#!node
'use strict'

// Load config from .env
import 'dotenv/config'

// Load system/npm modules
import * as net from 'node:net'
import * as path from 'node:path'
import * as fs from 'node:fs'
import WebSocket, { WebSocketServer } from 'ws'

// Load custom modules
import webserver from './lib/http-server.mjs'
import * as log from './lib/utility.mjs'
import scoretracker from './lib/scoretracker.mjs'

var settings   = {
	theme: 'default'
}

const mediaPath = 'dist/assets/media/'
const themes		= loadThemes()

console.log(`MODE: ${process.env.MODE}`)
console.log(`NODE_ENV: ${process.env.NODE_ENV}`)

// Initialize tracker and events
var tracker = new scoretracker()
tracker.on('state', (state) => { broadcast({ cmd: 'state', data: state }) })
tracker.on('stats', (stats) => { broadcast({ cmd: 'stats', data: stats }) })
tracker.on('game-ended', () => { broadcast({ cmd: 'game-ended' }) })

// Create TCP socket server and set up event handling on it
var tcp = net.createServer((sock) => {
	sock.setEncoding('utf8')

	sock.on('connect', (sock) => {
		log.tcp('Mod connected!')
	})

	sock.on('data', (data) => {
		log.tcp(data)
		let message = JSON.parse(data)

		if (message.cmd == 'getfullstats') {
			console.log(`opts: ${message.args}`)
			let stats = tracker.getStatsInterval(...message.args)
			console.log('getfullstats: ', stats)
			if (stats)
				broadcast(stats)
		}

		if (message.cmd == 'getstats') {
			console.log(`opts: ${message.args}`)
			let stats = tracker.getStats(...message.args)
			console.log('getstats: ', stats)
			if (stats)
				sock.write(JSON.stringify(stats))
		}

		if (message.cmd == 'balance') {
			let balanced = tracker.autoBalance(message.args.games)
			console.log('balanced: ', balanced)
			if (balanced)
				sock.write(JSON.stringify(balanced))
		}

		// Scoreboard
		tracker.handleEvent(message)
		if (tracker.running || true) {
			var fullState = { cmd: 'scoreboard', args: [ tracker.getScoreboard() ] }
			broadcast(fullState)

			// Handle media
			if (message.cmd === 'theme' && themes.includes(message.args[0])) {
				log.tcp(`Switched theme from '${settings.theme}' to '${message.args[0]}'.`)
				settings.theme = message.args[0]
			}

			if (getMedia(message.cmd)) {
				message.media = getMedia(message.cmd)
			}

			broadcast(message)
		}
	})

	sock.on('error', (err) => {
		log.tcp(err)
	})

	sock.pipe(sock)
})

tcp.listen(process.env.PORT_TCP, () => {
	log.tcp('Socket listening on ' + process.env.PORT_TCP)
})

webserver.listen(process.env.PORT_HTTP, (err) => {
	if (err)
		return log.tcp('http.listen() error: ' + err)

	log.http('Server listening on ' + process.env.PORT_HTTP)
})

const ws = new WebSocketServer({
	server: webserver,
	clientTracking: true
})

ws.on('listening', () => {
	log.ws(`Socket listening on ${process.env.PORT_HTTP}`)
})

ws.on('upgrade', (req, sock, head) => {
	log.ws(`Upgrade event: `, { req, sock, head })
})

ws.on('connection', (conn, req) => {
	conn.on('error', console.error)

	let clientAddress = req.socket.remoteAddress.split(':').at(-1)
	if (req.headers['x-forwarded-for'])
		clientAddress = req.headers['x-forwarded-for'].split(',')[0].trim();

	log.ws(`Connection from ${clientAddress}.`)

	log.ws('Sending full state.')
	var fullState = { cmd: 'scoreboard', args: [ tracker.getScoreboard() ] }
	conn.send(JSON.stringify(fullState))

	log.ws('Sending stats')
	if (tracker.state === 'ended') {
		log.ws(`Current state '${tracker.state}', sending pause stats`)
		conn.send(JSON.stringify({ cmd: 'state', data: 'ended' }))
		conn.send(JSON.stringify({ cmd: 'stats', data: tracker.generatePauseStats() }))
	} else if (tracker.state === 'idle') {
		log.ws(`Current state '${tracker.state}', sending idle stats`)
		conn.send(JSON.stringify({ cmd: 'state', data: 'idle' }))
		conn.send(JSON.stringify({ cmd: 'stats', data: tracker.generateIdleStats() }))
	} else if (tracker.state === 'live') {
		conn.send(JSON.stringify({ cmd: 'state', data: 'live' }))
	}

	// Send list of files
	conn.send(JSON.stringify({ cmd: 'filelist', data: getMediaList() }))

	conn.on('message', (data) => {
		log.ws(`[${clientAddress}]: ${data}`)
	})

	conn.on('close', (reason, description) => {
		log.ws(`[${clientAddress}] Disconnected.`)
	})
})

function getAllFiles(dirPath, arrayOfFiles) {
	var files = fs.readdirSync(dirPath)
	var arrayOfFiles = arrayOfFiles || []

	files.forEach(function(file) {
		if (fs.statSync(dirPath + "/" + file).isDirectory())
			arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles)
		else
			arrayOfFiles.push(path.join(path.resolve(), dirPath, "/", file))
	})

	return arrayOfFiles
}

function getMediaList() {
	var dir = `${mediaPath}/${settings.theme}`
	return getAllFiles(dir).map((a) => {
		return a.replace(/.*(assets.*)/, '$1')
	})
}

// Checks if media file exists for event.
// If using a theme, falls back to default in case of missing file.
function getMedia(event) {
	let media = []
	try {
		var dir = `${mediaPath}/${settings.theme}/${event}`
		if (! fs.existsSync(dir)) {
			dir = `${mediaPath}/default/${event}` 
			if (! fs.existsSync(dir))
				return false
		}

		media = fs.readdirSync(dir)
		let random = media[Math.floor(Math.random() * media.length)]

		if (dir.includes('default'))
			return `assets/media/default/${event}/${random}`
		else
			return `assets/media/${settings.theme}/${event}/${random}`
	} catch (e) {
		log.tcp(`No media found for event '${event}'.\nError: ${e}`)
		return false
	}
}

function loadThemes() {
	let files = fs.readdirSync(mediaPath)
	let themes = []
	files.forEach((file) => {
		let stats = fs.statSync(mediaPath + file)
		if (stats.isDirectory()) {
			themes.push(file)
		}
	})

	return themes
}

function broadcast(data) {
	ws.clients.forEach((client) => {
	if (client.readyState === WebSocket.OPEN)
		client.send(JSON.stringify(data))
	})
}
