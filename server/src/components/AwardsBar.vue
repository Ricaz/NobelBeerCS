<script setup>
// End-of-map awards, pinned to the bottom of the screen, sliding from award to award
import { ref, computed, onMounted, onUnmounted } from 'vue'

const props = defineProps({ awards: Array })

const SLIDE_EVERY = 6000

const index = ref(0)
const current = computed(() => props.awards[index.value % props.awards.length])
let timer

onMounted(() => {
  timer = setInterval(() => { index.value = (index.value + 1) % props.awards.length }, SLIDE_EVERY)
})
onUnmounted(() => clearInterval(timer))

const names = (list) => list.length > 1 ? `${list.slice(0, -1).join(', ')} & ${list.at(-1)}` : list[0]
</script>

<template>
  <aside class="awards" aria-label="End-of-map awards">
    <div class="heading">Map awards</div>
    <div class="stage">
      <Transition name="award" mode="out-in">
        <div class="award" :key="index">
          <div class="title">{{ current.title }}</div>
          <div class="winner">{{ names(current.names) }}</div>
          <div class="detail">{{ current.description }}: <b>{{ current.value }}</b></div>
        </div>
      </Transition>
    </div>
    <div class="dots" aria-hidden="true">
      <span v-for="(award, i) in awards" :key="award.title" :class="{ active: i === index % awards.length }"></span>
    </div>
  </aside>
</template>

<style scoped>
.awards {
  position: fixed;
  left: 1.5rem;
  right: 1.5rem;
  bottom: 1.5rem;
  z-index: 9000;
  max-height: 50vh;
  overflow: hidden;
  padding: 1.2rem 2rem 1rem;
  text-align: center;
  background: rgb(19 19 19 / 92%);
  border: 1px solid rgb(255 160 0 / 45%);
  border-radius: .75rem;
  box-shadow: 0 -8px 40px rgb(0 0 0 / 60%);
}

.heading {
  font-size: .95rem;
  letter-spacing: .2em;
  text-transform: uppercase;
  color: rgb(255 160 0);
}

.stage {
  overflow: hidden;
}

.title {
  font-size: 3rem;
  font-weight: 700;
  line-height: 1.15;
}

.winner {
  font-size: 2.2rem;
  color: #f2f2f2;
}

.detail {
  font-size: 1.2rem;
  color: rgb(255 255 255 / 65%);
}

.detail b {
  color: rgb(255 160 0);
}

.dots {
  display: flex;
  justify-content: center;
  gap: .5rem;
  margin-top: .8rem;
}

.dots span {
  width: .55rem;
  height: .55rem;
  border-radius: 50%;
  background: rgb(255 255 255 / 20%);
  transition: background-color .3s;
}

.dots span.active {
  background: rgb(255 160 0);
}

.award-enter-active,
.award-leave-active {
  transition: transform .45s cubic-bezier(.4, 0, .2, 1), opacity .45s;
}

.award-enter-from {
  transform: translateX(60%);
  opacity: 0;
}

.award-leave-to {
  transform: translateX(-60%);
  opacity: 0;
}

@media (prefers-reduced-motion: reduce) {
  .award-enter-active,
  .award-leave-active {
    transition: opacity .2s;
  }

  .award-enter-from,
  .award-leave-to {
    transform: none;
  }
}
</style>
