import { createApp } from 'vue'

const app = createApp({
	el: '#app',
	data: {
		status: "not connected",
		theme: "default",
		wslog: [],
		volume: 30,
		scores: [],
		audioElements: []
	},
	computed: {
		activeScores() {
			return this.scores.filter(player => player.active == true)
		},
		inactiveScores() {
			return this.scores.filter(player => player.active == false)
		}
	},
	mounted() {
		this.connectWebSocket()
	},
	created() {
		this.audioElements.forEach((audio) => { audio.volume = this.volume / 100 })
	},
	methods: {
		connectWebSocket: function() {
			const socket = new WebSocket(process.env.WEBSOCKET_URI, 'beercs')

			socket.addEventListener('open', (event) => {
				console.log('WebSocket conncted!', event)
				this.status = 'connected'
			})

			socket.addEventListener('close', (event) => {
				console.log('WebSocket disconncted!', event)
				this.status = 'disconnected'
				setTimeout(() => { this.connectWebSocket() }, 2000)
			})

			socket.addEventListener('error', (event) => {
				console.log('WebSocket error!', event)
				this.status = 'ERROR'
			})

			socket.addEventListener('message', this.handleMessage)
		},
		handleMessage: function (msg) {
			let data = JSON.parse(msg.data)
			console.log('Recieved socket data: ', data)

			switch (data.cmd) {
				case "scoreboard":
					this.scores = data.args[0].scores
					break
				case "unpause":
				case "newround":
				case "round":
					this.stopSound()
					break
			}

			this.playMedia(data.media)
		},
		playMedia: function (file) {
			if (!file)
				return

			let soundTypes = [ 'wav', 'mp3' ]
			let videoTypes = [ 'ogg', 'mp4', 'webm' ]
			let ext = file.split('.').pop()

			if (soundTypes.includes(ext))
				this.playSound(file)
			else if (videoTypes.includes(ext))
				this.playVideo(file)
			else
				console.log(`Could not determine if "${ext}" is sound or video.`)
		},
		playSound: function (path) {
			if (!path)
				return	

			var audio = new Audio(path)
			audio.load()
			audio.addEventListener('canplay', e => {
				audio.volume = this.volume / 100
				audio.play()
			})
			this.audioElements.push(audio)
		},
		playVideo: function (path) {
			// Attempt at streaming
			//this.$refs.video.load()
			//fetch(path)
			//	.then(response => response.blob())
			//	.then(blob => {
			//		this.$refs.video.srcObject = blob
			//		return this.$refs.video.play()
			//	})
			//	.then(_ => {
			//		console.log('Playing video, beep boop')
			//	})
			//	.catch(e => {
			//		console.log(`Playing video failed? ${e}`)
			//	})

			this.$refs.video.classList.remove('hidden')
			this.$refs.video.src = path
			this.$refs.video.play()
		},
		stopSound: function () {
			this.$refs.video.src = ''
			this.$refs.video.load()
			this.$refs.video.classList.add('hidden')

			// Pause all playing audio elements and remove them from array
			// Chrome will take care of garbage collection
			this.audioElements.forEach((audio, i, arr) => {
				if (! audio.paused)
					audio.pause()
				arr.splice(i, 1)
			})
		},
		volumeChange: function () {
			this.$refs.video.volume = this.volume / 100
			this.audioElements.forEach((audio, i, arr) => {
				audio.volume = this.volume / 100
			})
		}
	}
})
