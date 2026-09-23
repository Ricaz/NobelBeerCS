<script>
const HEADERS = [ "Name", "K/D", "Knife K/D", "TK/S", "Øls", "Rounds" ]
const STATS_HEADERS = [ "Name", "K/D", "Knife K/D", "TK/S", "Øls", "Maps" ]
const COOLDOWN_EVENTS = [ 'grenade' ]
// Teamkills and suicides that happen close together (without a pause in between)
// are summed up on one overlay
const SHAME_WINDOW = 3000
const KILL_EVENTS = [ 'kill', 'headshot', 'knife', 'grenade', 'tk', 'suicide', 'kniferound', 'bong' ]

// A 10 ms silent WAV file, for testing whether the browser allows sound
function silentWav() {
  const samples = 80, header = 44
  const view = new DataView(new ArrayBuffer(header + samples))
  const text = (offset, s) => [ ...s ].forEach((c, i) => view.setUint8(offset + i, c.charCodeAt(0)))
  text(0, 'RIFF'); view.setUint32(4, header - 8 + samples, true); text(8, 'WAVE')
  text(12, 'fmt '); view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, 1, true)
  view.setUint32(24, 8000, true); view.setUint32(28, 8000, true); view.setUint16(32, 1, true); view.setUint16(34, 8, true)
  text(36, 'data'); view.setUint32(40, samples, true)
  for (let i = 0; i < samples; i++)
    view.setUint8(header + i, 128) // 8-bit silence
  return URL.createObjectURL(new Blob([ view ], { type: 'audio/wav' }))
}

function board(title, headers, scores, show) {
  return { title, headers, scores, show: show && scores.length > 0 }
}

// Stats boards are not team-colored
function neutral(scores = []) {
  return scores.map((p) => ({ ...p, team: 'neutral' }))
}

export default {
  data() {
    return {
      stats: {},
      state: 'idle',
      status: "not connected",
      volume: 30,
      scores: [],
      audioElements: [],
      cooldowns: [],
      // lines: [ [ { text, team } ] ], names get their team's color
      overlay: { lines: [], show: false, summary: false },
      // Teamkills and suicides since the game last resumed: { type: 'tk', killer, victim } | { type: 'suicide', player }
      shame: [],
      shameAt: 0,
      // End-of-map awards while they are shown
      awards: null,
      awardsTimer: null,
      // The scoreboard as it was when the game ended, shown with the awards
      finalScores: null,
      // Bumped on every game start to show the "LIVE LIVE LIVE" banner (0 = hidden)
      liveBanner: 0,
      // The browser won't play sound until someone clicks or presses a key on the page
      soundBlocked: false,
      socket: null,
      // 'lan': the active LAN (live scoreboard or LAN stats), 'all': all-time stats
      mode: 'all',
      allStats: [],
      allHighlights: null,
      // LAN events for the dropdown, and the selected one ('' = all time)
      lans: [],
      selectedLan: '',
      loadingAll: false,
      // The game is paused (killfeed timers stop)
      paused: false,
      // Don't slide on page load, only on later switches
      animate: false,
      hasState: false,
    }
  },

  computed: {
    activeScores() {
      // Right after a game, the snapshot: by then everyone has left and switched teams
      if (this.finalScores)
        return board("Final scoreboard", HEADERS, this.finalScores, true)
      const live = this.state === 'live' || this.state === 'ended'
      return board("Scoreboard", HEADERS, this.scores.filter(p => p.active === true), live)
    },
    lanActive() {
      return this.state === 'live' || this.state === 'ended'
    },
    allScores() {
      return board(null, [ "Name (last seen)", ...STATS_HEADERS.slice(1) ], neutral(this.allStats), true)
    },
    sessionScores() {
      return board("Stats for last session", STATS_HEADERS, neutral(this.stats.session), this.state === 'ended')
    },
    lanScores() {
      return board("Stats for this LAN", STATS_HEADERS, neutral(this.stats.lan), this.state === 'ended')
    }
  },

  mounted() {
    this.connectWebSocket()
    this.checkSound()
    // Any click or key press lets the browser play sound; check again then
    for (const event of [ 'pointerdown', 'keydown' ])
      window.addEventListener(event, () => { if (this.soundBlocked) this.checkSound() })
  },

  methods: {
    connectWebSocket: function() {
      const socket = new WebSocket(import.meta.env.VITE_WEBSOCKET_URI)
      this.socket = socket

      socket.addEventListener('open', (event) => {
        console.log('WebSocket connected!')
        this.status = 'connected'
      })

      socket.addEventListener('close', (event) => {
        console.log('WebSocket disconnected!')
        this.status = 'disconnected'
        this.loadingAll = false
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
      if (import.meta.env.DEV)
        console.log('Received socket data: ', data)

      // Every kill goes in the killfeed, also during sound cooldowns
      this.addToKillFeed(data)

      // A second teamkill/suicide in the same pause only updates the overlay text,
      // it doesn't restart the video or sound
      if ((data.cmd === 'tk' || data.cmd === 'suicide') && this.addToShame(data))
        return

      // Handle cooldowns
      if (this.cooldowns.includes(data.cmd))
        return

      if (COOLDOWN_EVENTS.includes(data.cmd)) {
        this.cooldowns.push(data.cmd)
        setTimeout(() => {
          this.cooldowns = this.cooldowns.filter(value => value !== data.cmd)
        }, 1000)
      }

      switch (data.cmd) {
        case "scoreboard":
          this.scores = data.args[0].scores
          break
        case "stats":
          this.stats = data.data
          if (data.data.lans)
            this.lans = data.data.lans
          // Idle stats are the all-time stats, unless a LAN is picked
          if (data.data.all && !this.selectedLan)
            this.applyAllStats(data.data.all)
          break
        case "allstats":
          this.applyAllStats(data.data)
          this.loadingAll = false
          // Let the page render offscreen before sliding to it
          this.$nextTick(() => requestAnimationFrame(() => { this.mode = 'all' }))
          break
        case "mapend":
          this.playMedia('assets/media/default/wii/wiishop.mp3')
          break
        case "state":
          this.changeState(data.data)
          break
        case "bombexploded":
          this.overlay.lines = [ [ { text: 'Allahu Akbar!' } ] ]
          this.overlay.summary = false
          this.overlay.show = true
          break
        case "awards":
          this.awards = data.data.awards
          this.finalScores = data.data.scores
          clearTimeout(this.awardsTimer)
          this.awardsTimer = setTimeout(() => {
            // The LAN stats slide in, also on a page opened during the awards
            this.animate = true
            this.awards = null
            this.finalScores = null
          }, data.data.left)
          break
        case "paused":
          this.paused = true
          break
        case "resumed":
          this.paused = false
          this.shame = []
          break
        case "firstround":
          this.liveBanner++
          this.paused = false
          this.shame = []
          this.$refs.killfeed?.clear()
          break
        case "unpause":
        case "newround":
        case "round":
          this.stopSound()
          this.overlay.show = false
          this.shame = []
          break
      }

      this.playMedia(data.media)
    },

    changeState: function (state) {
      const previous = this.state
      this.state = state

      // A new game takes over the screen
      if (state === 'live') {
        this.awards = null
        this.finalScores = null
      }

      // Slide on automatic switches too, except for the first state on page load
      if (this.hasState)
        this.animate = true
      this.hasState = true

      // No LAN: only all-time stats. A game starting always gets the screen.
      if (state === 'idle')
        this.mode = 'all'
      else if (state === 'live' || previous === 'idle')
        this.mode = 'lan'
    },

    showLan: function () {
      if (!this.lanActive)
        return
      this.animate = true
      this.mode = 'lan'
    },

    // Fetches fresh stats for the selected LAN (or all time), then slides to them
    showAll: function () {
      if (this.mode === 'all')
        return
      this.animate = true
      this.requestStats()
    },

    selectLan: function (event) {
      this.selectedLan = event.target.value ? Number(event.target.value) : ''
      this.animate = true
      this.requestStats()
    },

    requestStats: function () {
      if (this.loadingAll || this.socket?.readyState !== WebSocket.OPEN)
        return
      this.loadingAll = true
      const args = this.selectedLan ? { scope: 'lan', id: this.selectedLan } : { scope: 'all' }
      this.socket.send(JSON.stringify({ cmd: 'getstats', args }))
    },

    applyAllStats: function (data) {
      this.allStats = data.scores
      this.allHighlights = data.highlights
      this.lans = data.lans
      this.selectedLan = data.lan ?? ''
    },

    lanLabel: function (lan) {
      const date = (time) => new Date(time).toLocaleDateString('da-DK', { day: 'numeric', month: 'short' })
      return `${lan.name} · ${date(lan.start)}–${date(lan.end)} · ${lan.games} ${lan.games === 1 ? 'map' : 'maps'}`
    },

    addToKillFeed: function (data) {
      if (!KILL_EVENTS.includes(data.cmd) || !this.$refs.killfeed)
        return

      const [ first, second ] = data.args ?? []
      const player = (id) => {
        const p = this.scores.find((p) => p.id == id)
        return { name: p?.name ?? '???', team: p?.team }
      }
      // Older plugin versions don't send the weapon: guess from the event, or show a generic gun
      const weapon = data.weapon ?? { knife: 'knife', grenade: 'grenade', suicide: null }[data.cmd] ?? 'unknown'

      if (data.cmd === 'suicide' || first === second)
        this.$refs.killfeed.add({ victim: player(second ?? first), weapon, suicide: true })
      else if (second)
        this.$refs.killfeed.add({
          killer: player(first),
          victim: player(second),
          weapon,
          headshot: data.headshot || data.cmd === 'headshot',
          teamkill: data.cmd === 'tk',
        })
    },

    // Game start: the LAN stats fly out to the sides and collapse, so the
    // fresh scoreboard below moves up. Game end: the reverse.
    animateLanStats: function (el, done, entering) {
      // Not on page load (the first state), and never on top of a running animation:
      // stop that first, and only let the latest one finish
      el.getAnimations({ subtree: true }).forEach((a) => a.cancel())
      if (!this.animate || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        el.style.overflow = ''
        return done()
      }
      const token = el.lanStatsAnimation = {}

      const timing = { duration: 700, easing: 'cubic-bezier(.4, 0, .2, 1)', fill: 'both' }
      const frames = (shown, hidden) => entering ? [ hidden, shown ] : [ shown, hidden ]
      el.style.overflow = 'hidden'

      const collapse = el.animate(frames({ height: `${el.offsetHeight}px` }, { height: '0px' }), timing)
      el.querySelector('.highlights')?.animate(frames({ transform: 'none', opacity: 1 }, { transform: 'translateY(-40px)', opacity: 0 }), timing)
      el.querySelector('.scores-session')?.animate(frames({ transform: 'none' }, { transform: 'translateX(-100%)' }), timing)
      el.querySelector('.scores-lan')?.animate(frames({ transform: 'none' }, { transform: 'translateX(100%)' }), timing)

      collapse.onfinish = () => {
        if (el.lanStatsAnimation !== token)
          return
        // Let the block size itself again after entering
        el.getAnimations({ subtree: true }).forEach((a) => a.cancel())
        el.style.overflow = ''
        done()
      }
    },

    playerName: function (id) {
      return this.scores.find((p) => p.id == id)?.name ?? '???'
    },

    // Adds a teamkill/suicide to the summary and shows it. Returns true if it
    // continues a summary that is already on screen.
    addToShame: function (data) {
      const [ first, second ] = data.args ?? []
      const now = Date.now()
      // Without a pause (pausing off, or an older plugin) only group events close together
      if (!this.paused && now - this.shameAt > SHAME_WINDOW)
        this.shame = []

      const continuing = this.shame.length > 0
      this.shame.push(data.cmd === 'tk'
        ? { type: 'tk', killer: first, victim: second, total: data.teamkillTotal }
        : { type: 'suicide', player: first })
      this.shameAt = now

      this.overlay.lines = this.shameLines()
      this.overlay.summary = this.shame.length > 1
      this.overlay.show = true
      return continuing
    },

    // One event: "ALSTRUP / teamkilled / CARO". Several: a header and a line per killer,
    // "3 teamkills + 1 suicide / ALSTRUP teamkilled CARO, emiL & Bob / Bob committed suicide".
    // Returns lines of { text, team } parts, so names can be colored.
    shameLines: function () {
      const player = (id) => {
        const p = this.scores.find((p) => p.id == id)
        return { text: p?.name ?? '???', team: p?.team }
      }
      const text = (text) => ({ text })
      const small = (text) => ({ text, small: true })
      // The killer's latest all-time teamkill count: "231st teamkill"
      const total = (killer) => this.shame.findLast((e) => e.type === 'tk' && e.killer === killer)?.total
      const ordinal = (n) => {
        const suffix = n % 100 >= 11 && n % 100 <= 13 ? 'th' : { 1: 'st', 2: 'nd', 3: 'rd' }[n % 10] ?? 'th'
        return `${n}${suffix}`
      }

      if (this.shame.length === 1) {
        const e = this.shame[0]
        return e.type === 'tk'
          ? [ [ player(e.killer) ], [ text('teamkilled') ], [ player(e.victim) ],
            ...(e.total ? [ [ small(`${player(e.killer).text}'s ${ordinal(e.total)} teamkill`) ] ] : []) ]
          : [ [ player(e.player), text(' committed suicide!') ] ]
      }

      const victims = new Map() // killer => victim ids, in order of first teamkill
      const order = []
      for (const e of this.shame) {
        if (e.type === 'suicide')
          order.push({ suicide: e.player })
        else if (victims.has(e.killer))
          victims.get(e.killer).push(e.victim)
        else {
          victims.set(e.killer, [ e.victim ])
          order.push({ killer: e.killer })
        }
      }

      // "A, B & C" with every name colored
      const list = (ids) => ids.flatMap((id, i) => [
        ...(i === 0 ? [] : [ text(i === ids.length - 1 ? ' & ' : ', ') ]),
        player(id),
      ])
      const plural = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`
      const teamkills = this.shame.filter((e) => e.type === 'tk').length
      const suicides = this.shame.length - teamkills
      const header = [ teamkills && plural(teamkills, 'teamkill'), suicides && plural(suicides, 'suicide') ].filter(Boolean).join(' + ')

      return [
        [ text(header) ],
        ...order.map((line) => line.suicide
          ? [ player(line.suicide), text(' committed suicide') ]
          : [ player(line.killer), text(' teamkilled '), ...list(victims.get(line.killer)),
            ...(total(line.killer) ? [ small(` · ${ordinal(total(line.killer))} teamkill`) ] : []) ]),
      ]
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
        this.$refs.overlay.playVideo(file).catch(this.onPlayError)
      else
        console.log(`Could not determine if "${ext}" is sound or video.`)
    },

    playSound: function (path) {
      let audio = new Audio(path)
      audio.volume = this.volume / 100
      audio.addEventListener('ended', () => {
        this.audioElements = this.audioElements.filter((a) => a !== audio)
      })
      audio.play().catch((e) => {
        this.onPlayError(e)
        console.log(`Could not play "${path}": ${e}`)
      })
      this.audioElements.push(audio)
    },

    // The browser refuses to play sound until the user has interacted with the page
    onPlayError: function (e) {
      if (e?.name === 'NotAllowedError')
        this.soundBlocked = true
    },

    // Whether the browser lets the page play sound yet. Firefox can tell directly;
    // elsewhere, try a short silent sound at normal volume (muted or zero-volume media
    // counts as inaudible and is allowed even when sound isn't)
    checkSound: function () {
      if (navigator.getAutoplayPolicy) {
        this.soundBlocked = navigator.getAutoplayPolicy('mediaelement') !== 'allowed'
        return
      }

      const audio = new Audio(silentWav())
      audio.play()
        .then(() => { this.soundBlocked = false; audio.pause() })
        .catch(this.onPlayError)
    },

    stopSound: function () {
      this.$refs.overlay.stopVideo()
      this.audioElements.forEach((audio) => audio.pause())
      this.audioElements = []
    },

    volumeChange: function () {
      this.$refs.overlay.setVolume(this.volume / 100)
      this.audioElements.forEach((audio) => {
        audio.volume = this.volume / 100
      })
    }
  }
}
</script>


<template>
  <div class="container-fluid" data-bs-theme="dark">
    <div class="row">
      <div class="col-12 pt-4">
        <div class="container-fluid">
          <!-- Status and volume left, LAN dropdown centered, buttons on the right -->
          <nav class="modes" aria-label="Stats">
            <!-- Status and volume on three compact lines -->
            <!-- Labels and values in two columns, so the values line up -->
            <div class="status">
              <span>Connection:</span><span class="value" :class="{ good: status === 'connected', bad: status === 'disconnected' }">{{ status }}</span>
              <span>State:</span><span class="value" :class="{ good: state === 'live' }">{{ state }}</span>
              <label for="volume">Volume:</label>
              <span v-if="soundBlocked" class="value sound-blocked" role="alert">Interact with page to enable sounds</span>
              <input v-else id="volume" class="slider" type="range" ref="volume" step="1" min="0" max="100" v-model="volume" v-on:change="volumeChange" />
            </div>
            <!-- Only shown on All stats -->
            <select id="lan-select" class="form-select" :class="{ concealed: mode !== 'all' }" aria-label="Show stats for" :value="selectedLan" :disabled="loadingAll" @change="selectLan">
              <option value="">All time</option>
              <option v-for="lan in lans" :key="lan.id" :value="lan.id">{{ lanLabel(lan) }}</option>
            </select>
            <div class="mode-buttons">
              <button type="button" :class="{ active: mode === 'lan' }" :aria-pressed="mode === 'lan'" :disabled="!lanActive" :title="lanActive ? '' : 'No LAN right now'" @click="showLan">Active LAN</button>
              <button type="button" :class="{ active: mode === 'all' }" :aria-pressed="mode === 'all'" :aria-busy="loadingAll" @click="showAll">
                All stats<span v-if="loadingAll" class="loading" aria-hidden="true"></span>
              </button>
            </div>
          </nav>

          <!-- Both pages sit side by side; the track slides to show one of them -->
          <div class="pages">
            <div class="track" :class="{ 'show-all': mode === 'all', animate }">
              <section class="page" :inert="mode !== 'lan'">
                <Transition :css="false" @enter="(el, done) => animateLanStats(el, done, true)" @leave="(el, done) => animateLanStats(el, done, false)">
                  <!-- Waits while the end-of-map awards are shown with the final scoreboard -->
                  <div v-if="state === 'ended' && !awards" class="lan-stats">
                    <Highlights :highlights="stats.lanHighlights" />
                    <div class="row w-100">
                      <div v-if="sessionScores.show" class="scores-session pb-5 col-6">
                        <Scoreboard :scoreboard="sessionScores.scores" :title="sessionScores.title" :headers="sessionScores.headers" />
                      </div>
                      <div v-if="lanScores.show" class="scores-lan pb-5 col-6">
                        <Scoreboard :scoreboard="lanScores.scores" :title="lanScores.title" :headers="lanScores.headers" />
                      </div>
                    </div>
                  </div>
                </Transition>

                <div v-if="activeScores.show" class="scores-active pb-5">
                  <Scoreboard :scoreboard="activeScores.scores" :title="activeScores.title" :headers="activeScores.headers" />
                </div>
              </section>

              <section class="page" :inert="mode !== 'all'">
                <Highlights :highlights="allHighlights" />
                <div v-if="allScores.show" class="scores-total pb-5">
                  <Scoreboard :scoreboard="allScores.scores" :headers="allScores.headers" />
                </div>
              </section>
            </div>
          </div>

          <audio ref="audio" id="audio">Audio not available</audio>
        </div>
      </div>
    </div>
  </div>
  <Overlay ref="overlay" :overlay="overlay" />
  <KillFeed ref="killfeed" :paused="paused" />
  <LiveBanner v-if="liveBanner" :key="liveBanner" @done="liveBanner = 0" />
  <Transition name="awards-fade">
    <AwardsBar v-if="awards?.length" :awards="awards" />
  </Transition>
</template>

<style>
@font-face {
  font-family: 'Trebuchet';
  src: url('fonts/trebuc.ttf');
}

.status {
  display: grid;
  grid-template-columns: max-content max-content;
  column-gap: .6rem;
  align-items: center;
  font-family: monospace;
  font-size: .8rem;
  line-height: 1.5;
  color: rgb(255 255 255 / 40%);
}

.status label {
  margin: 0;
}

/* Shown instead of the volume slider until the browser lets the page play sound */
.sound-blocked {
  color: rgb(255 200 0) !important;
  font-weight: 700;
  cursor: pointer;
  animation: blink 1s ease-in-out infinite alternate;
}

@keyframes blink {
  from { opacity: 1; }
  to { opacity: .25; }
}

@media (prefers-reduced-motion: reduce) {
  .sound-blocked {
    animation: none;
  }
}

.status .value {
  color: rgb(255 255 255 / 70%);
}

.status .value.good {
  color: #04aa6d;
}

.status .value.bad {
  color: #ea403e;
}

.modes {
  display: grid;
  /* Equal outer columns keep the dropdown centered */
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
}

.mode-buttons {
  display: flex;
  justify-content: flex-end;
  gap: .5rem;
}

.modes button {
  display: inline-flex;
  align-items: center;
  gap: .5rem;
  padding: .4rem 1.2rem;
  font-size: 1.1rem;
  color: rgb(255 255 255 / 60%);
  background: transparent;
  border: 1px solid rgb(255 255 255 / 18%);
  border-radius: 999px;
  cursor: pointer;
  transition: color .15s, background-color .15s, border-color .15s;
}

.modes button:hover:not(:disabled):not(.active) {
  color: white;
  border-color: rgb(255 255 255 / 40%);
}

.modes button.active {
  color: white;
  background: rgb(255 255 255 / 10%);
  border-color: rgb(255 255 255 / 45%);
}

.modes button:disabled {
  opacity: .35;
  cursor: default;
}

.modes button:focus-visible {
  outline: 2px solid #00abff;
  outline-offset: 2px;
}

.modes .loading {
  width: .8em;
  height: .8em;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: spin .7s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.modes select {
  width: auto;
  min-width: 22rem;
  font-size: 1.1rem;
  border-radius: 999px;
  transition: opacity .3s, visibility .3s;
}

.modes select.concealed {
  opacity: 0;
  visibility: hidden;
}

/* End-of-map awards fade out when their time is up */
.awards-fade-leave-active {
  transition: opacity 1s;
}

.awards-fade-leave-to {
  opacity: 0;
}

/* Two pages side by side in a track twice the page width */
.pages {
  overflow: hidden;
}

.track {
  display: flex;
  align-items: flex-start;
  width: 200%;
}

.track.animate {
  transition: transform .5s cubic-bezier(.4, 0, .2, 1);
}

.track.show-all {
  transform: translateX(-50%);
}

.page {
  width: 50%;
  min-width: 0;
  padding: 0 .75rem;
}

@media (prefers-reduced-motion: reduce) {
  .track.animate,
  .modes .loading {
    transition: none;
    animation-duration: 2s;
  }
}

.table td, .table th {
  font-size: 1.5rem;
  padding: .25rem;
  border-color: #ffffff17;
  text-shadow: 0 0 1px rgb(255 255 255 / 50%);
  /*font-family: 'Trebuchet';*/
  background-color: rgb(0 0 0 / 0%);
}

.scores-session .table td, .scores-session .table th, .scores-lan .table td, .scores-lan .table th {
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
  background-color: #131313;

  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  -webkit-text-size-adjust: 100%;
}



/* Slim slider that fits on a line of status text */
.slider {
  appearance: none;
  width: 110px;
  height: 3px;
  border-radius: 2px;
  background: rgb(255 255 255 / 30%);
  outline: none;
  cursor: pointer;
}

.slider::-webkit-slider-thumb {
  appearance: none;
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: #04AA6D;
}

.slider::-moz-range-thumb {
  width: 11px;
  height: 11px;
  border: none;
  border-radius: 50%;
  background: #04AA6D;
}

.slider:focus-visible {
  outline: 2px solid #00abff;
  outline-offset: 4px;
}
</style>
