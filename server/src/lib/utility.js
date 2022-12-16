'use strict'

const path = require('path')
const exec = require('child_process').exec
const fs   = require('fs')

function rng(min, max) {
	min = Math.floor(min)
	max = Math.floor(max)
	return Math.floor(Math.random() * (max - min) + min)
}

class Logger {
	tcp(msg) {
		console.log('[TCP]   ' + msg)
	}

	ws(msg) {
		console.log('[WS]    ' + msg)
	}

	http(msg) {
		console.log('[HTTP]  ' + msg)
	}

	score(msg) {
		console.log('[SCORE] ' + msg)
	}
}

class Player {
	playSound(name) {

		let theme = process.env.THEME || 'default'
		let soundDir = path.join(path.dirname(require.main.filename), '/sounds', theme, name)

		fs.readdir(soundDir, (err, files) => {
			if (err) {
				if (err.code == 'ENOENT') {
					// console.log(`[MAIN] No sounds for event "${name}"`)
				} else {
					console.log(`[SND]  ${err}`)
				}
				return
			}

			let file = rng(0, files.length) + '.mp3'
			let fullPath = path.join(soundDir, file)
			// console.log(`[MAIN] Playing ${fullPath}`)
			fs.exists(fullPath, (exists) => {
				if (exists) {
					console.log(`[SND]  Playing ${name}/${file}`)
					exec(`${process.env.PLAYER} ${fullPath}`, (err, stdout, stderr) => {
						if (err) {
							console.log(`[SND]  ${err}`)
							return
						}
					})
				}
			})
		})
	}
}

exports.player = new Player()
exports.log = new Logger()
