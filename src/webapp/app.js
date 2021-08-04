import Vue from 'vue'
// import Vuex from 'vuex'
import VueNativeSock from 'vue-native-websocket'

let socketHost = 'wss://cs.nobelnet.dk:27016'
let socketOptions = { 
	protocol: 'beercs',
	format: 'json',
	reconnection: true,
	reconnectionAttemps: 10,
	reconnectionDelay: 2000
}

import {Scoreboard as scoreboard} from './scoreboard.js'

// Vue.use(Vuex)
Vue.use(VueNativeSock, socketHost, socketOptions)

var app = new Vue({
	el: '#app',
	data: {
		status: "not connected",
		theme: "default",
		videopromise: undefined,
		wslog: [],
		volume: 30,
		scores: []
	},
	computed: {
		activeScores() {
			return this.scores.filter(player => player.active == true)
		},
		inactiveScores() {
			return this.scores.filter(player => player.active == false)
		}
	},
	created() {
		this.$options.sockets.onmessage = this.handleMessage
		this.$options.sockets.onopen = () => { this.status = 'connected' }
		this.$options.sockets.onclose = () => { this.status = 'disconnected' }
		this.$options.sockets.onerror = () => { this.status = 'ERROR' }
	},
	methods: {
		handleMessage: function (msg) {
			let data = JSON.parse(msg.data)
			console.log('recieved:', data)

			switch (data.cmd) {
				case "scoreboard":
					this.scores = data.args[0].scores
					break
				case "kill":
					// scoreboard.handleKill('STEAMID:001', 'STEAMID:002')
					break
				case "round":
					//this.playSound()
					break
				case "roundending":
				case "unpause":
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
			if (!path) {
				return	
			}
			this.$refs.audio.src = path
			this.$refs.audio.play()
		},
		playVideo: function (path) {
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

			this.$refs.audio.src = ''
			this.$refs.audio.load()
		},
		volumeChange: function () {
			this.$refs.audio.volume = this.volume / 100
			this.$refs.video.volume = this.volume / 100
		}
	}
})
