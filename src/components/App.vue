<script>
export default {
  data() {
    return {
      status: "not connected",
      theme: "default",
      wslog: [],
      volume: 30,
      scores: [],
      audioElements: []
      }
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
    }
  }
}
</script>

<template>
  <div class="container-fluid">
    <div class="row">
      <div class="col-12 pt-4">
        <div class="container-fluid">
          <div class="status">Status: <pre class="d-inline">{{ status }}</pre></div>
          <div class="volume">
            <input type="range" name="volume" ref="volume" step="5" id="volume" min="0" max="100" v-model="volume" v-on:change="volumeChange" />
            <label for="volume">Volume</label>
          </div>
          <div class="scores-active pb-5">
            <h1 class="text-center">Scoreboard</h1>
            <table class="table table-fluid">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>K/D</th>
                  <th>Knife K/D</th>
                  <th>TKs</th>
                  <th>Suicides</th>
                  <th>Sips</th>
                  <th>Rounds</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="player in activeScores" :class="player.team">
                  <td>{{ player.name }}</td>
                  <td><b>{{ player.kills }}</b> / {{ player.deaths }}</td>
                  <td><b>{{ player.knifekills }}</b> / {{ player.knifed }}</td>
                  <td>{{ player.teamkills }}</td>
                  <td>{{ player.suicides }}</td>
                  <td>{{ player.sips }}</td>
                  <td>{{ player.rounds }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="scores-inactive mt-5">
            <h1 class="text-center">Inactive</h1>
            <table class="table table-dark table-fluid">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>K/D</th>
                  <th>Knife K/D</th>
                  <th>TKs</th>
                  <th>Suicides</th>
                  <th>Sips</th>
                  <th>Rounds</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="player in inactiveScores" :class="player.team">
                  <td>{{ player.name }}</td>
                  <td><b>{{ player.kills }}</b> / {{ player.deaths }}</td>
                  <td><b>{{ player.knifekills }}</b> / {{ player.knifed }}</td>
                  <td>{{ player.teamkills }}</td>
                  <td>{{ player.suicides }}</td>
                  <td>{{ player.sips }}</td>
                  <td>{{ player.rounds }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <audio ref="audio" id="audio">Audio not available</audio>
          <video ref="video" class="hidden" id="video">Video not available</video>
        </div>
        
      </div>
    </div>
  </div>
</template>

<style>
.table td, .table th {
	font-size: 1.75rem;
	padding: .25rem;
	border-color: rgba(0,0,0,0.3);
	text-shadow: 0px 0px 4px rgb(255 255 255 / 77%);
	font-family: 'Arial';
}

.table tr.UNASSIGNED {
	background-color: rgb(220 220 220 / 90%);
}

.table tr.TERRORIST {
	background-color: rgb(232 4 4 / 80%);
	color: white;
}

.table tr.CT {
	background-color: rgb(38 135 255 / 80%);
	color: white;
}

.hidden {
	display: none;
}

.visible {
	display: block;
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
	opacity: 65%;
}

.volume {
	display: inline-block;
	position: absolute;
	right: 12pt;
	z-index: 10000;
}
</style>
