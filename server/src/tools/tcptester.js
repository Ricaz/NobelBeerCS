#!node

const net = require('net')
const readline = require('readline')

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

client.on('disconnect', function() {
	console.log('Connection closed')
})

let encode = function(cmd, name1 = '', name2 = '') {
	return { cmd: cmd, args: [ name1, name2 ] }
}
