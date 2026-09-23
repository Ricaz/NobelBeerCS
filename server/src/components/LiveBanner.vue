<script setup>
// "LIVE LIVE LIVE" scrolling across the screen when a game starts
import { onMounted, onUnmounted } from 'vue'

const emit = defineEmits([ 'done' ])

const DURATION = 4500 // ms, matches the scroll animation below
const WORDS = [ 'LIVE', 'LIVE', 'LIVE' ]
// The amx_csay colors: blue, red, cyan, green
const COLORS = [ 'rgb(0 0 255)', 'rgb(255 0 0)', 'rgb(0 255 255)', 'rgb(0 255 0)' ]

let timer
onMounted(() => { timer = setTimeout(() => emit('done'), DURATION) })
onUnmounted(() => clearTimeout(timer))
</script>

<template>
  <div class="live-banner" role="status" aria-label="The game is live">
    <div class="track">
      <span v-for="(word, w) in WORDS" :key="w" class="word">
        <span v-for="(letter, i) in word" :key="i" class="letter" :style="{ color: COLORS[(w * 4 + i) % COLORS.length] }">{{ letter }}</span>
      </span>
    </div>
  </div>
</template>

<style scoped>
.live-banner {
  position: fixed;
  inset: 0;
  z-index: 10001;
  display: flex;
  align-items: center;
  overflow: hidden;
  pointer-events: none;
}

.track {
  display: flex;
  gap: 8vh;
  white-space: nowrap;
  animation: scroll 4.5s linear forwards;
  will-change: transform;
}

.word {
  display: flex;
}

.letter {
  display: inline-block;
  font-size: 34vh;
  font-weight: 900;
  line-height: 1;
  -webkit-text-stroke: .04em #000;
  paint-order: stroke fill;
  /* A sharp shadow: a blurred glow on letters this big is slow to redraw */
  text-shadow: 0 .06em 0 rgb(0 0 0 / 60%);
}

@keyframes scroll {
  from { transform: translateX(100vw); }
  to { transform: translateX(-100%); }
}

@media (prefers-reduced-motion: reduce) {
  .live-banner {
    justify-content: center;
  }

  .track {
    animation: none;
    gap: 4vh;
  }

  .letter {
    font-size: 18vh;
  }
}
</style>
