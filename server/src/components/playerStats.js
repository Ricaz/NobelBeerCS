// Shared by the live scoreboard and the stats tables

export const SIPS_PER_BEER = 20

// K/D ratio; stats from several games already carry an averaged 'kd'
export function kdRatio(player) {
  if (player.kd !== undefined)
    return Number(player.kd)
  return player.deaths ? player.kills / player.deaths : player.kills
}

export function beers(sips) {
  return (sips / SIPS_PER_BEER).toFixed(1)
}
