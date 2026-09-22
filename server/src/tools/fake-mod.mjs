#!node
// Simulates the AMXX mod by sending a short game's worth of events over UDP,
// the same way the plugin does. Useful for testing the web app without a CS server.
//
// Usage: node src/tools/fake-mod.mjs [host] [port] [delay-ms]

import * as dgram from 'node:dgram'

const host  = process.argv[2] ?? '127.0.0.1'
const port  = Number(process.argv[3] ?? 1337)
const delay = Number(process.argv[4] ?? 1500)

const players = [
	{ id: 'STEAM_0:0:1001', name: 'Alice', team: 'TERRORIST' },
	{ id: 'STEAM_0:0:1002', name: 'Bob', team: 'TERRORIST' },
	{ id: 'STEAM_0:0:1003', name: 'Carol', team: 'CT' },
	{ id: 'STEAM_0:0:1004', name: 'Dave', team: 'CT' },
]
const [ a, b, c, d ] = players.map((p) => p.id)

const script = [
	{ cmd: 'mapchange', args: [ 'de_dust2' ] },
	...players.map((p) => ({ cmd: 'playerjoined', args: p })),
	{ cmd: 'balance', args: { games: 5 } },
	{ cmd: 'firstround' },
	{ cmd: 'playersync', args: players },
	{ cmd: 'roundstart' },
	{ cmd: 'kill', args: [ a, c ] },
	{ cmd: 'headshot', args: [ d, b ] },
	{ cmd: 'knife', args: [ a, d ], sound: 'jeppeknife' },
	{ cmd: 'alone' },
	{ cmd: 'round' },
	{ cmd: 'roundstart' },
	{ cmd: 'tk', args: [ c, d ] },
	{ cmd: 'unpause' },
	{ cmd: 'suicide', args: [ b ] },
	{ cmd: 'grenade', args: [ c, a ] },
	{ cmd: 'mapend' },
]

const sock = dgram.createSocket('udp4')
sock.on('message', (msg) => console.log('reply:', msg.toString()))
sock.connect(port, host, async () => {
	for (const event of script) {
		console.log('sending:', JSON.stringify(event))
		sock.send(JSON.stringify(event) + '\n')
		await new Promise((resolve) => setTimeout(resolve, delay))
	}
	sock.close()
})
