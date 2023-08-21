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
		<td>{{ player.sips }}</td>
		<td>{{ player.rounds }}</td>
	</tr>
</template>
