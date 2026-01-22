#!/bin/bash
# MT25035_PartC_main.sh

rm -f a.out b.out try_thread.txt try_proc.txt MT25035_PartC_results.csv

echo "Compiling programs..."
gcc MT25035_Part_C_Program_A.c -o a.out
gcc MT25035_Part_C_Program_B.c -o b.out -pthread
echo "Compilation done"
echo "=================================="

if ! command -v /usr/bin/time >/dev/null 2>&1; then
  echo "/usr/bin/time not found"; exit 1
fi

CSV="MT25035_Part_C_results.csv"
echo "components,program,function,cpu_percent,mem_mb,io_kbps,time_sec" > "$CSV"

measure() {
  TYPE=$1
  MODE=$2
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
  sleep 0.5

  sum_cpu=0; sum_mem=0; sum_io=0; cnt=0

  while kill -0 "$PID" 2>/dev/null; do
    #CPU:Sum %CPU for all threads/processes matching the name
    cpu=$(top -b -n 1 -H | grep "$exe_name" | awk '{s+=$9} END {print s+0}')
    
    # Memory:Sum RES column and handle 'm' or 'g' suffixes
    mem_kb=$(top -b -n 1 | grep "$exe_name" | awk '
    {
      val=$6
      if(val ~ /m$/) val *= 1024
      else if(val ~ /g$/) val *= 1048576
      s += val
    } END {print s+0}')
    
    # IO: Sum of read and write kB/s for devices starting with 'sd'
    io=$(iostat -d -k 1 2 | awk '
      /^Device/ { report++ }
      report==2 && $1 ~ /^sd/ { total += $3 + $4 }
      END { print total+0 }
    ')

    sum_cpu=$(awk -v a="$sum_cpu" -v b="$cpu" 'BEGIN{print a+b}')
    sum_mem=$(awk -v a="$sum_mem" -v b="$mem_kb" 'BEGIN{print a+b}')
    sum_io=$(awk -v s="$sum_io" -v b="$io" 'BEGIN{print s+b}')
    
    cnt=$((cnt+1))
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

  printf "%-10s %-8s %-10s %-8s %-8s\n" "${PROG}+${MODE}" "${avg_cpu}" "${avg_mem_mb}MB" "${avg_io}" "${elapsed}"
  echo "${NCOMP},${PROG},${MODE},${avg_cpu},${avg_mem_mb},${avg_io},${elapsed}" >> "$CSV"
}

printf "\ncomponents=%s\n" "2"
printf "%-10s %-8s %-10s %-8s %-8s\n" "Prog" "CPU%" "Mem" "IO" "Time(s)"
echo "------------------------------------------------------------"
for m in cpu mem io; do
  measure process $m 2
  measure thread  $m 2
done

echo ""
echo "Results saved to $CSV"