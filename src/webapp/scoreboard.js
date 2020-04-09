class Player {
	constructor(args) {
		this.id = args.id
		this.name = args.name
		this.kills = 0
		this.teamkills = 0
		this.knifekills = 0
		this.knifed = 0
		this.sips = 0
		this.rounds = 0
	}
}

export class Scoreboard {
	constructor(args) {
		this.players = [];
	}

	findPlayer(steamid) {
		let found = false

		this.players.forEach(function (player) {
			if (player.steamid === steamid) {
				return player
			}
		})

		return false
	}

	newRound() {
		this.players.forEach(function (player) {
			this.addSip(player.id)
			this.addRound(player.id)
		})
	}

	handleKnife(killerID, victimID) {
		killer = this.findPlayer(killerID)
		victim = this.findPlayer(victimID)
		if (player && victim) {
			this.addKnife(killer)
			this.addDeath(victim)
			this.addKnifed(victim)
		}
	}

	handleKill(killerID, victimID) {
		killer = this.findPlayer(killerID)
		victim = this.findPlayer(victimID)
		if (player && victim) {
			this.addKill(killer)
			this.addDeath(victim)
		}
	}

	addKnifed(id) {
		player = this.findPlayer(id)
		if (player)
			player.knifed++
	}

	addDeath(id) {
		player = this.findPlayer(id)
		if (player)
			player.deaths++
	}

	addKill(steamid, args = []) {
		player = this.findPlayer(steamid)
		if (player)
			player.kills++
	}

	addPlayer(args) {
		let player = new Player(id, name)	
		this.players.push(player)
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
