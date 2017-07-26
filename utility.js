const path = require('path')
const exec = require('child_process').exec
const fs   = require('fs')

class Logger {
	tcp(msg) {
		console.log('[TCP]  ' + msg)
	}

	ws(msg) {
		console.log('[WS]   ' + msg)
	}

	http(msg) {
		console.log('[HTTP] ' + msg)
	}
}

class Player {
	playSound(name) {

		let theme = process.env.THEME || 'default'
		let soundDir = path.join(path.dirname(require.main.filename), '/sounds', theme, name)

		fs.access(soundDir, (err) => { 
			if (err) {
				console.log(`[MAIN] ${err}`)
				return
			}		
		})

		fs.readdir(path.join(soundDir), (err, files) => {
			if (err) {
				console.log(`[MAIN] ${err}`)
				return
			}

			if (!files) {
				console.log(`[MAIN] No files in ${fullPath}`)
				return
			}

			let file = rng(1, files.length) + '.mp3'
			let fullPath = path.join(soundDir, file)
			console.log(`[MAIN] Playing ${fullPath}`)
			exec(`mpv ${fullPath}`, (err, stdout, stderr) => {
				if (err) {
					console.log(`[MAIN] ${err}`)
					return
				}
			})
		})
	}
}

exports.player = new Player()
exports.log = new Logger()
