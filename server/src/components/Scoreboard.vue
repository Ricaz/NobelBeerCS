<script setup>
defineProps([ 'scoreboard' ])
</script>

<template>
	<h1 class="text-center">{{ scoreboard.title }}</h1>
	<table class="table table-fluid">
		<thead>
			<tr>
				<th>Name</th>
				<th>K/D</th>
				<th>Knife K/D</th>
				<th>TKs</th>
				<th>Suicides</th>
				<th>Sips</th>
				<th>Rounds</th>
			</tr>
		</thead>
		<tbody>
			<ScoreboardRow v-for="player in scoreboard" :player="player" :key="player.id" />
		</tbody>
	</table>
</template>
