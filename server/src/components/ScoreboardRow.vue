<script setup>
defineProps([ 'player' ])
</script>

<template>
	<tr :class="player.team">
		<td>{{ player.name }}</td>
		<td><b>{{ player.kills }}</b> / {{ player.deaths }}</td>
		<td><b>{{ player.knifekills }}</b> / {{ player.knifed }}</td>
		<td>{{ player.teamkills }}</td>
		<td>{{ player.suicides }}</td>
		<td>{{ (player.sips / 20).toFixed(1) }}</td>
		<td>{{ player.games }}</td>
	</tr>
</template>
