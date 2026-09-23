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
  // Kills/deaths and knife kills/knifed in one column each, for narrow boards
  combined: Boolean,
  // A K/D ratio column
  ratio: Boolean,
  // The live game: glasses per beer, row flashes, and a font that scales with
  // the number of players
  live: Boolean,
  // Live: player id => changes on each kill, to flash their row
  flashes: Object,
  // Live: ids of players dead this round, struck through and greyed out
  dead: Array,
})

// Number columns: header, width (em), text (or a pair of numbers, the first in
// bold), and whether it fades as a zero
const count = (label, field, width) => ({ label, width, text: (p) => p[field], zero: (p) => !p[field] })
const pair = (label, a, b, width) => ({ label, width, pair: (p) => [ p[a], p[b] ], zero: (p) => !p[a] && !p[b] })
const RATIO = { label: 'K/D', width: 3, text: (p) => kdRatio(p).toFixed(2), zero: () => false, class: 'kd' }
const TK_SUICIDE = [ count('TK', 'teamkills', 2.8), count('Suicide', 'suicides', 3.8) ]

const columns = computed(() => props.combined
  ? [ pair('K/D', 'kills', 'deaths', 4.6), pair('Knife K/D', 'knifekills', 'knifed', 4.4), ...TK_SUICIDE ]
  : [ count('K', 'kills', 3.4), count('D', 'deaths', 3.4), ...(props.ratio ? [ RATIO ] : []),
      count('Knife', 'knifekills', 3.2), count('Knifed', 'knifed', 3.6), ...TK_SUICIDE ])
const columnWidths = computed(() => columns.value.map((c) => `${c.width}em`).join(' '))

// Beers over many games run into the thousands: a bar relative to the leader
const maxSips = computed(() => Math.max(1, ...props.players.map((p) => p.sips)))
</script>

<template>
  <section class="scoreboard" :class="{ live, 'with-extra': extra }" :style="{ '--rows': players.length, '--columns': columnWidths }">
    <h1 v-if="title">{{ title }}</h1>

    <div class="row head">
      <span class="rank">#</span>
      <span>{{ nameLabel }}</span>
      <span v-for="c in columns" :key="c.label" class="num">{{ c.label }}</span>
      <span class="num">{{ live ? 'ØLs' : 'Øl' }}</span>
      <span v-if="extra" class="num">{{ extra.label }}</span>
    </div>

    <div v-for="(p, i) in players" :key="p.id" class="row" :class="[ p.team, { dead: live && dead?.includes(p.id) } ]">
      <span v-if="live && flashes?.[p.id]" :key="flashes[p.id]" class="flash"></span>
      <span class="rank">{{ i + 1 }}</span>
      <span class="name" :title="p.name"><span class="text">{{ p.name }}</span></span>
      <span v-for="c in columns" :key="c.label" class="num" :class="[ c.class, { zero: c.zero(p) } ]">
        <template v-if="c.pair"><b>{{ c.pair(p)[0] }}</b>-{{ c.pair(p)[1] }}</template>
        <template v-else>{{ c.text(p) }}</template>
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
   name (a row is about 53em wide). --chrome is the rest of the page's height. */
.scoreboard.live {
  --chrome: 12.8rem;
  font-size: clamp(1rem, min(calc((100vh - var(--chrome)) / (var(--rows) + 1) / 1.6), calc((100vw - 4rem) / 53)), 2rem);
}

/* The final scoreboard has a title */
.scoreboard.live:has(> h1) {
  --chrome: 16.5rem;
}

h1 {
  text-align: center;
  font-size: 2.2rem;
  margin-bottom: .5em;
}

.row {
  position: relative;
  display: grid;
  /* # name (number columns) øl; the ems in --columns are this row's */
  grid-template-columns: 1.8em minmax(0, 1fr) var(--columns) var(--beer-column, 9em);
  align-items: center;
  column-gap: .5em;
  padding: .25em .5em;
  border-bottom: 1px solid rgb(255 255 255 / 7%);
  /* Team color as a thin line on the left */
  border-left: .2em solid var(--team, transparent);
}

.with-extra .row {
  grid-template-columns: 1.8em minmax(0, 1fr) var(--columns) var(--beer-column, 9em) 3.2em;
}

/* Narrow boards (the two stats tables side by side): no beer meter, to leave
   room for the names */
@container (width < 70rem) {
  .row {
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

.live .row {
  /* Tighter rows, so 20 players fit at 1080p */
  padding-block: .12em;
  line-height: 1.3;
}

.live .row:not(.head) {
  /* With few players the font can't grow without cutting names; taller rows fill
     the screen instead */
  min-height: min(calc((100vh - var(--chrome)) / (var(--rows) + 1)), 2.2em);
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
