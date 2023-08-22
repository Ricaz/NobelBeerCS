<script>
export default {
  data() {
    return {
      stats: {},
      state: 'idle',
      status: "not connected",
      theme: "default",
      wslog: [],
      volume: 30,
      scores: [],
      audioElements: [],
      loadedFiles: 0
    }
  },

  computed: {
    showStats() {
      if (this.state == 'idle' || this.state == 'ended')
        return true
      else
        return false
    },
    activeScores() {
      let board = {}
      board.scores = this.scores.filter(player => player.active == true)
      board.title = "Scoreboard"
      board.show = true
      board.show = this.state == 'live' || this.state == 'idle' ? true : false
      return board
    },
    inactiveScores() {
      let board = {}
      board.scores = this.scores.filter(player => player.active == false)
      board.title = "Inactive/offline"
      board.show = true
      return board
    },
    todayScores() {
      let board = {}
      board.scores = this.stats.today || []
      board.scores.forEach((p) => { p.team = 'neutral' })
      board.title = "Stats for today"
      board.show = this.state == 'ended' ? true : false
      if (! board.scores.length)
        board.show = false
      return board
    },
    lanScores() {
      let board = {}
      board.scores = this.stats.lan || []
      board.scores.forEach((p) => { p.team = 'neutral' })
      board.title = "Stats for this LAN"
      board.show = this.state == 'ended' ? true : false
      if (! board.scores.length)
        board.show = false
      return board
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
      const socket = new WebSocket(import.meta.env.VITE_WEBSOCKET_URI, 'beercs')

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
        case "filelist":
          this.preloadAudio(data.data)
          break
        case "stats":
          this.updateStats(data.data)
          break
        case "state":
          this.changeState(data.data)
        case "unpause":
        case "newround":
        case "round":
          this.stopSound()
          break
      }

      this.playMedia(data.media)
    },

    updateStats: function (data) {
      this.stats = data 
      this.stats.lan = this.stats.lan.sort((a, b) => { return b.sips - a.sips })
      this.stats.today = this.stats.today.sort((a, b) => { return b.sips - a.sips })
      console.log('stats', this.stats)
    },

    changeState: function (state) {
      this.state = state
      if (this.state == 'ended') {
         
      }
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
      //  .then(response => response.blob())
      //  .then(blob => {
      //    this.$refs.video.srcObject = blob
      //    return this.$refs.video.play()
      //  })
      //  .then(_ => {
      //    console.log('Playing video, beep boop')
      //  })
      //  .catch(e => {
      //    console.log(`Playing video failed? ${e}`)
      //  })

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
    },

    loadAudioFile: function(url) {
      let audio = new Audio()
      audio.addEventListener('canplaythrough', function() {
        loadedFiles++

      }, false)
      audio.src = url
    },

    preloadAudio: function(soundFiles) {
      // console.log("Loading files:", soundFiles)
    }
  }
}
</script>

<template>
  <div class="container-fluid">
    <div class="row">
      <div class="col-12 pt-4">
        <div class="container-fluid">
          <div class="status">
            Connection: <pre class="d-inline">{{ status }}</pre><br />
            State: <pre class="d-inline">{{ state }}</pre>
          </div>
          <div class="volume">
            <input class="slider" type="range" name="volume" ref="volume" step="5" id="volume" min="0" max="100" v-model="volume" v-on:change="volumeChange" />
            <label for="volume">Volume</label>

          </div>

          <div v-if="todayScores.show" class="scores-today pb-5 col-6">
            <Scoreboard :scoreboard="todayScores.scores" :title="todayScores.title" />
          </div>
          <div v-if="lanScores.show" class="scores-lan pb-5 col-6">
            <Scoreboard :scoreboard="lanScores.scores" :title="lanScores.title" />
          </div>
          <div v-if="activeScores.show" class="scores-active pb-5">
            <Scoreboard :scoreboard="activeScores.scores" :title="activeScores.title" />
          </div>
          <!--
          <div class="scores-inactive pb-5">
            <Scoreboard v-if="inactiveScores.show" :scoreboard="inactiveScores.scores" :title="inactiveScores.title" />
          </div>
          -->

          <audio ref="audio" id="audio">Audio not available</audio>
          <video ref="video" class="hidden" id="video">Video not available</video>
        </div>
        
      </div>
    </div>
  </div>
</template>

<style>
@font-face {
	font-family: 'Trebuchet';
	src: url('fonts/trebuc.ttf');
}

.status { 
	font-family: monospace;
	float: left;
}

.table td, .table th {
	font-size: 1.75rem;
	padding: .25rem;
	border-color: #ffffff17;
	text-shadow: 0px 0px 2px rgb(0 0 0 / 50%);
	font-family: 'Trebuchet';
	background-color: rgb(0 0 0 / 0%);
}

table th {
	color: white;
}

.table tr.neutral {
  color: white;
}

.table tr.UNASSIGNED {
	background-color: rgb(220 220 220 / 0%);
	color: gray;
}

.table tr.TERRORIST {
	background-color: rgb(232 4 4 / 0%);
	color: #ea403e;
}

.table tr.CT {
	background-color: rgb(38 135 255 / 0%);
	color: #00abff;
}

.hidden {
	display: none;
}

.visible {
	display: block;
}

body {
	background-color: #131313;
	color: white;
}

:root {
  font-family: Inter, Avenir, Helvetica, Arial, sans-serif;
  font-size: 16px;
  line-height: 24px;
  font-weight: 400;

  color-scheme: light dark;
  color: rgba(255, 255, 255, 0.87);
  background-color: #242424;

  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  -webkit-text-size-adjust: 100%;
}

video {
	position: fixed;
	top: 0;
	left: 0;
	width: 100%;
	opacity: 50%;
}

.volume {
	display: inline-block;
	z-index: 10000;
  width: 200px;
	float: right;
}

.volume label {
	float: right;
}

.slider {
  -webkit-appearance: none;
  width: 100%;
  height: 10px;
  border-radius: 5px;
  background: #d3d3d3;
  outline: none;
  opacity: 0.7;
  -webkit-transition: .2s;
  transition: opacity .2s;
}

.slider:hover {
  opacity: 1;
}

.slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 25px;
  height: 25px;
  border-radius: 50%;
  background: #04AA6D;
  cursor: pointer;
}

.slider::-moz-range-thumb {
  width: 25px;
  height: 25px;
  border-radius: 50%;
  background: #04AA6D;
  cursor: pointer;
}
</style>
