<script setup>
defineProps([ 'highlights' ])

const ITEMS = [
  [ 'beers', 'Most øls' ],
  [ 'teamkills', 'Most TKs' ],
  [ 'knifekills', 'Most knife kills' ],
  [ 'knifed', 'Most knifed' ],
  [ 'suicides', 'Most suicides' ],
]
</script>

<template>
  <div v-if="highlights" class="highlights">
    <!-- Only stats someone actually has -->
    <template v-for="[ key, label ] in ITEMS" :key="key">
      <div v-if="highlights[key]" class="highlight">
        <div class="label">{{ label }}</div>
        <div class="value">{{ highlights[key].value }}</div>
        <div class="names" :title="highlights[key].names.join(' & ')">{{ highlights[key].names.join(' & ') }}</div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.highlights {
  display: flex;
  gap: 1rem;
  margin-bottom: 2rem;
}

.highlight {
  flex: 1 1 0;
  min-width: 0;
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

.names {
  font-size: 1.2rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
