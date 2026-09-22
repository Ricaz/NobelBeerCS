<script setup>
// In-game style killfeed: "killer [weapon] [headshot] victim". Entries disappear
// after a while, and their timers stop while the game is paused.
import { ref, onMounted, onUnmounted } from 'vue'

const props = defineProps({ paused: Boolean })

const LIFETIME = 6000 // like hud_deathnotice_time in CS
const MAX_ENTRIES = 5
const TICK = 100

const entries = ref([])
let nextId = 0
let timer

// entry: { killer: { name, team }, victim: { name, team }, weapon, headshot, teamkill, suicide }
function add(entry) {
  entries.value.push({ ...entry, id: nextId++, remaining: LIFETIME })
  if (entries.value.length > MAX_ENTRIES)
    entries.value.shift()
}

function clear() {
  entries.value = []
}

onMounted(() => {
  timer = setInterval(() => {
    if (props.paused || !entries.value.length)
      return
    entries.value.forEach((e) => { e.remaining -= TICK })
    entries.value = entries.value.filter((e) => e.remaining > 0)
  }, TICK)
})
onUnmounted(() => clearInterval(timer))

defineExpose({ add, clear })

// CS 1.6 weapon names (from DeathMsg) grouped into icon silhouettes
const WEAPON_CLASS = {
  glock18: 'pistol', usp: 'pistol', p228: 'pistol', deagle: 'pistol', elite: 'pistol', fiveseven: 'pistol',
  mp5navy: 'smg', tmp: 'smg', p90: 'smg', mac10: 'smg', ump45: 'smg',
  m3: 'shotgun', xm1014: 'shotgun',
  ak47: 'rifle', m4a1: 'rifle', galil: 'rifle', famas: 'rifle', sg552: 'rifle', aug: 'rifle',
  awp: 'sniper', scout: 'sniper', g3sg1: 'sniper', sg550: 'sniper',
  m249: 'mg',
  knife: 'knife',
  grenade: 'grenade', hegrenade: 'grenade',
}

// Side-view silhouettes drawn on a 64x20 grid, facing right
const ICONS = {
  pistol: 'M16 5h28v2h2v4H31l-1 2h-3l1 5h-7l-2-7h-3zM28 11h3l-1 2h-2z',
  smg: 'M6 7l10-1V5h30v2h6v3H46v1H36l1 7h-4l-2-7h-6l-2 5h-5l1-5h-3L6 11z',
  shotgun: 'M2 8l12-2 2-1h30l16 1v2H48v1H36v2H27l-2 4h-5l1-4h-4L3 12z M36 9h11v2H36z',
  rifle: 'M2 7l12-2 2-1h32V3h4v2h10v2H50v1H40l-2 6h-4l1-6h-5l-2 5h-4l1-5h-9L3 12z',
  sniper: 'M2 7l12-2 2-1h34l12 1v2H48v1H38l1 4h-4l-1-4h-4l-2 5h-4l1-5h-9L3 12z M22 0h16v1h-2v2h-2V1h-8v2h-2V1h-2z',
  mg: 'M2 7l12-2 2-1h34V3h3v2h9v2H50v1h-6l-1 1h-9v6h-8V9h-2l-2 5h-4l1-5h-5L3 12z M52 8l2 6h-1l-2-6z',
  knife: 'M6 8h14v4H6z M20 8h26l14 2-14 2H20z M19 7h2v6h-2z',
  grenade: 'M32 4h5v2h-5z M38 3l6-2 1 1-6 3z M34 6a6 6 0 1 1-0.01 0z',
  headshot: 'M32 2a7 7 0 0 1 7 7v4l-2 1v3h-10v-3l-2-1V9a7 7 0 0 1 7-7z M29 9a1.5 1.5 0 1 0 0.01 0z M35 9a1.5 1.5 0 1 0 0.01 0z',
  suicide: 'M32 1a8 8 0 0 1 8 8v4l-2 1v4H26v-4l-2-1V9a8 8 0 0 1 8-8z M28 8a2 2 0 1 0 0.01 0z M36 8a2 2 0 1 0 0.01 0z M30 15h1v3h-1z M33 15h1v3h-1z',
}

// Horizontal extent of each icon on the grid, so small ones don't get wide margins
const BOUNDS = {
  pistol: [ 15, 32 ], smg: [ 5, 48 ], shotgun: [ 1, 62 ], rifle: [ 1, 62 ], sniper: [ 1, 62 ],
  mg: [ 1, 62 ], knife: [ 5, 56 ], grenade: [ 25, 21 ], headshot: [ 24, 16 ], suicide: [ 23, 18 ],
}

function icon(name) {
  if (!ICONS[name])
    return null
  const [ x, width ] = BOUNDS[name]
  return { d: ICONS[name], viewBox: `${x} 0 ${width} 20` }
}

function weaponIcon(weapon) {
  return icon(WEAPON_CLASS[weapon])
}
</script>

<template>
  <div class="killfeed" aria-live="polite">
    <TransitionGroup name="feed">
      <div v-for="e in entries" :key="e.id" class="entry" :class="{ teamkill: e.teamkill }">
        <span v-if="!e.suicide" class="name" :class="e.killer.team">{{ e.killer.name }}</span>
        <svg v-if="e.suicide" class="icon" :viewBox="icon('suicide').viewBox" role="img" aria-label="suicide"><path :d="icon('suicide').d" /></svg>
        <svg v-if="weaponIcon(e.weapon)" class="icon" :viewBox="weaponIcon(e.weapon).viewBox" role="img" :aria-label="e.weapon"><path :d="weaponIcon(e.weapon).d" /></svg>
        <span v-else-if="e.weapon && !e.suicide" class="weapon-name">{{ e.weapon }}</span>
        <svg v-if="e.headshot" class="icon" :viewBox="icon('headshot').viewBox" role="img" aria-label="headshot"><path :d="icon('headshot').d" /></svg>
        <span class="name" :class="e.victim.team">{{ e.victim.name }}</span>
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.killfeed {
  position: absolute;
  top: 0;
  right: 0;
  z-index: 10;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
  pointer-events: none;
}

.entry {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .25rem .7rem;
  font-size: 1.15rem;
  font-weight: 600;
  white-space: nowrap;
  background: rgb(0 0 0 / 65%);
  border: 1px solid transparent;
  border-radius: 3px;
}

.entry.teamkill {
  border-color: rgb(234 64 62 / 70%);
}

.name.TERRORIST { color: #ea403e; }
.name.CT { color: #00abff; }

.icon {
  height: 1.2rem;
  width: auto;
  fill: #f2f2f2;
  flex: none;
}

.weapon-name {
  font-size: .8rem;
  color: rgb(255 255 255 / 70%);
  text-transform: uppercase;
}

.feed-enter-active,
.feed-leave-active {
  transition: opacity .3s, transform .3s;
}

.feed-enter-from {
  opacity: 0;
  transform: translateX(30px);
}

.feed-leave-to {
  opacity: 0;
}

.feed-move {
  transition: transform .3s;
}

@media (prefers-reduced-motion: reduce) {
  .feed-enter-active,
  .feed-leave-active,
  .feed-move {
    transition: none;
  }
}
</style>
