#!node
'use strict'

// Load config from .env
import 'dotenv/config'

// Load system/npm modules
import * as dgram from 'node:dgram'
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

const mediaPath = 'dist/assets/media'
const media     = loadMedia()

console.log(`MODE: ${process.env.MODE}`)
console.log(`NODE_ENV: ${process.env.NODE_ENV}`)

// Initialize tracker and events
var tracker = new scoretracker({ historyDir: process.env.HISTORY_DIR })
tracker.on('state', (state) => { broadcast({ cmd: 'state', data: state }) })
tracker.on('stats', (stats) => { broadcast({ cmd: 'stats', data: stats }) })
tracker.on('game-ended', () => { broadcast({ cmd: 'game-ended' }) })

// The mod sends newline-terminated JSON messages over UDP. The replies to
// requests (like 'balance') are sent back to the address they came from.
const udp = dgram.createSocket('udp4')

udp.on('message', (data, rinfo) => {
	handleData(data.toString('utf8'), (reply) => {
		udp.send(JSON.stringify(reply), rinfo.port, rinfo.address)
	})
})

udp.on('error', (err) => {
	log.tcp(`UDP error: ${err}`)
})

udp.bind(process.env.PORT_TCP, () => {
	log.tcp('UDP socket listening on ' + process.env.PORT_TCP)
})

// Same protocol over TCP, used by tools/tcptester.js
var tcp = net.createServer((sock) => {
	let buffer = ''
	sock.setEncoding('utf8')

	sock.on('data', (data) => {
		buffer += data
		let end = buffer.lastIndexOf('\n')
		if (end === -1)
			return

		handleData(buffer.slice(0, end), (reply) => { sock.write(JSON.stringify(reply) + '\n') })
		buffer = buffer.slice(end + 1)
	})

	sock.on('error', (err) => {
		log.tcp(err)
	})
})

tcp.listen(process.env.PORT_TCP, () => {
	log.tcp('TCP socket listening on ' + process.env.PORT_TCP)
})

function handleData(data, reply) {
	for (const line of data.split('\n')) {
		if (!line.trim())
			continue

		log.tcp(line)
		let message
		try {
			message = JSON.parse(line)
		} catch (e) {
			log.tcp(`Invalid JSON from mod: ${e.message}`)
			continue
		}

		try {
			handleMessage(message, reply)
		} catch (e) {
			log.tcp(`Error handling '${message.cmd}': ${e.stack}`)
		}
	}
}

function handleMessage(message, reply) {
	if (message.cmd == 'getfullstats')
		broadcast({ cmd: 'stats', data: tracker.generatePauseStats() })

	if (message.cmd == 'getstats') {
		let stats = tracker.getStats(...message.args)
		if (stats)
			reply(stats)
	}

	if (message.cmd == 'balance') {
		let balanced = tracker.autoBalance(message.args.games)
		console.log('balanced: ', balanced)
		if (balanced)
			reply(balanced)
	}

	// Scoreboard
	tracker.handleEvent(message)
	broadcast({ cmd: 'scoreboard', args: [ tracker.getScoreboard() ] })

	// Handle media
	if (message.cmd === 'theme' && media[message.args[0]]) {
		log.tcp(`Switched theme from '${settings.theme}' to '${message.args[0]}'.`)
		settings.theme = message.args[0]
	}

	// 'sound' lets the mod pick a personal sound for an event, e.g. 'jeppeknife' for 'knife'
	let file = getMedia(message.sound) || getMedia(message.cmd)
	if (file)
		message.media = file

	broadcast(message)
}

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

ws.on('connection', (conn, req) => {
	conn.on('error', console.error)

	let clientAddress = req.socket.remoteAddress.split(':').at(-1)
	if (req.headers['x-forwarded-for'])
		clientAddress = req.headers['x-forwarded-for'].split(',')[0].trim();

	log.ws(`Connection from ${clientAddress}.`)

	log.ws('Sending full state.')
	var fullState = { cmd: 'scoreboard', args: [ tracker.getScoreboard() ] }
	conn.send(JSON.stringify(fullState))

	log.ws(`Sending state '${tracker.state}' and stats`)
	conn.send(JSON.stringify({ cmd: 'state', data: tracker.state }))
	const stats = tracker.generateStats()
	if (stats)
		conn.send(JSON.stringify({ cmd: 'stats', data: stats }))

	// Send list of files
	conn.send(JSON.stringify({ cmd: 'filelist', data: getMediaList() }))

	conn.on('message', (data) => {
		log.ws(`[${clientAddress}]: ${data}`)
	})

	conn.on('close', (reason, description) => {
		log.ws(`[${clientAddress}] Disconnected.`)
	})
})

// Builds an index of all media files: { theme: { event: [ 'assets/media/theme/event/file' ] } }
function loadMedia() {
	let index = {}
	for (const theme of fs.readdirSync(mediaPath, { withFileTypes: true })) {
		if (!theme.isDirectory())
			continue

		index[theme.name] = {}
		for (const event of fs.readdirSync(path.join(mediaPath, theme.name), { withFileTypes: true })) {
			if (!event.isDirectory())
				continue

			index[theme.name][event.name] = fs.readdirSync(path.join(mediaPath, theme.name, event.name), { withFileTypes: true })
				.filter((file) => file.isFile())
				.map((file) => `assets/media/${theme.name}/${event.name}/${file.name}`)
		}
	}

	log.tcp(`Loaded media for themes: ${Object.keys(index).join(', ')}`)
	return index
}

function getMediaList() {
	return Object.values(media[settings.theme] ?? {}).flat()
}

// Picks a random media file for the event.
// If using a theme, falls back to default in case of missing file.
function getMedia(event) {
	if (!event)
		return false

	let files = media[settings.theme]?.[event] ?? media.default?.[event]
	if (!files?.length)
		return false

	return files[Math.floor(Math.random() * files.length)]
}

function broadcast(data) {
	ws.clients.forEach((client) => {
	if (client.readyState === WebSocket.OPEN)
		client.send(JSON.stringify(data))
	})
}
