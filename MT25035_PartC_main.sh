#!/bin/bash
# MT25035_PartC_main.sh

rm -f a.out b.out try_thread.txt try_proc.txt MT25035_PartC_results.csv
gcc MT25035_PartB_A.c -o a.out
gcc MT25035_PartB_B.c -o b.out -pthread

if ! command -v /usr/bin/time >/dev/null 2>&1; then
  echo "/usr/bin/time not found"; exit 1
fi

CSV="MT25035_PartC_results.csv"
echo "components,program,function,cpu_percent,mem_mb,io_kbps,time_sec" > "$CSV"

measure() {
  TYPE=$1    # process or thread
  MODE=$2    # cpu mem io
  NCOMP=$3

  if [ "$TYPE" = "process" ]; then
    EXE="./a.out"; PROG="A"
  else
    EXE="./b.out"; PROG="B"
  fi

  exe_name=$(basename "$EXE")
  tf=$(mktemp)

  taskset -c 0,1 /usr/bin/time -f "%e" "$EXE" "$MODE" "$NCOMP" 2> "$tf" &
  PID=$!

  sum_cpu=0; sum_mem=0; sum_io=0; cnt=0

  while kill -0 "$PID" 2>/dev/null; do
    cpu=$(top -b -n1 | awk -v exe="$exe_name" '$0 ~ exe {c+=$9} END {print c+0}')
    mem=$(top -b -n1 | awk -v exe="$exe_name" '$0 ~ exe {m+=$6} END {print m+0}')
    io=$(iostat -dx 1 1 2>/dev/null | awk '$1=="sda" {print $9+0}')
    sum_cpu=$(awk -v a="$sum_cpu" -v b="$cpu" 'BEGIN{printf "%.6f", a+b}')
    sum_mem=$(awk -v a="$sum_mem" -v b="$mem" 'BEGIN{printf "%.0f", a+b}')
    sum_io=$(awk -v a="$sum_io" -v b="$io" 'BEGIN{printf "%.6f", a+b}')
    cnt=$((cnt+1))
    sleep 1
  done

  wait "$PID" 2>/dev/null
  elapsed=$(cat "$tf" 2>/dev/null || echo 0)
  rm -f "$tf"

  if [ "$cnt" -gt 0 ]; then
    avg_cpu=$(awk -v s="$sum_cpu" -v n="$cnt" 'BEGIN{printf "%.2f", s/n}')
    avg_mem_kb=$(awk -v s="$sum_mem" -v n="$cnt" 'BEGIN{printf "%.2f", s/n}')
    avg_mem_mb=$(awk -v k="$avg_mem_kb" 'BEGIN{printf "%.2f", k/1024}')
    avg_io=$(awk -v s="$sum_io" -v n="$cnt" 'BEGIN{printf "%.2f", s/n}')
  else
    avg_cpu="0.00"; avg_mem_mb="0.00"; avg_io="0.00"
  fi

  printf "%-6s %-8s %-8s %-8s %-8s\n" "${PROG}+${MODE}" "${avg_cpu}" "${avg_mem_mb}MB" "${avg_io}" "${elapsed}"
  echo "${NCOMP},${PROG},${MODE},${avg_cpu},${avg_mem_mb},${avg_io},${elapsed}" >> "$CSV"
}


printf "\ncomponents=%s\n" "2"
printf "%-6s %-8s %-8s %-8s %-8s\n" "Prog" "CPU%" "Mem" "IO" "Time(s)"
echo "----------------------------------------------"
for m in cpu mem io; do
measure process $m 2
measure thread  $m 2
done

echo "Results saved to $CSV"
