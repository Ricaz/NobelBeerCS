<script setup>
// One scoreboard for everything: the live (or final) game and the stats tables
// (last session, this LAN, all time). Players are listed in the given order.
import { computed } from 'vue'
import BeerBar from './BeerBar.vue'
import { kdRatio, beers } from './playerStats.js'

const props = defineProps({
  players: Array,
  title: String,
  nameLabel: { type: String, default: 'Name' },
  // Optional last column, e.g. { label: 'Maps', field: 'games' }
  extra: Object,
  // The live game: glasses per beer, round number, row flashes, and a font that
  // scales with the number of players
  live: Boolean,
  // Live: player id => changes on each kill, to flash their row
  flashes: Object,
  // Live: ids of players dead this round, struck through and greyed out
  dead: Array,
})

// [ header, player field ]; no field is the K/D ratio
const COLUMNS = [
  [ 'K', 'kills' ], [ 'D', 'deaths' ], [ 'K/D', null ],
  [ 'Knife', 'knifekills' ], [ 'Knifed', 'knifed' ], [ 'TK', 'teamkills' ], [ 'Suicide', 'suicides' ],
]

const round = computed(() => props.live ? Math.max(0, ...props.players.map((p) => p.rounds || 0)) : 0)
// Beers over many games run into the thousands: a bar relative to the leader
const maxSips = computed(() => Math.max(1, ...props.players.map((p) => p.sips)))
const kd = (p) => kdRatio(p).toFixed(props.live ? 1 : 2)
</script>

<template>
  <section class="scoreboard" :class="{ live, 'with-extra': extra }" :style="{ '--rows': players.length }">
    <h1 v-if="title">{{ title }}<span v-if="round" class="round">Round {{ round }}</span></h1>

    <div class="row head">
      <span class="rank">#</span>
      <span>{{ nameLabel }}</span>
      <span v-for="[ label ] in COLUMNS" :key="label" class="num">{{ label }}</span>
      <span class="num">{{ live ? 'ØLs' : 'Øl' }}</span>
      <span v-if="extra" class="num">{{ extra.label }}</span>
    </div>

    <div v-for="(p, i) in players" :key="p.id" class="row" :class="[ p.team, { dead: live && dead?.includes(p.id) } ]">
      <span v-if="live && flashes?.[p.id]" :key="flashes[p.id]" class="flash"></span>
      <span class="rank">{{ i + 1 }}</span>
      <span class="name" :title="p.name"><span class="text">{{ p.name }}</span></span>
      <span v-for="[ label, field ] in COLUMNS" :key="label" class="num" :class="field ? { zero: !p[field] } : 'kd'">
        {{ field ? p[field] : kd(p) }}
      </span>
      <span class="beers">
        <BeerBar v-if="live" :sips="p.sips" />
        <span v-else class="meter"><span :style="{ width: `${p.sips / maxSips * 100}%` }"></span></span>
        <b>{{ beers(p.sips) }}</b>
      </span>
      <span v-if="extra" class="num extra">{{ p[extra.field] }}</span>
    </div>
  </section>
</template>

<style scoped>
.scoreboard {
  container-type: inline-size;
  font-size: 1.2rem;
}

/* The live board fills the screen (20 players fit at 1080p): the font grows with
   fewer players (a row is about 1.6em high), but stays small enough to fit a long
   name (a row is about 57em wide) */
.scoreboard.live {
  font-size: clamp(1rem, min(calc((100vh - 16.5rem) / (var(--rows) + 1) / 1.6), calc((100vw - 4rem) / 57)), 2rem);
}

h1 {
  text-align: center;
  font-size: 2.2rem;
  margin-bottom: .5em;
}

.round {
  margin-left: .8em;
  font-size: .55em;
  font-weight: 400;
  color: rgb(255 255 255 / 55%);
}

.row {
  position: relative;
  display: grid;
  /* # name K D K/D knife knifed TK suicide øl */
  grid-template-columns: 1.8em minmax(0, 1fr) 3.4em 3.4em 3em 3.2em 3.6em 2.8em 3.8em var(--beer-column, 9em);
  align-items: center;
  column-gap: .5em;
  padding: .12em .5em;
  line-height: 1.3;
  border-bottom: 1px solid rgb(255 255 255 / 7%);
  /* Team color as a thin line on the left */
  border-left: .2em solid var(--team, transparent);
}

.with-extra .row {
  grid-template-columns: 1.8em minmax(0, 1fr) 3.4em 3.4em 3em 3.2em 3.6em 2.8em 3.8em var(--beer-column, 9em) 3.2em;
}

/* Narrow boards (the two stats tables side by side): no beer meter and a smaller
   font, to leave room for the names */
@container (width < 70rem) {
  .row {
    font-size: .85em;
    --beer-column: 3.4em;
  }

  .meter {
    display: none;
  }
}

/* Room for 10 glasses of beer */
.live .row {
  --beer-column: 11.5em;
}

.live .row:not(.head) {
  /* With few players the font can't grow without cutting names; taller rows fill
     the screen instead */
  min-height: min(calc((100vh - 16.5rem) / (var(--rows) + 1)), 2.2em);
}

.CT { --team: #00abff; }
.TERRORIST { --team: #ea403e; }

/* Only the header text is smaller: the row keeps the font size of the rows below,
   so its columns (sized in em) line up with theirs */
.row.head > * {
  font-size: .8em;
  white-space: nowrap;
  color: rgb(255 255 255 / 60%);
}

.rank {
  color: rgb(255 255 255 / 40%);
  font-variant-numeric: tabular-nums;
}

.name {
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  color: var(--team, white);
}

.num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

/* Zeros fade into the background, so the numbers that matter stand out */
.num.zero {
  color: rgb(255 255 255 / 25%);
}

.kd,
.extra {
  color: rgb(255 255 255 / 60%);
}

.beers {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: .4em;
  min-width: 0;
}

.beers b {
  min-width: 2.4em;
  text-align: right;
  font-size: 1.1em;
  font-variant-numeric: tabular-nums;
  color: rgb(255 180 0);
}

.meter {
  flex: 1;
  height: .35em;
  border-radius: .2em;
  background: rgb(255 255 255 / 8%);
}

.meter span {
  display: block;
  height: 100%;
  border-radius: .2em;
  background: rgb(255 180 0 / 85%);
}

/* Dead this round: a line is drawn through the name, then the row turns grey.
   Only dying is animated; everyone comes back at once on a new round. */
.name .text {
  position: relative;
}

.name .text::after {
  content: '';
  position: absolute;
  left: -.1em;
  right: -.1em;
  top: 55%;
  height: .1em;
  border-radius: .05em;
  background: rgb(255 255 255 / 85%);
  transform: scaleX(0);
  transform-origin: left;
}

.dead .name .text::after {
  transform: scaleX(1);
  transition: transform .35s cubic-bezier(.6, 0, .4, 1);
}

.dead > :not(.flash) {
  opacity: .4;
  filter: grayscale(1);
  transition: opacity .6s ease .3s, filter .6s ease .3s;
}

/* A row lights up when that player gets a kill */
.flash {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--team, white);
  opacity: 0;
  animation: flash 3s ease-out;
}

@keyframes flash {
  0% { opacity: .35; }
  100% { opacity: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .flash {
    animation-duration: .01s;
  }

  .dead .name .text::after,
  .dead > :not(.flash) {
    transition: none;
  }
}
</style>
