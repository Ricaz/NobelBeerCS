const http = require('http')
const path = require('path')
const url = require('url')
const fs = require('fs')
const log = require('./utility').log

var server = http.createServer((req, res) => {
	log.http(`${req.method} ${req.url}`)

	var parsedUrl = url.parse(req.url)

	// var filepath = path.join('./dist/', parsedUrl.pathname)
	var filepath = ''
	if (parsedUrl.pathname == '/')
		filepath = 'dist/stats.html'
	else
		filepath = path.join('dist/assets/', parsedUrl.pathname)

	const map = {
		'.ogg': 'audio/ogg',
		'.mp4': 'video/mp4',
		'.ico': 'image/x-icon',
		'.webm': 'video/webm',
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
	if (map[ext]) { 
		res.setHeader('Content-Type', `${map[ext]}; charset=utf-8`);
	} else {
		res.setHeader('Content-Type', 'text/plain; charset=utf-8');
	}

	fs.exists(filepath, (exists) => {
		if (!exists) {
			res.errorCode = 404
			res.end(`Nope!\n${filepath}`)
		}

		fs.readFile(filepath, function(err, data){
			if(err){
				res.statusCode = 500
				err += `\n${filepath}`
				log.http(`Error serving '${req.url}: ${err}`)
				res.end(`Hvem har hældt øl i serveren?!\n${err}`)
			} else {
				res.end(data)
				log.http(`Served '${req.url}' to ${req.connection.remoteAddress}.`)
			}
		});
	})

})

module.exports = server
