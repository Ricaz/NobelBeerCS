const log  = require('./utility').log
const fs   = require('fs')
const path = require('path')
const glob = require('glob')

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

class Tracker {
	constructor(args) {
		this.startTime
		this.endTime
		this.running = false
		this.board
		this.historyDir = path.resolve(__dirname, '../history')

		// Ensure history dir exists
		if (! fs.existsSync(this.historyDir))
			fs.mkdirSync(this.historyDir)

		// Load temp scoreboard if exists
		this.board = new Scoreboard()
		this.loadScoreboard()

		// TODO: debug
		//this.board.addPlayer('a', 'ræv')
		//this.board.addPlayer('b', 'abe')
	}

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

		else if (cmd == 'knife')
			this.board.handleKnife(args[0], args[1])

		else if (cmd == 'tk')
			this.board.handleTeamkill(args[0], args[1])

		else if (cmd == 'suicide')
			this.board.handleSuicide(args[0])


		else if (cmd == 'mapchange') {
			log.score(`Game ended! Switching to ${args[0]}...`)
			this.endTime = Date.now()
			this.running = false

			// Write final scoreboard
			var filename = `${this.historyDir}/${this.endTime}.json`
			fs.writeFile(filename, JSON.stringify(this.getScoreboard()), { flag: 'wx' }, (err) => {
				if (err)
					log.score(`Failed to write scoreboard to ${filename}: ${err.message}`)
				else 
					log.score(`Wrote final scoreboard to file ${filename}`)
			})

			return
		}

		// Write scoreboard to tmp file (to resume state if started during round)
		// TODO: For some reason, file is sometimes written twice and I have no idea why..
		if (this.running) {
			var filename = `${this.historyDir}/${this.startTime}.json`
			fs.writeFile(filename, JSON.stringify(this.getScoreboard()), { flag: 'w' }, (err) => {
				if (err)
					log.score(`Failed to write scoreboard to ${filename}: ${err.message}`)
				else 
					log.score(`Wrote temp scoreboard to ${filename}`)
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

module.exports = Tracker
