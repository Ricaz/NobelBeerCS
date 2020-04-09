import Vue from 'vue'
// import Vuex from 'vuex'
import VueNativeSock from 'vue-native-websocket'

let socketHost = 'wss://localhost:8080'
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
		status: "connected",
		wslog: [],
		scores: [
			{
				name: 'lols',
				kills: 5,
				teamkills: 1,
				knifekills: 1,
				knifed: 0,
				sips: 35,
				rounds: 4
			},
			{
				name: 'Kaptajn Haddock',
				kills: 9,
				teamkills: 0,
				knifekills: 9,
				knifed: 0,
				sips: 49,
				rounds: 5
			},
			{
				name: 'KAJANTHAN KAKATARZAN',
				kills: 0,
				teamkills: 6,
				knifekills: 9,
				knifed: 32,
				sips: 291,
				rounds: 19
			},
		]
	},
	created() {
		this.$options.sockets.onmessage = this.handleMessage
	},
	methods: {
		handleMessage: function (msg) {
			let data = JSON.parse(msg.data)
			console.log('recieved:', data)
			this.status = data.cmd
			this.wslog.push(data)
			this.playSound(data.playsound)

			switch (data.cmd) {
				case "kill":
					// scoreboard.handleKill('STEAMID:001', 'STEAMID:002')
					break
				case "round":
					//this.playSound()
					break
			}
		},
		playSound: function (path) {
			if (!path) {
				return	
			}
			this.$refs.audio.src = path
			this.$refs.audio.play()
		},
		playVideo: function (e) {
			let video = 'videos/' + this.videos[Math.floor(Math.random() * videos.length)]
			console.log('playing video', video)
			this.$refs.video.src = video
			this.$refs.video.play()
		}
	}
})
