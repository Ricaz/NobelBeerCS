<script setup>
// "LIVE LIVE LIVE" scrolling across the screen with bouncing letters when a game starts
import { onMounted, onUnmounted } from 'vue'

const emit = defineEmits([ 'done' ])

const DURATION = 4500 // ms, matches the scroll animation below
const WORDS = [ 'LIVE', 'LIVE', 'LIVE' ]

let timer
onMounted(() => { timer = setTimeout(() => emit('done'), DURATION) })
onUnmounted(() => clearTimeout(timer))
</script>

<template>
  <div class="live-banner" role="status" aria-label="The game is live">
    <div class="track">
      <span v-for="(word, w) in WORDS" :key="w" class="word">
        <span v-for="(letter, i) in word" :key="i" class="letter" :style="{ animationDelay: `${-(w * 4 + i) * 0.09}s` }">{{ letter }}</span>
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
  text-shadow: 0 .06em 0 rgb(0 0 0 / 60%), 0 0 .3em rgb(255 160 0 / 60%);
  animation: bounce .45s ease-in-out infinite alternate, colors .6s steps(1) infinite;
}

@keyframes scroll {
  from { transform: translateX(100vw); }
  to { transform: translateX(-100%); }
}

@keyframes bounce {
  from { transform: translateY(12%) rotate(-7deg) scale(.95); }
  to { transform: translateY(-12%) rotate(7deg) scale(1.08); }
}

@keyframes colors {
  0% { color: #00abff; }
  33% { color: #ea403e; }
  66% { color: rgb(255 200 0); }
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
    animation: none;
    color: rgb(255 200 0);
  }
}
</style>
