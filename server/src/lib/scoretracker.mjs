import * as path from 'node:path'
import * as fs from 'node:fs'
import { EventEmitter } from 'node:events'
import * as log from './utility.mjs'
import { balanceTeams } from './balance.mjs'

const SIPS_PER_BEER = 20

// Shorter games (aborted starts, restarts, tests) are left out of stats and ratings
const MIN_ROUNDS = 8
const MIN_ACTIVE_PLAYERS = 4

// Balancing: teams may differ this much in average rating, and every rating gets
// this many extra kills and deaths, which pulls players with few games toward 1.0
const BALANCE_TOLERANCE = 0.03
const RATING_PRIOR = 20

// LAN events: games less than LAN_GAP apart belong to the same LAN, which counts
// as active until LAN_ACTIVE_FOR after its latest game started
const LAN_GAP = 3 * 86400 * 1000
const LAN_ACTIVE_FOR = 30 * 3600 * 1000
// "Today" starts at this hour (server time). We play from ~21:00 into the morning.
const DAY_STARTS_AT = 12
// Show stats instead of the live scoreboard when a game has been quiet this long,
// in case its end event never arrived
const GAME_IDLE_AFTER = 20 * 60 * 1000
// Groups of fewer games are casual evenings, not LANs (except the current LAN)
const MIN_LAN_GAMES = 10

// LANs are named by the season they start in, e.g. "Easter 2024"
const SEASONS = [ 'Winter', 'Winter', 'Easter', 'Easter', 'Easter', 'Summer', 'Summer', 'Summer', 'Autumn', 'Autumn', 'Autumn', 'Christmas' ]

// "Most øls" etc. for a list of player stats
function highlights(scores) {
	const most = (field, format = (v) => v) => {
		const max = Math.max(0, ...scores.map((p) => p[field]))
		if (!max)
			return null
		const names = scores.filter((p) => p[field] === max).map((p) => p.name)
		return { names, value: format(max) }
	}

	return {
		beers: most('sips', (sips) => (sips / SIPS_PER_BEER).toFixed(1)),
		teamkills: most('teamkills'),
		knifekills: most('knifekills'),
		suicides: most('suicides'),
	}
}

function isRealGame(game) {
	const rounds = Math.max(0, ...game.scores.map((p) => p.rounds || 0))
	const active = game.scores.filter((p) => p.kills || p.deaths).length
	return rounds >= MIN_ROUNDS && active >= MIN_ACTIVE_PLAYERS
}

class Player {
	constructor(args) {
		this.id = args.id
		this.name = args.name
		this.team = args.team
		this.kills = 0
		this.deaths = 0
		this.teamkills = 0
		this.knifekills = 0
		this.knifed = 0
		this.suicides = 0
		this.sips = 0
		this.rounds = 0
		this.active = true
	}
}

export default class Tracker extends EventEmitter {
	constructor(args) {
		super()
		this.startTime
		this.endTime
		this.running = false
		this.board
		this.historyDir = path.resolve(args?.historyDir || 'history')
		this.writeTimers = new Map() // per game start time

		// Ensure history dir exists
		if (! fs.existsSync(this.historyDir))
			fs.mkdirSync(this.historyDir)

		// All finished (and the current) games, sorted oldest first: [ { time, game } ]
		this.history = this.loadHistory()

		this.lastEventTime = 0
		this.state = this.currentState()

		// Load temp scoreboard if exists
		this.board = new Scoreboard()
		this.loadScoreboard()

		// The state also changes with time: LANs end, games go quiet
		setInterval(() => this.updateState(), 60 * 1000).unref()
	}

	loadHistory() {
		let history = []
		for (const file of fs.readdirSync(this.historyDir)) {
			if (!file.endsWith('.json'))
				continue

			try {
				const game = JSON.parse(fs.readFileSync(path.join(this.historyDir, file), 'utf8'))
				history.push({ time: Number(path.basename(file, '.json')), game })
			} catch (e) {
				log.score(`Error loading scoreboard '${file}': ${e}`)
			}
		}

		history.sort((a, b) => a.time - b.time)
		log.score(`Loaded ${history.length} games from history`)
		return history
	}

	// 'live': a game is running, 'ended': between games at a LAN, 'idle': no LAN
	currentState() {
		if (this.running && Date.now() - this.lastEventTime < GAME_IDLE_AFTER)
			return 'live'

		const latest = this.realGames().at(-1)
		if (latest && Date.now() - latest.time < LAN_ACTIVE_FOR)
			return 'ended'

		return 'idle'
	}

	updateState() {
		const state = this.currentState()
		if (state === this.state)
			return

		log.score(`State: ${this.state} => ${state}`)
		this.state = state
		this.emit('state', state)
		if (state !== 'live')
			this.emit('stats', this.generateStats())
	}

	// Stats to show in the current state (none while live)
	generateStats() {
		if (this.state === 'ended')
			return this.generatePauseStats()
		if (this.state === 'idle')
			return this.generateIdleStats()
		return null
	}

	generateIdleStats() {
		return { all: this.getStatsReply() }
	}

	generatePauseStats() {
		const lan = this.getStatsSince(this.lanStart())
		return {
			today: this.getStatsSince(this.todayStart()),
			lan,
			lanHighlights: highlights(lan),
			lans: this.getLanList(),
		}
	}

	// Stats for the "All stats" page: all time, or one LAN by id
	getStatsReply(lanId = null) {
		const lans = this.getLans()
		const lan = lanId ? lans.find((l) => l.id === lanId) : null
		const scores = lan ? this.sumStats(lan.entries) : this.getStats()
		return {
			lan: lan?.id ?? null,
			scores,
			highlights: highlights(scores),
			lans: lans.map(({ entries, ...info }) => info),
		}
	}

	// LANs for the dropdown, without their games
	getLanList() {
		return this.getLans().map(({ entries, ...info }) => info)
	}

	// LAN events, newest first: [ { id, name, start, end, games, entries } ].
	// The id is the start time of the LAN's first game.
	getLans() {
		const groups = []
		for (const entry of this.realGames()) {
			const group = groups.at(-1)
			if (group && entry.time - group.at(-1).time < LAN_GAP)
				group.push(entry)
			else
				groups.push([ entry ])
		}

		const current = this.state !== 'idle' ? groups.at(-1) : null
		const lans = groups.filter((group) => group.length >= MIN_LAN_GAMES || group === current)

		// Number LANs sharing a season: "Summer 2024", "Summer 2024 (2)"
		const seen = {}
		return lans.map((entries) => {
			const start = new Date(entries[0].time)
			const base = `${SEASONS[start.getMonth()]} ${start.getFullYear()}`
			seen[base] = (seen[base] || 0) + 1
			return {
				id: entries[0].time,
				name: seen[base] > 1 ? `${base} (${seen[base]})` : base,
				start: entries[0].time,
				end: entries.at(-1).time,
				games: entries.length,
				entries,
			}
		}).reverse()
	}

	realGames() {
		return this.history.filter((entry) => isRealGame(entry.game))
	}

	// Start time of the first game of the latest LAN
	lanStart() {
		const games = this.realGames()
		let start = games.at(-1)?.time ?? Date.now()
		for (let i = games.length - 2; i >= 0 && start - games[i].time < LAN_GAP; i--)
			start = games[i].time
		return start
	}

	// The latest DAY_STARTS_AT o'clock
	todayStart() {
		const start = new Date()
		if (start.getHours() < DAY_STARTS_AT)
			start.setDate(start.getDate() - 1)
		start.setHours(DAY_STARTS_AT, 0, 0, 0)
		return start.getTime()
	}

	// Kills / deaths over the player's own last `numGames` real games (all if 0)
	getRating(id, numGames = 0) {
		let kills = 0, deaths = 0, games = 0
		for (let i = this.history.length - 1; i >= 0 && (!numGames || games < numGames); i--) {
			const game = this.history[i].game
			const player = game.scores.find((p) => p.id === id)
			if (!player || !(player.kills || player.deaths) || !isRealGame(game))
				continue

			kills += player.kills
			deaths += player.deaths
			games++
		}

		return (kills + RATING_PRIOR) / (deaths + RATING_PRIOR)
	}

	// Returns new teams for all active players: [ { steamid, team: 'CT' | 'T' } ]
	autoBalance(numGames = 50) {
		const players = this.board.players.filter((p) => p.active && (p.team === 'CT' || p.team === 'TERRORIST'))
		if (players.length < 2)
			return false

		const ratings = players.map((p) => this.getRating(p.id, numGames))
		const current = players.map((p) => p.team === 'CT' ? 1 : 0)
		const { teams, imbalance, candidates } = balanceTeams(ratings, { tolerance: BALANCE_TOLERANCE, currentTeams: current })

		// Which of the two teams plays CT is random too
		const ctTeam = Math.random() < 0.5 ? 0 : 1
		const response = players.map((p, i) => ({ steamid: p.id, team: teams[i] === ctTeam ? 'CT' : 'T' }))

		log.score(`Balancing ${players.length} players (last ${numGames || 'all'} games each): picked 1 of ${candidates} splits, ${(imbalance * 100).toFixed(1)}% imbalance`)
		for (const side of [ 'CT', 'T' ]) {
			const members = players.map((p, i) => ({ p, rating: ratings[i] })).filter((_, i) => response[i].team === side)
			const avg = members.reduce((a, m) => a + m.rating, 0) / members.length
			log.score(`${side} (avg ${avg.toFixed(2)}): ${members.sort((a, b) => b.rating - a.rating).map((m) => `${m.p.name} ${m.rating.toFixed(2)}`).join(', ')}`)
		}

		return response
	}

	// Adds together the latest `numGames` scoreboards (all if 0).
	// Also calculates K/D for each player.
	getStats(numGames = 0, sortBy = 'sips') {
		return this.sumStats(numGames > 0 ? this.history.slice(-numGames) : this.history, sortBy)
	}

	// Stats for all games started at or after `time`
	getStatsSince(time) {
		return this.sumStats(this.history.filter((entry) => entry.time >= time))
	}

	sumStats(entries, sortBy = 'sips') {
		const games = entries.map((entry) => entry.game).filter(isRealGame)

		log.score(`getStats() using ${games.length} games`)

		// Loop over each game, calculate K/D for each player,
		// ignoring players with 0/0 stats. Should produce the same
		// format as normal scoreboards, just with K/D added.
		let scores = new Map()
		for (const game of games) {
			for (const score of game.scores) {
				// Ignore players with 0/0.
				// If players have 0 deaths, use kills as KD.
				// If players have 0 kills, KD is 1/deaths
				if (score.kills === 0 && score.deaths === 0)
					continue

				let kd
				if (score.deaths === 0)
					kd = score.kills
				else if (score.kills === 0)
					kd = 1 / score.deaths
				else
					kd = score.kills / score.deaths

				let player = scores.get(score.id)
				if (! player) {
					scores.set(score.id, {
						name: score.name,
						id: score.id,
						kd: kd,
						games: 1,
						kills: score.kills,
						deaths: score.deaths,
						teamkills: score.teamkills,
						suicides: score.suicides,
						sips: score.sips,
						knifekills: score.knifekills,
						knifed: score.knifed
					})
					continue
				}

				// Games are oldest first, so this ends up as the name last seen
				player.name = score.name
				player.kd += kd
				player.kills += score.kills
				player.deaths += score.deaths
				player.teamkills += score.teamkills
				player.suicides += score.suicides
				player.knifekills += score.knifekills
				player.knifed += score.knifed
				player.sips += score.sips
				player.games++
			}
		}

		return [...scores.values()]
			.map((player) => ({ ...player, kd: (player.kd / player.games).toFixed(2) }))
			.sort((a, b) => b[sortBy] - a[sortBy])
	}

	// Loads newest scoreboard. This enables us to recover a live game
	// in case the web app crashes. Stats during the downtime will be lost.
	loadScoreboard() {
		const loaded = this.history.at(-1)?.game
		if (loaded && ! loaded.endTime && loaded.startTime > Date.now() - (60000 *  70)) {
			log.score(`Loaded game with start time ${new Date(loaded.startTime).toLocaleTimeString('en-GB')}.`)
			this.startTime = loaded.startTime
			this.board.players = loaded.scores
			this.running = true
			this.lastEventTime = Date.now()
			this.updateState()
			return
		}

		log.score('No recent, unfinished game found. Waiting for Øl CS!')
	}

	getScoreboard() {
		return {
			startTime: this.startTime,
			endTime: this.endTime,
			scores: this.board.getScores()
		}
	}

	// Updates the current game in history and writes it to disk. Writes are
	// batched, and go through a temp file so a crash can't leave a broken file.
	saveScoreboard(immediately = false) {
		const game = JSON.parse(JSON.stringify(this.getScoreboard()))
		const entry = this.history.find((e) => e.time === this.startTime)
		if (entry)
			entry.game = game
		else
			this.history.push({ time: this.startTime, game })

		clearTimeout(this.writeTimers.get(game.startTime))
		this.writeTimers.set(game.startTime, setTimeout(() => {
			this.writeTimers.delete(game.startTime)
			const filename = `${this.historyDir}/${game.startTime}.json`
			const tmpname = `${filename}.tmp`
			fs.promises.writeFile(tmpname, JSON.stringify(game))
				.then(() => fs.promises.rename(tmpname, filename))
				.then(() => { if (game.endTime) log.score(`Wrote final scoreboard to file ${filename}`) })
				.catch((err) => log.score(`Failed to write scoreboard to ${filename}: ${err.message}`))
		}, immediately ? 0 : 1000))
	}

	handleEvent(message) {
		const cmd = message.cmd
		const args = message.args

		if (this.running)
			this.lastEventTime = Date.now()

		if (cmd === 'firstround') {
			// The previous game's end event may have been lost
			if (this.running)
				this.endGame(this.lastEventTime)

			log.score('Game starting!')
			this.startTime = Date.now()
			this.endTime = undefined
			this.running = true
			this.lastEventTime = Date.now()
			this.board.reset()
			this.updateState()
		}

		else if (cmd === 'playerjoined')
			this.board.addPlayer(args.id, args.name, args.team)

		else if (cmd === 'playerleft')
			this.board.removePlayer(args.id)

		else if (cmd === 'playerteam')
			this.board.switchTeam(args.id, args.name, args.team)

		else if (cmd === 'playersync') {
			// Deactivate players not on server
			const remoteIds = new Set(args.map((p) => p.id))
			this.board.players.forEach((localPlayer) => {
				if (!remoteIds.has(localPlayer.id) && localPlayer.active === true)
					this.board.removePlayer(localPlayer.id)
			})

			// Add/update players from server
			args.forEach((remotePlayer) => {
				this.board.addPlayer(remotePlayer.id, remotePlayer.name, remotePlayer.team)
			})
		}

		// Don't do scoreboard stuff unless started
		else if (! this.running)
			return

		else if (cmd === 'roundstart')
			this.board.handleNewRound()

		else if (cmd === 'kill' || cmd === 'headshot' || cmd === 'grenade')
			this.board.handleKill(args[0], args[1])

		else if (cmd === 'knife')
			this.board.handleKnife(args[0], args[1])

		else if (cmd === 'tk')
			this.board.handleTeamkill(args[0], args[1])

		else if (cmd === 'suicide')
			this.board.handleSuicide(args[0])

		else if (cmd === 'mapend' || cmd === 'mapchange') {
			this.endGame(Date.now())
			this.updateState()
			return
		}

		// Save scoreboard (to resume state if the server restarts during a game)
		if (this.running) {
			this.saveScoreboard()
			this.updateState()
		}
	}

	endGame(endTime) {
		log.score(`Game ended!`)
		this.endTime = endTime
		this.saveScoreboard(true)
		this.running = false
	}
}

class Scoreboard {
	constructor(args) {
		this.players = []
	}

	// Add player
	// If ID exists, update name/team
	addPlayer(id, name, team) {
		if (! team)
			team = "UNASSIGNED"
		let player = this.getPlayer(id)
		if (player) {
			if (player.name !== name) {
				log.score(`Rename "${player.name}" => "${name}"`)
				player.name = name
			}
			if (player.team !== team) {
				player.team = team
				log.score(`Team switch: "${name}" => ${team}`)
			}
			player.active = true
		} else {
			log.score(`Adding player "${name}"`)
			let player = new Player({ id: id, name: name, team: team })
			this.players.push(player)
		}
	}

	switchTeam(id, name, team) {
		let player = this.getPlayer(id)
		if (! player) {
			log.score(`Tried to switch team of "${name}", but player doesn't exist`)
			return
		}
		if (player.team !== team) {
			player.team = team
			log.score(`Team switch: "${name}" => ${team}`)
		}
	}

	removePlayer(id) {
		let player = this.getPlayer(id)
		if (player) {
			log.score(`Removing player "${player.name}"`)
			player.active = false
		}
	}

	getPlayer(steamid) {
		return this.players.find(player => player.id === steamid)
	}

	getScores() {
		return this.players.sort((a, b) => b.sips - a.sips)
	}

	handleNewRound() {
		this.players.forEach(function (player) {
			if (player.active) {
				player.sips++
				player.rounds++
			}
		})
	}

	handleKnife(killerID, victimID) {
		let killer = this.getPlayer(killerID)
		let victim = this.getPlayer(victimID)
		if (killer && victim) {
			killer.kills  += 1
			killer.knifekills += 1
			killer.sips   += 2
			victim.deaths += 1
			victim.knifed += 1
			victim.sips   += 1
		}
	}

	handleKill(killerID, victimID) {
		let killer = this.getPlayer(killerID)
		let victim = this.getPlayer(victimID)
		if (killer && victim) {
			killer.kills  += 1
			killer.sips   += 2
			victim.deaths += 1
			victim.sips   += 1
		} else {
			log.score(`Kill error: Couldn't find killer (${killerID}) or victim (${victimID})`)
		}
	}

	handleSuicide(playerID) {
		let player = this.getPlayer(playerID)
		if (player) {
			log.score(`Player "${player.name}" committed suicide!`)
			player.suicides += 1
			player.deaths += 1
			player.sips   += 10
		}
	}

	handleTeamkill(killerID, victimID) {
		let killer = this.getPlayer(killerID)
		let victim = this.getPlayer(victimID)
		if (killer && victim) {
			// Finish your beer: add the sips remaining in the current one
			killer.sips += SIPS_PER_BEER - killer.sips % SIPS_PER_BEER
			killer.teamkills += 1
			killer.kills  += 1
			victim.deaths += 1
			victim.sips   += 1
		}
	}

	reset() {
		this.players.forEach(function (player) {
			player.kills = 0
			player.deaths = 0
			player.teamkills = 0
			player.knifekills = 0
			player.suicides = 0
			player.knifed = 0
			player.sips = 0
			player.rounds = 0
		})
	}
}
