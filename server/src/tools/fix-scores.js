#!node
'use strict'

const fs   = require('fs')
const path = require('path')
const glob = require('glob')

var files = glob.sync('../history/*json')
var games = []

const gameFiles = files.map(name => ({name, ctime: fs.statSync(name).ctime}))
	.sort((a, b) => a.ctime - b.ctime)

for (const filename of gameFiles) {
	let game

	try {
		game = JSON.parse(fs.readFileSync(filename.name))
	} catch (e) {
		console.log(`Error loading file ${filename.name}: ${e}`)
		continue
	}

	games.push(game)
}

var changed = 0
var left = 0

for (const game of games) {
	for (const player of game.scores) {
		if (player.active)
			continue

		if (player.kills || player.deaths > 1) {
			player.active = true
			changed++
		} else {
			left++
		}
	}
}

console.log(`Loaded ${games.length} games`)
console.log(`Changed ${changed} statuses (left ${left})`)
