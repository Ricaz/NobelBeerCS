<script setup>
defineProps([ 'overlay' ])

const playVideo = function(path) {
  this.$refs.video.classList.remove('hidden')
  this.$refs.video.src = path
  this.$refs.video.play()
  console.log(`Overlay video: "${path}"`)
}

const stopVideo = function() {
  this.$refs.video.classList.add('hidden')
  this.$refs.video.src = ''
  this.$refs.video.load()
  console.log(`Stopped video.`)
}

defineExpose({ playVideo, stopVideo })

</script>

<template>
<div class="container-fluid overlay" v-show="overlay.show">
  <div class="overlay-body">
    <h2>TEST</h2>
    <video ref="video" class="hidden" id="video">Video not available</video>
  </div>
</div>
</template>

<style scoped>
.overlay {
  position: fixed;
  top: 10%;
  background-color: yellow;
  color: black;
  width: 100%;
  height: 100%;
  z-index: 9999;
}

video {
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}
</style>