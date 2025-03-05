import * as http from 'node:https'
import * as path from 'node:path'
import * as fs from 'node:fs'
import * as url from 'node:url'
import * as log from './utility.mjs'

const dist = 'dist/'
const options = {
	key: fs.readFileSync('tls/key.pem'),
	cert: fs.readFileSync('tls/cert.pem'),
}
const toBool = [() => true, () => false]

const MIME = {
	default: 'application/octet-stream',
	ogg: 'audio/ogg',
	mp4: 'video/mp4',
	ico: 'image/x-icon',
	webm: 'video/webm',
	html: 'text/html',
	js: 'text/javascript',
	json: 'application/json',
	css: 'text/css',
	png: 'image/png',
	jpg: 'image/jpeg',
	wav: 'audio/wav',
	opus: 'audio/ogg',
	mp3: 'audio/mpeg',
	svg: 'image/svg+xml',
	pdf: 'application/pdf',
}

// Finds out if file exists for URL and prepares stream for it
const streamFile = async (url) => {
	const paths = [ dist, url ]
	if (url.endsWith('/')) paths.push('index.html')
	const filePath = path.join(...paths)
	const pathTraversal = !filePath.startsWith(dist)
	const exists = await fs.promises.access(filePath).then(...toBool)
	const found = !pathTraversal && exists
	const streamPath = found ? filePath : dist + '/404.html'
	const ext = path.extname(streamPath).substring(1).toLowerCase()
	const stream = fs.createReadStream(streamPath)
	return { found, ext, stream }
}

export default http.createServer(options, async (req, res) => {
	const file = await streamFile(req.url)
	const code = file.found ? 200 : 404
	const mime = MIME[file.ext] || MIME.default

	res.writeHead(code, { 'Content-Type': mime })
	file.stream.pipe(res)
	log.http(`${req.method} ${req.url} ${code}`)
})
