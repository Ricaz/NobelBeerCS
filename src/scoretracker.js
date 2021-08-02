const log  = require('./utility').log
const fs   = require('fs')
const glob = require('glob')

class Player {
	constructor(args) {
		this.id = args.id
		this.name = args.name
		this.kills = 0
		this.deaths = 0
		this.teamkills = 0
		this.knifekills = 0
		this.knifed = 0
		this.sips = 0
		this.rounds = 0
		this.active = true
	}
}

class Tracker {
	constructor(args) {
		// TODO: Load scoreboard from file/db
		this.startTime
		this.endTime
		this.running = false
		this.board

		// Load temp scoreboard if exists
		this.board = new Scoreboard()
		this.loadScoreboard()

		// debug
		this.board.addPlayer('a', 'ræv')
		this.board.addPlayer('b', 'abe')
	}

	loadScoreboard() {
		var path = `${process.env.TMPDIR}/*.json`
		const newestFile = glob.sync(path)
			.map(name => ({name, ctime: fs.statSync(name).ctime}))
			.sort((a, b) => b.ctime - a.ctime)[0].name

		if (newestFile) {
			const loaded = JSON.parse(fs.readFileSync(newestFile, { encoding: 'utf8' }))
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
			log.score('ROUND STARTING')
			this.startTime = Date.now()
			this.running = true
			this.board.reset()
			this.board.handleNewRound()
		}

		// TODO: don't do scoreboard stuff unless started
		//else if (! this.running)
		//	return

		else if (cmd == 'round')
			this.board.handleNewRound()

		else if (cmd == 'kill')
			this.board.handleKill(args[0], args[1])

		else if (cmd == 'knife')
			this.board.handleKnife(args[0], args[1])

		else if (cmd == 'tk')
			this.board.handleTeamkill(args[0], args[1])

		else if (cmd == 'suicide')
			this.board.handleSuicide(args[0])

		else if (cmd == 'player-joined')
			this.board.addPlayer(args[0], args[1])

		else if (cmd == 'player-left')
			this.board.removePlayer(args[0])

		else if (cmd == 'playersync') {
			args.forEach((serverPlayer) => {
				let exists = false
				this.players.forEach((localPlayer) => {
					if (serverPlayer.steamid == localPlayer.steamid)
						exists = true
				})
				if (exists) {
					this.addPlayer(serverPlayer.steamid, serverPlayer.name)
				}
			})

			this.players.forEach((localPlayer) => {
				let exists = true
				serverPlayers.forEach((serverPlayer) => {
					if (serverPlayer.steamid == localPlayer.steamid)
						exists = false
				})

				if (! exists)
					this.removePlayer(localPlayer.steamid)
			})
		}

		else if (cmd == 'mapend') {
			log.score('ROUND ENDING')
			this.endTime = Date.now()
			this.running = false

			// Write final scoreboard
			var tmpdir = process.env.TMPDIR
			if (! fs.existsSync(tmpdir))
				fs.mkdirSync(tmpdir)
			var filename = `${tmpdir}/${this.endTime}.json`
			fs.writeFile(filename, JSON.stringify(this.getScoreboard()), { flag: 'wx' }, (err) => {
				if (err)
					log.score(`Failed to write scoreboard to ${filename}: ${err.message}`)
				else 
					log.score(`Wrote final scoreboard to file ${filename}`)
			})

			return
		}

		// TODO: remove
		else
			log.score("Unknown event: " + JSON.stringify(message))


		// TODO: write scoreboard to temp file
		var tmpdir = process.env.TMPDIR
		if (! fs.existsSync(tmpdir))
			fs.mkdirSync(tmpdir)
		var filename = `${tmpdir}/${this.startTime}.json`
		fs.writeFile(filename, JSON.stringify(this.getScoreboard()), { flag: 'w' }, (err) => {
			if (err)
				log.score(`Failed to write scoreboard to ${filename}: ${err.message}`)
			else 
				log.score(`Wrote temp scoreboard to ${filename}`)
		})
	}
}

class Scoreboard {
	constructor(args) {
		this.players = []
	}

	// Add player
	// If ID exists, set name
	addPlayer(id, name) {
		var player = this.getPlayer(id)
		if (player) {
			player.name = name
			player.active = true
			return
		} else {
			var player = new Player({ id: id, name: name })	
			this.players.push(player)
		}
	}

	removePlayer(id) {
		var player = this.getPlayer(id)
		if (player)
			player.active = false
	}

	getPlayer(steamid) {
		return this.players.find(player => player.id == steamid)
	}

	getScores() {
		return this.players.sort((a, b) => (a.sips > b.sips) ? 1 : -1)
	}

	handleNewRound() {
		this.players.forEach(function (player) {
			player.sips++
			player.rounds++
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
		}
	}

	handleSuicide(playerID) {
		var player = this.getPlayer(playerID)
		if (player) {
			player.deaths += 1
			player.sips   += 10
		}
	}

	handleTeamkill(killerID, victimID) {
		var killer = this.getPlayer(killerID)
		var victim = this.getPlayer(victimID)
		if (killer && victim) {
			killer.kills  += 1
			killer.sips   += 20
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

	reset() {
		this.players.forEach(function (player) {
			player.kills = 0
			player.teamkills = 0
			player.knifekills = 0
			player.knifed = 0
			player.sips = 0
			player.rounds = 0
		})
	}
}

module.exports = Tracker
