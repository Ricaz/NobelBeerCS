#!node

import * as net from "node:net"
import * as readline from "node:readline"

var rl = readline.createInterface({
	input: process.stdin,
	output: process.stdout,
	terminal: true
})

rl.on('line', (input) => {
	var input = input.split(' ')
	let cmd = input[0]

	if (cmd === 'tk') {
		input[1] = 'STEAM_0:0:32762533'
		input[2] = 'STEAM_0:1:11611559'
	} else if (cmd === 'suicide') {
		input[1] = 'STEAM_0:0:32762533'
	}

	var encoded = encode(input[0], input[1], input[2])
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
