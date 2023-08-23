#!node
'use strict'

// Load config from .env
require('dotenv').config()

// Load system/npm modules
const net  = require('net')
const WSs  = require('websocket').server
const exec = require('child_process').exec
const fs   = require('fs')
const path = require('path')

// Load custom modules
const http         = require('./lib/http-server')
const log          = require('./lib/utility').log
const scoretracker = require('./lib/scoretracker')

// Global vars
var clientsWs  = []
var clientsTcp = []
var readyTcp   = false
var readyWs    = false
var connID     = 0
var settings   = {
	theme: 'default'
}

const mediaPath = 'dist/assets/media/'
var themes		= loadThemes()

var tracker = new scoretracker()
tracker.on('state', (state) => {
	clientsWs.forEach((client) => { client.send(JSON.stringify({ cmd: 'state', data: state })) })
})
tracker.on('stats', (stats) => {
	clientsWs.forEach((client) => { client.send(JSON.stringify({ cmd: 'stats', data: stats })) })
})
tracker.on('game-ended', () => {
	clientsWs.forEach((client) => { client.send(JSON.stringify({ cmd: 'game-ended' })) })
})

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
				clientsWs.forEach((client) => { client.send(JSON.stringify(stats)) })
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
			clientsWs.forEach((client) => { client.send(JSON.stringify(fullState)) })

			// Handle media
			if (message.cmd === 'theme' && themes.includes(message.args[0])) {
				log.tcp(`Switched theme from '${settings.theme}' to '${message.args[0]}'.`)
				settings.theme = message.args[0]
			}

			if (getMedia(message.cmd)) {
				message.media = getMedia(message.cmd)
			}

			// Forward to WS clients
			clientsWs.forEach((client) => { client.send(JSON.stringify(message)) })
		}
	})

	sock.on('error', (err) => {
		log.tcp(err)
	})

	clientsTcp.push(sock)
	sock.pipe(sock)
})

tcp.listen(process.env.PORT_TCP, () => {
	readyTcp = true
	log.tcp('Socket listening on ' + process.env.PORT_TCP)
})

http.listen(process.env.PORT_HTTP, (err) => {
	if (err)
		return log.tcp('http.listen() error: ' + err)

	log.http('Server listening on ' + process.env.PORT_HTTP)
})

var ws = new WSs({
	httpServer: http,
	autoAcceptConnections: false
})

ws.on('request', (req) => {
	let connection = req.accept('beercs', req.origin)
})

ws.on('connect', (conn) => {
	conn.id = connID++
	clientsWs[conn.id] = conn
	log.ws(`[${conn.id}] Connected from ${conn.socket.remoteAddress}.`)

	log.ws('Sending full state.')
	var fullState = { cmd: 'scoreboard', args: [ tracker.getScoreboard() ] }
	conn.send(JSON.stringify(fullState))

  // Send list of files
	conn.send(JSON.stringify({ cmd: 'filelist', data: getMediaList() }))

	conn.on('message', (data) => {
		log.ws(`[${conn.id}]: ${data}`)
	})

	conn.on('close', (reason, description) => {
		log.ws(`[${conn.id}] Disconnected.`)
	})
})

function getAllFiles(dirPath, arrayOfFiles) {
	var files = fs.readdirSync(dirPath)
	var arrayOfFiles = arrayOfFiles || []

	files.forEach(function(file) {
		if (fs.statSync(dirPath + "/" + file).isDirectory())
			arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles)
		else
			arrayOfFiles.push(path.join(__dirname, dirPath, "/", file))
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

// Helper functions
// RNG
function rng(min, max) {
	min = Math.floor(min)
	max = Math.floor(max) + 1
	return Math.floor(Math.random() * (max - min) + min)
}
