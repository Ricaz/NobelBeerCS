<script setup>
// The live (or final) scoreboard: CT and T side by side like in the game, with team
// totals. The font scales with the number of players so it fills the screen.
import { computed } from 'vue'
import BeerBar from './BeerBar.vue'
import { kdRatio, beers, badges, crowns } from './playerStats.js'

const props = defineProps({
  title: String,
  players: Array,
  // player id => kill count, to flash the row of whoever just got a kill
  flashes: Object,
})

const TEAMS = [ [ 'CT', 'Counter-Terrorists' ], [ 'TERRORIST', 'Terrorists' ] ]

const teams = computed(() => TEAMS.map(([ key, name ]) => {
  const players = props.players.filter((p) => p.team === key)
    .sort((a, b) => b.sips - a.sips || b.kills - a.kills)
  return {
    key,
    name,
    players,
    kills: players.reduce((sum, p) => sum + p.kills, 0),
    sips: players.reduce((sum, p) => sum + p.sips, 0),
  }
}))
const others = computed(() => props.players.filter((p) => p.team !== 'CT' && p.team !== 'TERRORIST'))
const round = computed(() => Math.max(0, ...props.players.map((p) => p.rounds || 0)))
const best = computed(() => crowns(props.players))
const rows = computed(() => Math.max(1, ...teams.value.map((t) => t.players.length)))
</script>

<template>
  <section class="team-board" :style="{ '--rows': rows }">
    <h1>{{ title }}<span v-if="round" class="round">Round {{ round }}</span></h1>

    <div class="panels">
      <div v-for="team in teams" :key="team.key" class="panel" :class="team.key">
        <header>
          <span class="team-name">{{ team.name }}</span>
          <span class="totals">{{ team.kills }} kills · <b>{{ beers(team.sips) }}</b> øl</span>
        </header>

        <div class="row head">
          <span class="rank">#</span><span>Name</span><span class="num">K</span><span class="num">D</span><span class="num">K/D</span><span class="beers">Øl</span>
        </div>

        <div v-for="(p, i) in team.players" :key="p.id" class="row">
          <span v-if="flashes?.[p.id]" :key="flashes[p.id]" class="flash"></span>
          <span class="rank">{{ i + 1 }}</span>
          <span class="name">
            <span class="text" :title="p.name">{{ p.name }}</span>
            <span v-if="best.beers.has(p.id)" class="crown" title="Most øls">👑</span>
            <span v-if="best.kd.has(p.id)" class="crown" title="Best K/D">🎯</span>
            <span v-for="b in badges(p)" :key="b.label" class="badge" :class="b.label" :title="b.title">{{ b.label }} {{ b.count }}</span>
          </span>
          <span class="num">{{ p.kills }}</span>
          <span class="num">{{ p.deaths }}</span>
          <span class="num kd">{{ kdRatio(p).toFixed(1) }}</span>
          <span class="beers"><BeerBar :sips="p.sips" /><b>{{ beers(p.sips) }}</b></span>
        </div>
      </div>
    </div>

    <p v-if="others.length" class="others">Not playing: {{ others.map((p) => p.name).join(', ') }}</p>
  </section>
</template>

<style scoped>
.team-board {
  /* Rows get smaller the more players there are, so the board fills the screen, but
     never so big that a 26-character name no longer fits in half the screen width
     (a row is about 34em wide with such a name and a badge) */
  font-size: clamp(1rem, min(calc((100vh - 15rem) / (var(--rows) + 3) / 1.8), calc((50vw - 4rem) / 34)), 2rem);
}

h1 {
  text-align: center;
  font-size: 2.2rem;
  margin-bottom: .6em;
}

.round {
  margin-left: .8em;
  font-size: .55em;
  font-weight: 400;
  color: rgb(255 255 255 / 55%);
}

.panels {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
}

.panel header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  padding: .25em .5em;
  border-bottom: .12em solid var(--team);
  font-size: .85em;
}

.team-name {
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: var(--team);
}

.totals {
  color: rgb(255 255 255 / 70%);
}

.totals b {
  color: rgb(255 180 0);
}

.CT { --team: #00abff; }
.TERRORIST { --team: #ea403e; }

.row {
  position: relative;
  display: grid;
  grid-template-columns: 1.4em minmax(0, 1fr) 2em 2em 2.6em 6.3em;
  align-items: center;
  column-gap: .4em;
  padding: .3em .5em;
  border-bottom: 1px solid rgb(255 255 255 / 7%);
}

/* With few players the font can't grow without cutting names; taller rows fill the
   screen instead */
.row:not(.head) {
  min-height: min(calc((100vh - 16rem) / (var(--rows) + 2)), 3.2em);
}

.row.head {
  font-size: .6em;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: rgb(255 255 255 / 50%);
}

.rank {
  color: rgb(255 255 255 / 40%);
  font-variant-numeric: tabular-nums;
}

.name {
  display: flex;
  align-items: center;
  gap: .35em;
  min-width: 0;
}

.name .text {
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  color: var(--team);
}

.crown {
  flex: none;
  font-size: .8em;
}

.badge {
  flex: none;
  padding: .05em .4em;
  border-radius: .3em;
  font-size: .55em;
  white-space: nowrap;
  color: rgb(255 255 255 / 85%);
  background: rgb(255 255 255 / 10%);
}

.badge.TK,
.badge.suicide {
  background: rgb(234 64 62 / 30%);
}

.num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.kd {
  color: rgb(255 255 255 / 60%);
}

.beers {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: .4em;
}

.beers b {
  min-width: 2.2em;
  text-align: right;
  font-size: 1.15em;
  font-variant-numeric: tabular-nums;
  color: rgb(255 180 0);
}

.row.head .beers {
  justify-content: flex-end;
}

/* A row lights up when that player gets a kill */
.flash {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--team);
  opacity: 0;
  animation: flash 3s ease-out;
}

@keyframes flash {
  0% { opacity: .35; }
  100% { opacity: 0; }
}

.others {
  margin-top: 1em;
  font-size: .6em;
  color: rgb(255 255 255 / 45%);
}

@media (prefers-reduced-motion: reduce) {
  .flash {
    animation-duration: .01s;
  }
}
</style>
