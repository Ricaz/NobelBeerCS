<script setup>
// One glass per finished beer, and a partly filled one for the current beer
import { computed } from 'vue'
import { SIPS_PER_BEER } from './playerStats.js'

const props = defineProps({ sips: Number })

// More full glasses than this are shown as "+N"
const MAX_GLASSES = 6

const full = computed(() => Math.floor(props.sips / SIPS_PER_BEER))
const current = computed(() => (props.sips % SIPS_PER_BEER) / SIPS_PER_BEER)
</script>

<template>
  <span class="beer-bar" aria-hidden="true">
    <span v-for="i in Math.min(full, MAX_GLASSES)" :key="i" class="glass" style="--fill: 100%"></span>
    <span v-if="full > MAX_GLASSES" class="more">+{{ full - MAX_GLASSES }}</span>
    <span v-if="current > 0" class="glass" :style="{ '--fill': `${current * 100}%` }"></span>
  </span>
</template>

<style scoped>
.beer-bar {
  display: inline-flex;
  align-items: flex-end;
  gap: .15em;
}

.glass {
  width: .45em;
  height: .8em;
  border: .08em solid rgb(255 180 0 / 80%);
  border-top-color: rgb(255 255 255 / 60%);
  border-radius: 0 0 .12em .12em;
  background: linear-gradient(to top, rgb(255 180 0) var(--fill), transparent var(--fill));
}

.more {
  font-size: .7em;
  color: rgb(255 180 0);
}
</style>
