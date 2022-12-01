const http = require('https')
const path = require('path')
const url = require('url')
const fs = require('fs')
const log = require('./utility').log

const options = {
	key: fs.readFileSync('tls/key.pem'),
	cert: fs.readFileSync('tls/cert.pem'),
}

var server = http.createServer(options, (req, res) => {
	var parsedUrl = url.parse(req.url)

	// var filepath = path.join('./dist/', parsedUrl.pathname)
	var filepath = ''
	if (parsedUrl.pathname == '/')
		filepath = 'dist/index.html'
	else
		filepath = path.join('dist/', parsedUrl.pathname)

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
	}

	var ext = path.parse(filepath).ext
	if (map[ext]) {
		res.setHeader('Content-Type', `${map[ext]}; charset=UTF-8`)
	} else {
		res.setHeader('Content-Type', 'text/plain; charset=UTF-8')
	}

	fs.exists(filepath, (exists) => {
		if (!exists) {
			res.errorCode = 404
			res.end(`File '${filepath}' not found.`)
			return
		}

		// if video
		if (map[ext] && map[ext].includes('video')) {
			fileStream = fs.createReadStream(filepath)
			fileStream.on('error', (e) => log.http(`Error reading '${filepath}': ${e}`))
			fileStream.on('data', (chunk) => res.write(chunk))
			fileStream.on('close', (chunk) => res.end())
			log.http(`Streamed '${req.url}' to ${req.connection.remoteAddress}.`)
			return
		}

		fs.readFile(filepath, function(err, data){
			if(err){
				res.statusCode = 500
				err += `\n${filepath}`
				log.http(`Error serving '${req.url}: ${err}`)
				res.end(`Hvem har hældt øl i serveren?!\n${err}`)
			} else {
				res.end(data)
			}
		})
	})

})

module.exports = server
