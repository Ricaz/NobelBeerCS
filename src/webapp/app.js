import Vue from 'vue'
import VueNativeSock from 'vue-native-websocket'

let socketHost = 'ws://localhost:8080';
let socketOptions = { 
	protocol: 'beercs',
	format: 'json',
	reconnection: true,
	reconnectionAttemps: 10,
	reconnectionDelay: 2000
}

Vue.use(VueNativeSock, socketHost, socketOptions)

var app = new Vue({
	el: '#app',
	data: {
		status: "Hello World!",
		sounds: [
			'combowhore.mp3',
			'dominating.mp3',
			'doublekill.mp3',
			'firstblood.mp3',
			'godlike.mp3',
			'hattrick.wav',
			'headhunter.wav',
			'headshot.mp3',
			'holyshit.mp3',
			'humiliation.mp3',
			'impressive.mp3',
			'killingspree.mp3',
			'ludicrouskill.mp3',
			'megakill.mp3',
			'monsterkill.mp3',
			'multikill.mp3',
			'perfect.mp3',
			'play.wav',
			'prepare.mp3',
			'rampage.mp3',
			'teamkiller.mp3',
			'triplekill.mp3',
			'ultrakill.mp3',
			'unstoppable.mp3',
			'wickedsick.mp3'
		],
		videos: [ '1.webm' ],
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

			switch (data.cmd) {
				case "kill":
					this.playSound()
					break
				case "round":
					this.playSound()
					break
			}
		},
		playSound: function (e) {
			let sound = 'sounds/' + this.sounds[Math.floor(Math.random() * this.sounds.length)]
			console.log('playing audio', sound)
			this.$refs.audio.src = sound
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
 
// function handleMessage(msg) {
// 	app.data.message = msg.data
// 	app.data.wslog.push(msg.data)
// }
