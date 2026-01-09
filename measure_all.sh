#!/usr/bin/env bash
set -euo pipefail

# CONFIG
CPU_CORE=0
SAMPLE_INTERVAL=0.2   # seconds between samples (smaller so short runs are caught)
SAMPLE_TIMEOUT=300    # safety timeout in seconds for each run

# Per-worker counts (tweak these for your roll number as required)
CPU_COUNT=2000000
MEM_COUNT=20000
IO_COUNT=20000

PROGA=./c1.out
PROGB=./c2.out

if [[ ! -x "$PROGA" || ! -x "$PROGB" ]]; then
  echo "Please compile c1.out and c2.out first"
  echo "gcc -O2 C1.c -o c1.out"
  echo "gcc -O2 C2.c -o c2.out -pthread"
  exit 1
fi

# Recursively collect pid + all descendants (children, grandchildren, ...)
get_all_pids() {
  local root=$1
  local pid
  echo "$root"
  # pgrep -P lists direct children; recurse
  for pid in $(pgrep -P "$root" 2>/dev/null || true); do
    get_all_pids "$pid"
  done
}

printf "Program+Function\tAvgCPU(%%)\tPeakMem(KB)\tAvg_rKB/s\tAvg_wKB/s\tElapsed(s)\n"

variants=(
  "$PROGA cpu"
  "$PROGA mem"
  "$PROGA io"
  "$PROGB cpu"
  "$PROGB mem"
  "$PROGB io"
)

for v in "${variants[@]}"; do
  prog=$(echo "$v" | awk '{print $1}')
  worker=$(echo "$v" | awk '{print $2}')
  base=$(basename "$prog")
  tag="${base}+${worker}"
  outdir="logs_${tag}"
  mkdir -p "$outdir"

  prog_stdout="$outdir/prog.out"
  prog_stderr="$outdir/prog.err"

  case "$worker" in
    cpu) COUNT_ARG=$CPU_COUNT ;;
    mem) COUNT_ARG=$MEM_COUNT ;;
    io)  COUNT_ARG=$IO_COUNT ;;
    *)   COUNT_ARG=10000 ;;
  esac

  # start program
  start_time=$(date +%s.%N)
  taskset -c $CPU_CORE "$prog" "$worker" "$COUNT_ARG" > "$prog_stdout" 2> "$prog_stderr" &
  prog_pid=$!

  # wait shortly for /proc to appear
  attempts=0
  while [[ ! -d "/proc/$prog_pid" && $attempts -lt 50 ]]; do
    sleep 0.02
    attempts=$((attempts + 1))
  done

  # initialize IO counters (sum over all pids)
  start_read=0
  start_write=0

  # sampling accumulators
  cpu_sum=0.0
  samples=0
  peak_rss=0

  # we keep last seen total IO (sum across all pids) while process runs
  last_read=0
  last_write=0

  t0=$(date +%s)
  start_time=$(date +%s.%N)

  # immediate first sample (to capture very short runs)
  pids=( $(get_all_pids "$prog_pid") )
  if [[ ${#pids[@]} -gt 0 ]]; then
    # build CSV for ps
    pids_csv=$(IFS=,; echo "${pids[*]}")
    # sum CPU and RSS across PIDs
    # ps returns one line per pid
    ps_output=$(ps -p "$pids_csv" -o %cpu=,rss= 2>/dev/null || echo "")
    if [[ -n "$ps_output" ]]; then
      # sum CPU and take max RSS
      cpu_now=$(awk '{cpu+=$1} END{printf "%f", cpu+0}' <<<"$ps_output")
      rss_now=$(awk 'BEGIN{m=0} { if ($2+0 > m) m=$2+0 } END{print m+0}' <<<"$ps_output")
      cpu_sum=$(awk -v s="$cpu_sum" -v c="$cpu_now" 'BEGIN{printf "%.6f", s + c}')
      if (( rss_now > peak_rss )); then peak_rss=$rss_now; fi
      samples=$((samples + 1))
    fi

    # sum IO across pids
    sum_read=0; sum_write=0
    for pid in "${pids[@]}"; do
      if [[ -r "/proc/$pid/io" ]]; then
        r=$(awk '/read_bytes/{print $2; exit}' /proc/$pid/io 2>/dev/null || echo 0)
        w=$(awk '/write_bytes/{print $2; exit}' /proc/$pid/io 2>/dev/null || echo 0)
        r=${r:-0}; w=${w:-0}
        sum_read=$((sum_read + r))
        sum_write=$((sum_write + w))
      fi
    done
    last_read=$sum_read
    last_write=$sum_write
    start_read=$sum_read
    start_write=$sum_write
  fi

  # sampling loop
  while kill -0 "$prog_pid" 2>/dev/null; do
    # collect current PIDs (parent + descendants)
    pids=( $(get_all_pids "$prog_pid") )

    if [[ ${#pids[@]} -gt 0 ]]; then
      pids_csv=$(IFS=,; echo "${pids[*]}")
      ps_output=$(ps -p "$pids_csv" -o %cpu=,rss= 2>/dev/null || echo "")
      if [[ -n "$ps_output" ]]; then
        cpu_now=$(awk '{cpu+=$1} END{printf "%f", cpu+0}' <<<"$ps_output")
        rss_now=$(awk 'BEGIN{m=0} { if ($2+0 > m) m=$2+0 } END{print m+0}' <<<"$ps_output")
        cpu_sum=$(awk -v s="$cpu_sum" -v c="$cpu_now" 'BEGIN{printf "%.6f", s + c}')
        if (( rss_now > peak_rss )); then peak_rss=$rss_now; fi
        samples=$((samples + 1))
      fi

      # sample IO across current pids (keep last seen total)
      sum_read=0; sum_write=0
      for pid in "${pids[@]}"; do
        if [[ -r "/proc/$pid/io" ]]; then
          r=$(awk '/read_bytes/{print $2; exit}' /proc/$pid/io 2>/dev/null || echo 0)
          w=$(awk '/write_bytes/{print $2; exit}' /proc/$pid/io 2>/dev/null || echo 0)
          r=${r:-0}; w=${w:-0}
          sum_read=$((sum_read + r))
          sum_write=$((sum_write + w))
        fi
      done
      # update last seen (only increase if larger; protects against transient read issues)
      if (( sum_read > last_read )); then last_read=$sum_read; fi
      if (( sum_write > last_write )); then last_write=$sum_write; fi
    fi

    # timeout guard (integer seconds)
    now=$(date +%s)
    if (( now - t0 >= SAMPLE_TIMEOUT )); then
      echo "Run $tag exceeded timeout ${SAMPLE_TIMEOUT}s, killing." >> "$prog_stderr"
      kill -9 "$prog_pid" 2>/dev/null || true
      break
    fi

    sleep "$SAMPLE_INTERVAL"
  done

  end_time=$(date +%s.%N)
  wait "$prog_pid" 2>/dev/null || true

  # final attempt to read remaining /proc io if still present
  if [[ -r "/proc/$prog_pid/io" ]]; then
    # re-sum current descendants too
    pids=( $(get_all_pids "$prog_pid") )
    sum_read=0; sum_write=0
    for pid in "${pids[@]}"; do
      if [[ -r "/proc/$pid/io" ]]; then
        r=$(awk '/read_bytes/{print $2; exit}' /proc/$pid/io 2>/dev/null || echo 0)
        w=$(awk '/write_bytes/{print $2; exit}' /proc/$pid/io 2>/dev/null || echo 0)
        r=${r:-0}; w=${w:-0}
        sum_read=$((sum_read + r))
        sum_write=$((sum_write + w))
      fi
    done
    # take max of last seen and this final read
    if (( sum_read > last_read )); then last_read=$sum_read; fi
    if (( sum_write > last_write )); then last_write=$sum_write; fi
  fi

  # compute elapsed (float)
  elapsed=$(awk -v a="$start_time" -v b="$end_time" 'BEGIN{printf "%.3f", b - a}')

  # average CPU
  avg_cpu="0.00"
  if (( samples > 0 )); then
    avg_cpu=$(awk -v s="$cpu_sum" -v n="$samples" 'BEGIN{printf "%.2f", s/n}')
  fi

  # IO delta and rates
  delta_read=$(( last_read - start_read ))
  delta_write=$(( last_write - start_write ))
  if (( delta_read < 0 )); then delta_read=0; fi
  if (( delta_write < 0 )); then delta_write=0; fi

  avg_r_kbs="0.00"
  avg_w_kbs="0.00"
  if awk "BEGIN {exit !($elapsed > 0)}"; then
    avg_r_kbs=$(awk -v r="$delta_read" -v e="$elapsed" 'BEGIN{printf "%.2f", (r/1024.0)/e}')
    avg_w_kbs=$(awk -v w="$delta_write" -v e="$elapsed" 'BEGIN{printf "%.2F", (w/1024.0)/e}')
  fi

  printf "%s\t%s\t%d\t%s\t%s\t%s\n" "$tag" "$avg_cpu" "$peak_rss" "$avg_r_kbs" "$avg_w_kbs" "$elapsed"
done

echo ""
echo "Results saved in logs_* directories"
