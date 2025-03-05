#!node

import * as net from "node:net"
import * as readline from "node:readline"

var rl = readline.createInterface({
	input: process.stdin,
	output: process.stdout,
	terminal: true
})

rl.on('line', (cmd) => {
	var cmds = cmd.split(' ')
	var encoded = encode(cmds[0], cmds[1], cmds[2])
	console.log('sending:', encoded)
	client.write(JSON.stringify(encoded))
	rl.prompt()
})

var client = new net.Socket()
client.connect(1337, '127.0.0.1', () => {
	console.log('Connected')
	rl.prompt()
})

client.on('timeout', () => {
	console.log('Connection timed out')
	socket.end();
})

client.on('disconnect', function() {
	console.log('Connection closed')
	client.connect(1337, '127.0.0.1', () => {
		console.log('Reconnected')
		rl.prompt()
	})
})

let encode = function(cmd, name1 = '', name2 = '') {
	return { cmd: cmd, args: [ name1, name2 ] }
}
