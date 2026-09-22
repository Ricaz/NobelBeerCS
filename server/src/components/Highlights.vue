<script setup>
defineProps([ 'highlights' ])

const ITEMS = [
  [ 'beers', 'Most øls' ],
  [ 'teamkills', 'Most TKs' ],
  [ 'knifekills', 'Most knife kills' ],
  [ 'suicides', 'Most suicides' ],
]
</script>

<template>
  <div v-if="highlights" class="highlights">
    <div v-for="[ key, label ] in ITEMS" :key="key" class="highlight">
      <div class="label">{{ label }}</div>
      <template v-if="highlights[key]">
        <div class="value">{{ highlights[key].value }}</div>
        <div class="names" :title="highlights[key].names.join(' & ')">{{ highlights[key].names.join(' & ') }}</div>
      </template>
      <div v-else class="value none">–</div>
    </div>
  </div>
</template>

<style scoped>
.highlights {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.highlight {
  padding: .9rem 1.2rem;
  border: 1px solid rgb(255 255 255 / 12%);
  border-radius: .5rem;
  background: rgb(255 255 255 / 3%);
  text-align: center;
}

.label {
  font-size: 1rem;
  color: rgb(255 255 255 / 60%);
}

.value {
  font-size: 2.2rem;
  font-weight: 700;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
}

.value.none {
  color: rgb(255 255 255 / 30%);
}

.names {
  font-size: 1.2rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
