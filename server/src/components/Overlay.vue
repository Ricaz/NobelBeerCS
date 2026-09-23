<script setup>
import { ref } from 'vue'

defineProps([ 'overlay' ])

const video = ref(null)

const playVideo = function(path) {
  video.value.classList.remove('hidden')
  video.value.src = path
  console.log(`Overlay video: "${path}"`)
  // Rejected when the next video interrupts this one, which is fine; blocked
  // playback (no user interaction yet) is passed on
  return video.value.play().catch((e) => {
    if (e.name === 'NotAllowedError')
      throw e
  })
}

const stopVideo = function() {
  video.value.classList.add('hidden')
  video.value.src = ''
  video.value.load()
  console.log(`Stopped video.`)
}

const setVolume = function(volume) {
  video.value.volume = volume
}

defineExpose({ playVideo, stopVideo, setVolume })

</script>

<template>
<div class="container-fluid overlay" v-show="overlay.show">
  <div class="overlay-body">
    <div class="overlay-text" :class="{ summary: overlay.summary }">
      <div v-for="(line, i) in overlay.lines" :key="i">
        <span v-for="(part, j) in line" :key="j" :class="[ part.team, { small: part.small } ]">{{ part.text }}</span>
      </div>
    </div>
    <video ref="video" class="hidden" id="video">Video not available</video>
  </div>
</div>
</template>

<style scoped>
.overlay-text {
  position: fixed;
  white-space: pre;
  color: white;
  width: 100%;
  top: 10%;
  text-align: center;
  font-size: 60pt;
  text-shadow: 3px -1px 7px rgba(0,0,0,0.5);
}

/* Player names in their team's color, like the scoreboard */
.overlay-text .CT {
  color: #00abff;
}

.overlay-text .TERRORIST {
  color: #ea403e;
}

.overlay-text .CT,
.overlay-text .TERRORIST {
  font-weight: 700;
  text-shadow: 0 0 12px rgb(0 0 0 / 80%), 3px -1px 7px rgb(0 0 0 / 50%);
}

/* The killer's all-time teamkill count */
.overlay-text .small {
  font-size: .5em;
  color: rgb(255 255 255 / 85%);
}

/* Several teamkills/suicides: header plus a line per killer */
.overlay-text.summary {
  font-size: 40pt;
  line-height: 1.3;
}

.overlay-text.summary > :first-child {
  font-size: 52pt;
}
.overlay {
  /* Only shows things: clicks go through to the page (e.g. the volume slider) */
  pointer-events: none;
  position: absolute;
  top: 0;
  color: black;
  width: 100%;
  height: 90%;
  z-index: 9999;
  opacity: 75%;
}

video {
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}
</style>
