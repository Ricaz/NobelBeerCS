<script setup>
// Stats tables (last session, this LAN, all time): the same compact style as the
// live scoreboard, one list sorted by beers
import { computed } from 'vue'
import { kdRatio, beers, badges, crowns } from './playerStats.js'

const props = defineProps({
  scoreboard: Array,
  title: String,
  // [ name column, ..., last column ] e.g. 'Name (last seen)', 'Maps'
  headers: Array,
})

const best = computed(() => crowns(props.scoreboard))
// Beers over many games run into the thousands: a bar relative to the leader
const maxSips = computed(() => Math.max(1, ...props.scoreboard.map((p) => p.sips)))
</script>

<template>
  <section class="stats-board">
    <h1 v-if="title">{{ title }}</h1>
    <div class="row head">
      <span class="rank">#</span><span>{{ headers[0] }}</span><span class="num">K</span><span class="num">D</span><span class="num">K/D</span><span class="beers">Øl</span><span class="num">{{ headers.at(-1) }}</span>
    </div>
    <div v-for="(p, i) in scoreboard" :key="p.id" class="row">
      <span class="rank">{{ i + 1 }}</span>
      <span class="name">
        <span class="text" :title="p.name">{{ p.name }}</span>
        <span v-if="best.beers.has(p.id)" class="crown" title="Most øls">👑</span>
        <span v-if="best.kd.has(p.id)" class="crown" title="Best K/D">🎯</span>
        <span v-for="b in badges(p)" :key="b.label" class="badge" :class="b.label" :title="b.title">{{ b.label }} {{ b.count }}</span>
      </span>
      <span class="num">{{ p.kills }}</span>
      <span class="num">{{ p.deaths }}</span>
      <span class="num kd">{{ kdRatio(p).toFixed(2) }}</span>
      <span class="beers"><span class="meter"><span :style="{ width: `${p.sips / maxSips * 100}%` }"></span></span><b>{{ beers(p.sips) }}</b></span>
      <span class="num games">{{ p.games || p.rounds }}</span>
    </div>
  </section>
</template>

<style scoped>
.stats-board {
  font-size: 1.25rem;
}

h1 {
  text-align: center;
  font-size: 2.2rem;
  margin-bottom: .5em;
}

.row {
  display: grid;
  grid-template-columns: 1.8em minmax(0, 1fr) 3em 3em 3.2em 8.5em 3.4em;
  align-items: center;
  column-gap: .5em;
  padding: .25em .4em;
  border-bottom: 1px solid rgb(255 255 255 / 7%);
}

.row.head {
  font-size: .65em;
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
}

.crown {
  flex: none;
  font-size: .8em;
}

.badge {
  flex: none;
  padding: .05em .4em;
  border-radius: .3em;
  font-size: .6em;
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

.kd,
.games {
  color: rgb(255 255 255 / 60%);
}

.beers {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: .4em;
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

.beers b {
  min-width: 2.6em;
  text-align: right;
  font-size: 1.1em;
  font-variant-numeric: tabular-nums;
  color: rgb(255 180 0);
}
</style>
