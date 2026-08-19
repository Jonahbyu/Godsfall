#!/usr/bin/env bash
# Run one balance round: N games split across S shards in parallel.
#   tools/run_round.sh <round_name> [total_games] [shards]
set -u
GODOT="C:/Users/Jonah/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
ROUND="$1"; TOTAL="${2:-1000000}"; SHARDS="${3:-20}"
PER=$(( TOTAL / SHARDS ))
OUT="logs/sim/rounds/$ROUND"
rm -rf "$OUT"; mkdir -p "$OUT"
echo "== round $ROUND : $SHARDS shards x $PER games = $((PER*SHARDS)) =="
for i in $(seq 0 $((SHARDS-1))); do
  # Each shard gets its own seed AND its own pairing phase offset, so the
  # round-robin stays balanced across the union rather than 20 copies of the
  # same prefix.
  "$GODOT" --headless --path . --script res://scripts/core/BalanceSim.gd -- \
    games=$PER out=$OUT/s$i.csv seed=$(( 1000 + i )) > "$OUT/s$i.log" 2>&1 &
done
wait
echo "-- shards done --"
grep -h "BalanceSim:" "$OUT"/*.log | head -3
cat "$OUT"/s*.csv | grep -c . 
