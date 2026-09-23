#!node
// Minimal GoldSrc rcon client for the local test server.
//
// Usage: node test/rcon.mjs <command...>
// Env:   RCON_HOST (127.0.0.1), RCON_PORT (27015), RCON_PASSWORD (read from cstrike/server.cfg)

import * as dgram from 'node:dgram'
import * as fs from 'node:fs'

const host = process.env.RCON_HOST ?? '127.0.0.1'
const port = Number(process.env.RCON_PORT ?? 27015)
const password = process.env.RCON_PASSWORD
	?? fs.readFileSync(new URL('../cstrike/server.cfg', import.meta.url), 'utf8').match(/^rcon_password\s+"(.*)"/m)?.[1]
const command = process.argv.slice(2).join(' ')

if (!command) {
	console.log('Usage: node test/rcon.mjs <command...>')
	process.exit(1)
}

const HEADER = Buffer.from([ 0xff, 0xff, 0xff, 0xff ])
const sock = dgram.createSocket('udp4')
let output = ''

sock.on('message', (msg) => {
	const text = msg.subarray(4).toString('latin1')
	const challenge = text.match(/challenge rcon (\d+)/)
	if (challenge)
		sock.send(Buffer.concat([ HEADER, Buffer.from(`rcon ${challenge[1]} "${password}" ${command}\n`) ]), port, host)
	else
		output += text.replace(/^l/, '')
})

sock.send(Buffer.concat([ HEADER, Buffer.from('challenge rcon\n') ]), port, host)

// rcon replies can span several packets, so just collect for a moment
setTimeout(() => {
	process.stdout.write(output)
	sock.close()
}, 1000)
