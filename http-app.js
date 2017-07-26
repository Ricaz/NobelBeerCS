const http = require('http')
const path = require('path')
const url = require('url')
const fs = require('fs')
const log = require('./utility').log

const server = http.createServer((req, res) => {
	log.http(`${req.method} ${req.url}`)

	var parsedUrl = url.parse(req.url)

	var filepath = '.' + parsedUrl.pathname
	if (filepath == './')
		filepath = './stats.html'

	const map = {
		'.ico': 'image/x-icon',
		'.html': 'text/html',
		'.js': 'text/javascript',
		'.json': 'application/json',
		'.css': 'text/css',
		'.png': 'image/png',
		'.jpg': 'image/jpeg',
		'.wav': 'audio/wav',
		'.mp3': 'audio/mpeg',
		'.svg': 'image/svg+xml',
		'.pdf': 'application/pdf',
	};

	var ext = path.parse(filepath).ext

	fs.exists(filepath, (exists) => {
		if (!exists) {
			if (filepath == '/') {
				filepath += 'stats.html'
			} else {
				res.errorCode = 404
				res.end(`Nope!`)
			}
		}

		fs.readFile(filepath, function(err, data){
			if(err){
				res.statusCode = 500;
				res.end(`Hvem har hældt øl i serveren?!: ${err}`);
			} else {
				res.setHeader('Content-Type', map[ext] || 'text/plain' );
				res.end(data);
			}
		});
	})

})

module.exports = server
