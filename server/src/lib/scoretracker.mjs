import * as path from 'node:path'
import * as fs from 'node:fs'
import { EventEmitter } from 'node:events'
import * as log from './utility.mjs'

const SIPS_PER_BEER = 20

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
		this.historyDir = path.resolve('history')
		this.writeTimer = null

		// Ensure history dir exists
		if (! fs.existsSync(this.historyDir))
			fs.mkdirSync(this.historyDir)

		// All finished (and the current) games, sorted oldest first: [ { time, game } ]
		this.history = this.loadHistory()

		// Set state 'ended' if less than 30 hours since last game
		if (Date.now() - this.getLatestGameDate() < (3600*30*1000))
			this.state = 'ended'
		else
			this.state = 'idle'

		// Load temp scoreboard if exists
		this.board = new Scoreboard()
		this.loadScoreboard()
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

	changeState(newState) {
		this.state = newState
		this.emit('state', this.state)

		if (newState === 'ended') {
			this.emit('stats', this.generatePauseStats())

			// If a game ended, change back to idle after 30 hours
			setTimeout(() => {
				this.state = 'idle'
				this.emit('state', this.state)
			}, 3600 * 30 * 1000)
		}
	}

	generateIdleStats() {
		let totalStats = this.getStats()

		return { full: totalStats }
	}

	generatePauseStats() {
		let lanStats = this.getStatsInterval()
		let todayStats = this.getStatsInterval(3600 * 16 * 1000)

		return { today: todayStats, lan: lanStats }
	}

	autoBalance(numGames = 0) {
		let scores = this.getStats(numGames)
		let response = []

		if (! this.board.getScores().length)
			return false

		// Only use players currently active
		scores = scores.filter((p) => {
			let found = this.board.getPlayer(p.id)
			if (! found)
				return false

			console.log(`"${found.name}"  Active? ${found.active}. Team? ${found.team}`)
			return !!(found && found.active && (found.team === 'CT' || found.team === 'TERRORIST'));
		}).sort((a, b) => b.kd - a.kd)

		let newTeams = { ct: [], t: [] }
		scores.forEach((player, i) => {
			if (i % 2 === 0) {
				newTeams.ct.push(player)
				response.push({ steamid: player.id, team: 'CT' })
			} else {
				newTeams.t.push(player)
				response.push({ steamid: player.id, team: 'T' })
			}
		})

		// Just logging
		log.score(`Balancing teams..`)
		log.score(`Counter-Terrorists:`)
		newTeams.ct.forEach((p) => {
			log.score(`${p.kd}  ${p.name}`)
		})
		log.score(`Terrorists:`)
		newTeams.t.forEach((p) => {
			log.score(`${p.kd}  ${p.name}`)
		})

		return response
	}

	getLatestGameDate() {
		const latest = this.history.at(-1)?.time
		log.score(`Latest game: ${latest}`)
		return latest
	}

	// Generate stats for multiple games. Iterates back over games
	// that fit within `interval` window from latest game. For example,
	// if you set `interval` to 12 hours, you could get all stats from current session,
	// or with `interval` to 3 days, get all stats for the entire LAN.
	//
	// Defaults to 3 days.
	getStatsInterval(interval = 3 * 86400 * 1000) {
		const times = this.history.map((entry) => entry.time).reverse()

		let delta = Date.now() - 2 * interval
		let numGames = 0
		let current

		while ((current = times.shift()) > delta) {
			numGames++
			delta = current - interval
		}

		if (numGames > 0)
			return this.getStats(numGames)
		else
			return []
	}

	// Adds together the latest `numGames` scoreboards (all if 0).
	// Also calculates K/D for each player.
	getStats(numGames = 0, sortBy = 'sips') {
		// Skip games with <2 players
		const games = (numGames > 0 ? this.history.slice(-numGames) : this.history)
			.map((entry) => entry.game)
			.filter((game) => game.scores.length >= 2)

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
			this.changeState('live')
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

		clearTimeout(this.writeTimer)
		this.writeTimer = setTimeout(() => {
			const filename = `${this.historyDir}/${game.startTime}.json`
			const tmpname = `${filename}.tmp`
			fs.promises.writeFile(tmpname, JSON.stringify(game))
				.then(() => fs.promises.rename(tmpname, filename))
				.then(() => { if (game.endTime) log.score(`Wrote final scoreboard to file ${filename}`) })
				.catch((err) => log.score(`Failed to write scoreboard to ${filename}: ${err.message}`))
		}, immediately ? 0 : 1000)
	}

	handleEvent(message) {
		const cmd = message.cmd
		const args = message.args

		if (cmd === 'firstround') {
			log.score('Game starting!')
			this.startTime = Date.now()
			this.endTime = undefined
			this.running = true
			this.changeState('live')
			this.board.reset()
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
			log.score(`Game ended!`)
			this.endTime = Date.now()
			this.saveScoreboard(true)
			this.running = false
			this.changeState('ended')
			return
		}

		// Save scoreboard (to resume state if the server restarts during a game)
		if (this.running)
			this.saveScoreboard()
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
