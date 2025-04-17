<script>
export default {
  data() {
    return {
      stats: {},
      state: 'idle',
      status: "not connected",
      theme: "default",
      volume: 30,
      scores: [],
      audioElements: [],
      cooldowns: [],
      loadedFiles: 0,
      overlay: { 'event': 'abc', show: false},
      defaultHeaders: [ "Name", "K/D", "Knife K/D", "TK/S", "Øls", "Maps/rounds" ]
    }
  },

  computed: {
    activeScores() {
      let board = {}
      board.headers = [ "Name", "K/D", "Knife K/D", "TK/S", "Øls", "Rounds" ]
      board.scores = this.scores.filter(player => player.active === true)
      board.title = "Scoreboard"
      board.show = true
      board.show = this.state === 'live' || this.state === 'ended'
      if (! board.scores.length)
        board.show = false
      return board
    },
    inactiveScores() {
      let board = {}
      board.headers = [ "Name", "K/D", "Knife K/D", "TK/S", "Øls", "Rounds" ]
      board.scores = this.scores.filter(player => player.active === false)
      board.title = "Inactive/offline"
      board.show = true
      return board
    },
    totalScores() {
      let board = {}
      board.headers = [ "Name (last seen)", "K/D", "Knife K/D", "TK/S", "Øls", "Maps" ]
      board.scores = this.stats.full ?? []
      board.scores.forEach((p) => { p.team = 'neutral' })
      board.title = "No LAN active. All stats:"
      board.show = this.state === 'idle'
      if (! board.scores.length)
        board.show = false
      return board
    },
    todayScores() {
      let board = {}
      board.headers = [ "Name", "K/D", "Knife K/D", "TK/S", "Øls", "Maps" ]
      board.scores = this.stats.today ?? []
      board.scores.forEach((p) => { p.team = 'neutral' })
      board.title = "Stats for today"
      board.show = this.state === 'ended'
      if (! board.scores.length)
        board.show = false
      return board
    },
    lanScores() {
      let board = {}
      board.headers = [ "Name", "K/D", "Knife K/D", "TK/S", "Øls", "Maps" ]
      board.scores = this.stats.lan ?? []
      board.scores.forEach((p) => { p.team = 'neutral' })
      board.title = "Stats for this LAN"
      board.show = this.state === 'ended'
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
      const socket = new WebSocket(import.meta.env.VITE_WEBSOCKET_URI)

      socket.addEventListener('open', (event) => {
        console.log('WebSocket connected!')
        this.status = 'connected'
      })

      socket.addEventListener('close', (event) => {
        console.log('WebSocket disconnected!')
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
      if (process.env.NODE_ENV === 'development')
        console.log('Received socket data: ', data)

      // Handle cooldowns
      if (this.cooldowns.includes(data.cmd))
        return

      let cooldownList = ['suicide', 'mikkitk', 'tk', 'grenade']
      if (cooldownList.includes(data.cmd)) {
        this.cooldowns.push(data.cmd)
        setTimeout(() => {
          this.cooldowns = this.cooldowns.filter(value => value !== data.cmd)
        }, 1000)
      }

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
        case "mapend":
          this.playMedia('assets/media/default/wii/wiishop.mp3')
          break
        case "state":
          this.changeState(data.data)
          break
        case "tk":
        case "mikkitk":
        case "suicide":
        case "bombexploded":
          this.showOverlay(data.cmd, data.args)
          break
        case "unpause":
        case "newround":
        case "round":
          this.stopSound()
          this.overlay.show = false
          break
      }

      this.playMedia(data.media)
    },

    showOverlay: function(cmd, args) {
      // Generate text to display on overlay
      if (cmd === 'tk' || cmd == 'mikkitk') {
        const killer = this.scores.find((p) => p.id == args[0]).name    
        const victim = this.scores.find((p) => p.id == args[1]).name    
        this.overlay.text = `${killer}\nteamkilled\n${victim}`
      } else if (cmd === 'suicide') {
        const victim = this.scores.find((p) => p.id == args[0]).name    
        this.overlay.text = `${victim} committed suicide!` 
      } else if (cmd === 'bombexploded') {
        this.overlay.text = 'Allahu Akbar!'
      } else if (cmd === 'knife') {
        const killer = this.scores.find((p) => p.id == args[0]).name    
        const victim = this.scores.find((p) => p.id == args[1]).name    
        this.overlay.text = `${victim}\nwas knifed by\n${killer}`
      } else {
        this.overlay.text = ''
      }

      this.overlay.show = true
    },

    updateStats: function (data) {
      this.stats = data
      if (this.stats.lan)
        this.stats.lan = this.stats.lan.sort((a, b) => { return b.sips - a.sips })
      if (this.stats.today)
        this.stats.today = this.stats.today.sort((a, b) => { return b.sips - a.sips })
      if (this.stats.full)
        this.stats.full = this.stats.full.sort((a, b) => { return b.sips - a.sips })

      if (process.env.NODE_ENV === 'development')
        console.log('stats', this.stats)
    },

    changeState: function (state) {
      this.state = state
      if (this.state === 'ended') {

      }
    },

    playMedia: function (file) {
      if (!file)
        return

      let soundTypes = [ 'wav', 'mp3', 'ogg' ]
      let videoTypes = [ 'mp4', 'webm' ]
      let ext = file.split('.').pop()

      console.log(`Playing file "${file}"`)
      if (soundTypes.includes(ext))
        this.playSound(file)
      else if (videoTypes.includes(ext))
        this.$refs.overlay.playVideo(file)
      else
        console.log(`Could not determine if "${ext}" is sound or video.`)
    },

    playSound: function (path) {
      if (!path)
        return

      let audio = new Audio(path)
      audio.load()
      audio.addEventListener('canplay', e => {
        audio.volume = this.volume / 100
        audio.play()
      })
      this.audioElements.push(audio)
    },

    stopSound: function () {
      this.$refs.overlay.stopVideo()

      // Pause all playing audio elements and remove them from array
      // Chrome will take care of garbage collection
      this.audioElements.forEach((audio, i, arr) => {
          audio.pause()
      })
      this.audioElements.forEach((audio, i, arr) => {
        if (! audio.paused)
          audio.pause()
        arr.splice(i, 1)
      })
    },

    volumeChange: function () {
      this.$refs.overlay.setVolume(this.volume / 100)
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
  <div class="container-fluid" data-bs-theme="dark">
    <div class="row">
      <div class="col-12 pt-4">
        <div class="container-fluid">
          <div class="status">
            Connection: <pre class="d-inline">{{ status }}</pre><br />
            State: <pre class="d-inline">{{ state }}</pre>
          </div>
          <div class="volume">
            <input class="slider" type="range" name="volume" ref="volume" step="1" id="volume" min="0" max="100" v-model="volume" v-on:change="volumeChange" />
            <label for="volume">Volume</label>
          </div>

          <div class="row w-100">
            <div v-if="todayScores.show" class="scores-today pb-5 col-6">
              <Scoreboard :scoreboard="todayScores.scores" :title="todayScores.title" :headers="todayScores.headers" />
            </div>
            <div v-if="lanScores.show" class="scores-lan pb-5 col-6">
              <Scoreboard :scoreboard="lanScores.scores" :title="lanScores.title" :headers="lanScores.headers" />
            </div>
          </div>

          <div class="row w-100">
            <div v-if="totalScores.show" class="scores-total pb-5 col-12">
              <Scoreboard :scoreboard="totalScores.scores" :title="totalScores.title" :headers="totalScores.headers" />
            </div>
          </div>

          <div v-if="activeScores.show" class="scores-active pb-5">
            <Scoreboard :scoreboard="activeScores.scores" :title="activeScores.title" :headers="activeScores.headers" />
          </div>
          <!--
          <div class="scores-inactive pb-5">
            <Scoreboard v-if="inactiveScores.show" :scoreboard="inactiveScores.scores" :title="inactiveScores.title" />
          </div>
          -->

          <audio ref="audio" id="audio">Audio not available</audio>
        </div>
      </div>
    </div>
  </div>
  <Overlay ref="overlay" :overlay="overlay" />
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
  font-size: 1.5rem;
  padding: .25rem;
  border-color: #ffffff17;
  text-shadow: 0 0 1px rgb(255 255 255 / 50%);
  /*font-family: 'Trebuchet';*/
  background-color: rgb(0 0 0 / 0%);
}

.scores-today .table td, .scores-today .table th, .scores-lan .table td, .scores-lan .table th {
  font-size: 1.25rem;
}

table th {
  color: white;
}

.table tr.neutral {
  color: white;
}

.table tr.UNASSIGNED td {
  background-color: rgb(220 220 220 / 0%);
  color: gray;
}

.table tr.TERRORIST td {
  background-color: rgb(232 4 4 / 0%);
  color: #ea403e;
}

.table tr.CT td {
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
  min-height: 100%;
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

.volume {
  display: inline-block;
  z-index: 10000;
  width: 200px;
  position: fixed;
  right: 20pt;
}

.volume label {
  float: right;
}

.slider {
  appearance: none;
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
  -webkit-appearance: none;
  width: 25px;
  height: 25px;
  border-radius: 50%;
  background: #04AA6D;
  cursor: pointer;
}
</style>
