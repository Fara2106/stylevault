#!/bin/zsh
# Lancia un comando pesante senza bloccare il Mac: priorità bassa, tempo massimo,
# e stop se lo swap supera il limite o la memoria libera scende troppo.
# Uso: guard.sh <minuti> <comando...>
# Il 4/11 una generazione senza limiti è durata ore e il Mac si è dovuto riavviare.
MAX_MIN=$1; shift
MAX_SWAP_MB=${MAX_SWAP_MB:-3000}
MIN_FREE_PCT=${MIN_FREE_PCT:-12}

swap_mb() { sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9]+)\..*/\1/' }

# Conta solo lo swap che si aggiunge dopo l'avvio: quello di partenza non è nostro
BASE_SWAP=$(swap_mb)
nice -n 10 "$@" &
PID=$!
START=$SECONDS
PEAK_SWAP=0

stop() {
  echo "GUARD: $1, fermo il comando"
  kill -TERM -- $PID 2>/dev/null
  sleep 5
  kill -KILL -- $PID 2>/dev/null
  exit 124
}

while kill -0 $PID 2>/dev/null; do
  sleep 5
  SWAP=$(( $(swap_mb) - BASE_SWAP ))
  FREE=$(memory_pressure | awk -F': ' '/free percentage/ {gsub("%","",$2); print $2}')
  (( SWAP > PEAK_SWAP )) && PEAK_SWAP=$SWAP
  (( SECONDS - START > MAX_MIN * 60 )) && stop "tempo massimo di $MAX_MIN minuti"
  (( SWAP > MAX_SWAP_MB )) && stop "swap salito di $SWAP MB"
  [[ -n $FREE ]] && (( FREE < MIN_FREE_PCT )) && stop "memoria libera al $FREE%"
done
wait $PID
CODE=$?
echo "GUARD: finito in $((SECONDS - START)) s, codice $CODE, swap massimo $PEAK_SWAP MB"
exit $CODE
