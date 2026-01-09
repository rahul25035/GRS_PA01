#!/usr/bin/env bash
set -euo pipefail

# CONFIG
CPU_CORE=0
SAMPLE_INTERVAL=0.5
SAMPLE_COUNT=60

# Per-worker counts
CPU_COUNT=2000000
MEM_COUNT=20000
IO_COUNT=20000

iostat_cmd=$(command -v iostat || true)
top_cmd=$(command -v top)
date_cmd=$(command -v date)

PROGA=./c1.out
PROGB=./c2.out

if [[ ! -x "$PROGA" || ! -x "$PROGB" ]]; then
  echo "Please compile c1.out and c2.out first"
  echo "gcc -O2 C1.c -o c1.out"
  echo "gcc -O2 C2_fixed.c -o c2.out -pthread"
  exit 1
fi

if [[ -z "$iostat_cmd" ]]; then
  echo "Warning: iostat not found. IO metrics will be N/A."
fi

variants=(
  "$PROGA cpu"
  "$PROGA mem"
  "$PROGA io"
  "$PROGB cpu"
  "$PROGB mem"
  "$PROGB io"
)

printf "Program+Function\tAvgCPU(%%)\tPeakMem(KB)\tAvg_rKB/s\tAvg_wKB/s\tElapsed(s)\n"

for v in "${variants[@]}"; do
  prog=$(echo "$v" | awk '{print $1}')
  worker=$(echo "$v" | awk '{print $2}')
  tag=$(basename "$prog")"+"$worker
  outdir="logs_${tag}"
  mkdir -p "$outdir"

  top_log="$outdir/top.log"
  iostat_log="$outdir/iostat.log"
  prog_stdout="$outdir/prog.out"
  prog_stderr="$outdir/prog.err"

  # Start monitoring BEFORE program
  $top_cmd -b -d $SAMPLE_INTERVAL > "$top_log" 2>&1 &
  top_pid=$!

  if [[ -n "$iostat_cmd" ]]; then
    $iostat_cmd -dx $SAMPLE_INTERVAL > "$iostat_log" 2>&1 &
    iostat_pid=$!
  else
    iostat_pid=""
  fi

  sleep 0.3

  case "$worker" in
    cpu) COUNT_ARG=$CPU_COUNT ;;
    mem) COUNT_ARG=$MEM_COUNT ;;
    io)  COUNT_ARG=$IO_COUNT ;;
    *)   COUNT_ARG=10000 ;;
  esac

  start_time=$($date_cmd +%s.%N)
  taskset -c $CPU_CORE "$prog" "$worker" "$COUNT_ARG" > "$prog_stdout" 2> "$prog_stderr" &
  prog_pid=$!

  # Wait with timeout
  timeout=$SAMPLE_COUNT
  elapsed_loop=0
  while kill -0 "$prog_pid" 2>/dev/null; do
    sleep 1
    elapsed_loop=$((elapsed_loop+1))
    if (( elapsed_loop >= timeout )); then
      echo "Program $tag exceeded ${timeout}s, killing." >> "$outdir/prog.err"
      kill -9 "$prog_pid" 2>/dev/null || true
      break
    fi
  done
  wait "${prog_pid}" 2>/dev/null || true
  end_time=$($date_cmd +%s.%N)

  sleep 0.2
  kill "$top_pid" 2>/dev/null || true
  if [[ -n "$iostat_pid" ]]; then kill "$iostat_pid" 2>/dev/null || true; fi

  elapsed=$(awk -v a="$start_time" -v b="$end_time" 'BEGIN{printf "%.3f", b - a}')

  # Parse top for CPU and Memory (simple approach)
  cpu_avg="0.00"
  mem_peak_kb=0
  if [[ -s "$top_log" ]]; then
    read cpu_avg mem_peak_kb < <(awk 'NR>7 {cpu+=$9; mem=($10>mem)?$10:mem; cnt++} 
       END {if(cnt>0) printf "%.2f %d\n", cpu/cnt, int(mem*10.24); else print "0.00 0"}' "$top_log")
  fi

  # Parse iostat for I/O stats
  avg_r="N/A"
  avg_w="N/A"
  if [[ -s "$iostat_log" ]] && [[ -n "$iostat_cmd" ]]; then
    read avg_r avg_w < <(awk '
      NR>3 && NF>4 && $1 ~ /^[a-z]/ {r+=$4; w+=$5; cnt++}
      END {if(cnt>0) printf "%.2f %.2f\n", r/cnt, w/cnt; else print "0.00 0.00"}
    ' "$iostat_log" 2>/dev/null || echo "0.00 0.00")
  fi

  printf "%s\t%s\t%d\t%s\t%s\t%s\n" "$tag" "$cpu_avg" "$mem_peak_kb" "$avg_r" "$avg_w" "$elapsed"
done

echo ""
echo "Results saved in logs_* directories"
