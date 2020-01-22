#!node
'use strict'

// Load config from .env
require('dotenv').config()

// Load system/npm modules
const net	= require('net')
const WSs	= require('websocket').server
const exec	= require('child_process').exec
const path	= require('path')
const fs	= require('fs')

// Load custom modules
const http	= require('./http-server')
const log	= require('./utility').log
const player = require('./utility').player

// Global vars
var clientsWs	= []
var clientsTcp	= []
var readyTcp	= false
var readyWs		= false
var connID		= 0

// Create TCP socket server and set up event handling on it
var tcp = net.createServer((sock) => {
	var host = exIP(sock.remoteAddress)
	log.tcp('Client connected from ' + host) 
	sock.setEncoding('utf8')

	sock.on('data', (data) => {
		let cmd = decodeTCPMessage(data).cmd
		log.tcp(`[${host}]: ${cmd}`)
		
		// Forward to WS clients
		clientsWs.forEach((client) => { client.send(data) })
		log.ws(`Forwarded to ${clientsWs.length} clients.`)
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

	conn.on('message', (data) => {
		log.ws(`[${conn.id}]: ${data}`)
	})

	conn.on('close', (reason, description) => {
		log.ws(`[${conn.id}] Disconnected.`)
	})
})

// Create object from "encoded" string
function decodeTCPMessage(msg) {
	let out = {}

	let split = msg.split("|€@!|")
	return { 'cmd': split.shift(), 'args': split }
}

// Helper functions
// RNG
function rng(min, max) {
	min = Math.floor(min)
	max = Math.floor(max) + 1
	return Math.floor(Math.random() * (max - min) + min)
}

// Extract IP from socket.remoteAddress
function exIP (host) {
	host = host.split(':')
	return host[host.length - 1]
}
