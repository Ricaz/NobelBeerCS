#!node
// Extracts the killfeed icons (d_ak47, d_headshot, ...) from your own Counter-Strike 1.6
// install into public/assets/killfeed/, for the web app's killfeed. The icons are Valve's,
// so they are not committed to the repo; run this once, then `npm run build`.
//
// Usage: node src/tools/extract-killfeed-icons.mjs [path to cstrike dir]

import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import zlib from 'node:zlib'

const cstrike = process.argv[2] ?? path.join(os.homedir(), '.local/share/Steam/steamapps/common/Half-Life/cstrike')
const outDir = path.resolve('public/assets/killfeed')
const sprites = path.join(cstrike, 'sprites')

if (!fs.existsSync(path.join(sprites, 'hud.txt'))) {
	console.error(`No sprites/hud.txt in ${cstrike}. Pass the path to your cstrike directory.`)
	process.exit(1)
}

// hud.txt lines: <name> <resolution> <sprite file> <x> <y> <width> <height>
const icons = fs.readFileSync(path.join(sprites, 'hud.txt'), 'latin1')
	.split(/\r?\n/)
	.map((line) => line.trim().split(/\s+/))
	.filter(([ name, res ]) => name?.startsWith('d_') && res === '640')
	.map(([ name, , sprite, x, y, width, height ]) => ({ name: name.slice(2), sprite, x: +x, y: +y, width: +width, height: +height }))

// GoldSrc .spr (version 2): header, palette, then frames of palette indices
function readSprite(file) {
	const buf = fs.readFileSync(file)
	if (buf.toString('ascii', 0, 4) !== 'IDSP' || buf.readInt32LE(4) !== 2)
		throw new Error(`${file} is not a GoldSrc sprite`)

	const texFormat = buf.readInt32LE(12)
	const colors = buf.readInt16LE(40)
	const palette = buf.subarray(42, 42 + colors * 3)
	const frame = 42 + colors * 3
	const width = buf.readInt32LE(frame + 12), height = buf.readInt32LE(frame + 16)
	return { texFormat, palette, width, height, pixels: buf.subarray(frame + 20, frame + 20 + width * height) }
}

// Opacity of one pixel. HUD sprites are grayscale and tinted by the game, so only
// the opacity matters; the web app tints them with CSS.
function alpha(sprite, index) {
	switch (sprite.texFormat) {
		case 1: // additive: brightness is opacity, black is transparent
			return Math.max(...sprite.palette.subarray(index * 3, index * 3 + 3))
		case 2: // index is opacity
			return index
		case 3: // last color is transparent
			return index === 255 ? 0 : 255
		default:
			return 255
	}
}

// Minimal RGBA PNG encoder
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
	let c = n
	for (let k = 0; k < 8; k++)
		c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
	return c >>> 0
})

function crc32(buf) {
	let c = 0xffffffff
	for (const byte of buf)
		c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8)
	return (c ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
	const out = Buffer.alloc(12 + data.length)
	out.writeUInt32BE(data.length, 0)
	out.write(type, 4, 'ascii')
	data.copy(out, 8)
	out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length)
	return out
}

function png(width, height, rgba) {
	const header = Buffer.alloc(13)
	header.writeUInt32BE(width, 0)
	header.writeUInt32BE(height, 4)
	header.set([ 8, 6, 0, 0, 0 ], 8) // 8-bit RGBA
	const rows = Buffer.alloc((width * 4 + 1) * height)
	for (let y = 0; y < height; y++)
		rgba.copy(rows, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4)
	return Buffer.concat([
		Buffer.from([ 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a ]),
		chunk('IHDR', header),
		chunk('IDAT', zlib.deflateSync(rows)),
		chunk('IEND', Buffer.alloc(0)),
	])
}

fs.mkdirSync(outDir, { recursive: true })
const cache = {}
const manifest = {}

for (const icon of icons) {
	const sprite = cache[icon.sprite] ??= readSprite(path.join(sprites, `${icon.sprite}.spr`))
	const rgba = Buffer.alloc(icon.width * icon.height * 4)
	for (let y = 0; y < icon.height; y++) {
		for (let x = 0; x < icon.width; x++) {
			const index = sprite.pixels[(icon.y + y) * sprite.width + icon.x + x]
			rgba.set([ 255, 255, 255, alpha(sprite, index) ], (y * icon.width + x) * 4)
		}
	}
	fs.writeFileSync(path.join(outDir, `${icon.name}.png`), png(icon.width, icon.height, rgba))
	manifest[icon.name] = { width: icon.width, height: icon.height }
}

fs.writeFileSync(path.join(outDir, 'icons.json'), JSON.stringify(manifest))
console.log(`Extracted ${icons.length} icons to ${outDir}: ${Object.keys(manifest).join(', ')}`)
console.log('Run `npm run build` to include them in the web app.')
