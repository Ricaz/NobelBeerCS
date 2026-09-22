<script setup>
import { ref } from 'vue'

defineProps([ 'overlay' ])

const video = ref(null)

const playVideo = function(path) {
  video.value.classList.remove('hidden')
  video.value.src = path
  video.value.play()
  console.log(`Overlay video: "${path}"`)
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
    <span class="overlay-text">{{ overlay.text }}</span>
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
.overlay {
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
