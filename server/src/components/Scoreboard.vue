<script setup>
defineProps([ 'scoreboard', 'title', 'headers' ])
</script>

<template>
	<h1 class="text-center">{{ title }}</h1>
	<table class="table table-fluid">
		<thead>
			<tr>
				<th>{{ headers[0] }}</th>
				<th>{{ headers[1] }}</th>
				<th>{{ headers[2] }}</th>
				<th>{{ headers[3] }}</th>
				<th>{{ headers[4] }}</th>
				<th>{{ headers[5] }}</th>
			</tr>
		</thead>
		<tbody>
			<ScoreboardRow v-for="player in scoreboard" :player="player" :key="player.id" />
		</tbody>
	</table>
</template>
