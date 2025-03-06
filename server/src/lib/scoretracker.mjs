import * as path from 'node:path'
import * as glob from 'glob'
import * as url from 'node:url'
import * as fs from 'node:fs'
import { EventEmitter } from 'node:events'
import * as log from './utility.mjs'

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

		// Set state 'ended' if less than 30 hours since last game
		if (Date.now() - this.getLatestGameDate() < (3600*30*1000))
			this.state = 'ended'
		else
			this.state = 'idle'

		// Ensure history dir exists
		if (! fs.existsSync(this.historyDir))
			fs.mkdirSync(this.historyDir)

		// Load temp scoreboard if exists
		this.board = new Scoreboard()
		this.loadScoreboard()

		// TODO: debug
		//this.board.addPlayer('STEAM_0:0:32762533', 'jÆBBØH', 'T')
		//this.board.addPlayer('STEAM_0:1:11611559', 'ALSTRUP', 'CT')
	}

	changeState(newState) {
		this.state = newState
		this.emit('state', this.state)

		if (newState == 'ended') {
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
			var found = this.board.getScores().find(e => e.id == p.id)
			if (! found)
				return false

			console.log(`"${found.name}"  Active? ${found.active}. Team? ${found.team}`)
			if (found && found.active && (found.team == 'CT' || found.team == 'TERRORIST'))
				return true
			else
				return false
		}).sort((a, b) => b.kd - a.kd)

		let newTeams = { ct: [], t: [] }
		scores.forEach((player, i) => {
			if (i % 2 == 0) {
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
			p = p.id
		})
		log.score(`Terrorists:`)
		newTeams.t.forEach((p) => {
			log.score(`${p.kd}  ${p.name}`)	
			p = p.id
		})

		return response
	}

	getLatestGameDate() {
		const latest = glob.sync(`${this.historyDir}/*.json`)
			.map((file) => { return path.basename(file, '.json') })
			.sort((a, b) => { return b - a })
			[0]

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
		// Gets array of cleaned and desc-sorted filenames without .json extension
		const files = glob.sync(`${this.historyDir}/*.json`)
			.map((file) => { return path.basename(file, '.json') })
			.sort((a, b) => { return b - a })

		const now = Date.now()
		let delta = now - 2 * interval
		let numGames = 0
		let current

		while ((current = files.shift()) > delta) {
			numGames++
			delta = current - interval
		}

		if (numGames > 0)
			return this.getStats(numGames)
		else 
			return []
	}

	// Loads the latest `numGames` scoreboards and adds them together.
	// Also calculates K/D for each player.
	getStats(numGames = 0, sortBy = 'sips') {
		log.score(`called tracker.getStats(${numGames}, ${sortBy})`)
		var files = glob.sync(`${this.historyDir}/*.json`)
		var loadedFiles = []

		if (numGames == 0)
			numGames = files.length

		// Get files by name (cant sort by ctime anymore as i fucked and deleted everything)
		const gameFiles = files.sort((a, b) => path.basename(a, '.json') < path.basename(b, '.json'))

		// Load files until we have requested number of games (with >6 players)
		while (loadedFiles.length < numGames) {
			let game
			let file = gameFiles.pop()

			// Skip loading files if invalid JSON or less than 7 players
			try {
				game = JSON.parse(fs.readFileSync(file))
			} catch (e) {
				log.score(`Error loading scoreboard '${file}': ${e}`)
				numGames--
				continue
			}

			if (game.scores.length <= 6) {
				numGames--
				continue
			}

			loadedFiles.push(game)
		}

		log.score(`Loading ${loadedFiles.length} files`)

		// Loop over each loaded game, calculate K/D for each player,
		// ignoring players with 0/0 stats. Should produce the same
		// format as normal scoreboards, just with K/D added.
		var scores = []
		for (const game of loadedFiles) {
			for (const score of game.scores) {
				let player = scores.find((p) => {
					return p.id == score.id
				})
				let exists = player === undefined ? false : true
				let kd = 1

				// Ignore players with 0/0.
				// If players have 0 deaths, use kills as KD.
				// If players have 0 kills, KD is 1/deaths
				if (score.kills == 0 && score.deaths == 0) {
					continue
				} else if (score.kills > 0 && score.deaths == 0)
					kd = score.kills
				else if (score.kills == 0 && score.deaths > 0)
					kd = 1 / score.deaths
				else 
					kd = score.kills / score.deaths

				// If we didn't already handle this player, create it freshly
				if (! exists) {
					player = {
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
						knifed: score.knifed,
						sips: score.sips
					} 

					scores.push(player)
				}

				if (exists) {
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
		}

		scores.forEach((player) => {
			player.kd = player.kd / player.games
			player.kd = player.kd.toFixed(2)
		})

		scores.sort((a, b) => b[sortBy] - a[sortBy])

		return scores
	}

	// Loads newest scoreboard. This enables us to recover a live game
	// in case the web app crashes. Stats during the downtime will be lost.
	loadScoreboard() {
		var path = `${this.historyDir}/*.json`
		var files = glob.sync(path)

		if (files.length > 0) {
			const newestFile = files.map(name => ({name, ctime: fs.statSync(name).ctime}))
				.sort((a, b) => b.ctime - a.ctime)[0].name
			var loaded
			try {
				loaded = JSON.parse(fs.readFileSync(newestFile, { encoding: 'utf8' }))
			} catch (e) {
				log.score(`Error loading scoreboard: ${e}`)
				return
			}
			if (! loaded)
				return
			if (! loaded.endTime && loaded.startTime > Date.now() - (60000 *  70)) {
				log.score(`Loaded game with start time ${new Date(loaded.startTime).toLocaleTimeString('en-GB')} from ${newestFile}.`)
				this.startTime = loaded.startTime
				this.board.players = loaded.scores
				this.running = true
				this.changeState('live')
				return
			}
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

	handleEvent(message) {
		var cmd = message.cmd
		var args = message.args

		if (cmd == 'firstround') {
			log.score('Game starting!')
			this.startTime = Date.now()
			this.running = true
			this.changeState('live')
			this.board.reset()
		}

		else if (cmd == 'playerjoined')
			this.board.addPlayer(args.id, args.name, args.team)

		else if (cmd == 'playerleft')
			this.board.removePlayer(args.id)

		else if (cmd == 'playerteam')
			this.board.switchTeam(args.id, args.name, args.team)

		else if (cmd == 'playersync') {
			// Deactivate players not on server
			this.board.players.forEach((localPlayer) => {
				var existsRemote = false
				args.forEach((remotePlayer) => {
					if (localPlayer.id == remotePlayer.id)
						existsRemote = true
				})

				if (!existsRemote && localPlayer.active == true)
					this.board.removePlayer(localPlayer.id)
			});

			// Add/update players from server
			args.forEach((remotePlayer) => {
				this.board.addPlayer(remotePlayer.id, remotePlayer.name, remotePlayer.team)
			})
		}

		// Don't do scoreboard stuff unless started
		else if (! this.running)
			return

		else if (cmd == 'roundstart')
			this.board.handleNewRound()

		else if (cmd == 'kill' || cmd == 'headshot' || cmd == 'grenade')
			this.board.handleKill(args[0], args[1])

		else if (cmd.match(/knife$/))
			this.board.handleKnife(args[0], args[1])

		else if (cmd == 'tk')
			this.board.handleTeamkill(args[0], args[1])

		else if (cmd == 'suicide')
			this.board.handleSuicide(args[0])

		else if (cmd == 'mapend' || cmd == 'mapchange') {
			log.score(`Game ended!`)
			this.endTime = Date.now()

			// Write final scoreboard
			var filename = `${this.historyDir}/${this.startTime}.json`
			fs.writeFile(filename, JSON.stringify(this.getScoreboard()), { flag: 'wx' }, (err) => {
				if (err)
					log.score(`Failed to write scoreboard to ${filename}: ${err.message}`)
				else 
					log.score(`Wrote final scoreboard to file ${filename}`)
			})

			this.running = false
			this.changeState('ended')

			return
		}

		// Write scoreboard to tmp file (to resume state if started during round)
		// TODO: For some reason, file is sometimes written twice and I have no idea why..
		if (this.running) {
			var filename = `${this.historyDir}/${this.startTime}.json`
			fs.writeFile(filename, JSON.stringify(this.getScoreboard()), { flag: 'w' }, (err) => {
				if (err)
					log.score(`Failed to write scoreboard to ${filename}: ${err.message}`)
			})
		}
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
		var player = this.getPlayer(id)
		if (player) {
			if (player.name != name) {
				player.name = name
				log.score(`Rename "${player.name}" => "${name}"`)
			}
			if (player.team != team) {
				player.team = team
				log.score(`Team switch: "${name}" => ${team}`)
			}
			player.active = true
			return
		} else {
			log.score(`Adding player "${name}"`)
			var player = new Player({ id: id, name: name, team: team })
			this.players.push(player)
		}
	}

	switchTeam(id, name, team) {
		var player = this.getPlayer(id)
		if (! player) {
			log.score(`Tried to switch team of "${name}", but player doesn't exist`)
			return
		}
		if (player.team != team) {
			player.team = team
			log.score(`Team switch: "${name}" => ${team}`)
		}
	}

	removePlayer(id) {
		var player = this.getPlayer(id)
		if (player) {
			log.score(`Removing player "${player.name}"`)
			player.active = false
		}
	}

	getPlayer(steamid) {
		return this.players.find(player => player.id == steamid)
	}

	getScores() {
		return this.players.sort((a, b) => (a.sips < b.sips) ? 1 : -1)
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
		var killer = this.getPlayer(killerID)
		var victim = this.getPlayer(victimID)
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
		var killer = this.getPlayer(killerID)
		var victim = this.getPlayer(victimID)
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
		var player = this.getPlayer(playerID)
		if (player) {
			log.score(`Player "${player.name}" committed suicide!`)
			player.suicides += 1
			player.deaths += 1
			player.sips   += 10
		}
	}

	handleTeamkill(killerID, victimID) {
		var killer = this.getPlayer(killerID)
		var victim = this.getPlayer(victimID)
		if (killer && victim) {
			if (killer.sips < 20)
				killer.sips += 10
			else if (killer.sips % 20 < 4)
				killer.sips += 3
			else 
				killer.sips += killer.sips % 20
			killer.teamkills += 1
			killer.kills  += 1
			victim.deaths += 1
			victim.sips   += 1
		}
	}

	handleNewName(id, name) {
		var player = this.getPlayer(id)
		if (player) {
			player.name = name
		}
	}

	handlePlayerDisconnect(id) {
		var player = this.getPlayer(id)
		if (player)
			player.active = false
	}

	handleMapChange(map) {
		log.score(`Chaning map to ${map}`)
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
