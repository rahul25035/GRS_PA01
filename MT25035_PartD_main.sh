#MT25035_PartD_main.sh
#!/bin/bash
# set -e

rm -f a.out b.out try_thread.txt try_proc.txt results.csv
sleep 1

echo "Compiling programs..."
gcc MT25035_PartD_A.c -o a.out
gcc MT25035_PartD_B.c -o b.out -pthread
echo "Compilation done"
echo "=================================="

# Require GNU time
if ! command -v /usr/bin/time >/dev/null 2>&1; then
    echo "Error: /usr/bin/time (GNU time) not found."
    exit 1
fi

# Create CSV and header
CSV_FILE="MT25035_PartD_results.csv"
echo "components,program,function,cpu_percent,mem_mb,io_kbps,time_sec" > "$CSV_FILE"

measure() {
    TYPE=$1
    MODE=$2
    NOP=$3

    if [ "$TYPE" = "process" ]; then
        EXE="./a.out"
        prog="A"
    else
        EXE="./b.out"
        prog="B"
    fi

    exe_name=$(basename "$EXE")

    time_file=$(mktemp)

    taskset -c 0,1 /usr/bin/time -f "%e" "$EXE" "$MODE" "$NOP" 2> "$time_file" &
    PID=$!

    sum_cpu=0
    sum_mem=0
    sum_io=0
    count=0

    while kill -0 "$PID" 2>/dev/null; do
        cpu=$(top -b -H -n 1 | awk -v exe="$exe_name" '$0 ~ exe {c+=$9} END {print c}')
        cpu=${cpu:-0}

        mem=$(top -b -n 1 | awk -v exe="$exe_name" '$0 ~ exe {m+=$6} END {print m}')
        mem=${mem:-0}

        io=$(iostat -dx 1 1 | awk '$1=="sda" {print $9}')
        io=${io:-0}

        sum_cpu=$(awk -v s="$sum_cpu" -v c="$cpu" 'BEGIN{print s + c}')
        sum_mem=$(awk -v s="$sum_mem" -v m="$mem" 'BEGIN{print s + m}')
        sum_io=$(awk -v s="$sum_io" -v i="$io"  'BEGIN{print s + i}')

        count=$((count + 1))
        sleep 1
    done

    wait "$PID"

    elapsed_raw=$(cat "$time_file")
    rm -f "$time_file"

    avg_cpu=$(awk -v s="$sum_cpu" -v n="$count" 'BEGIN{if(n>0) printf "%.2f", s/n; else print 0}')
    avg_mem_kb=$(awk -v s="$sum_mem" -v n="$count" 'BEGIN{if(n>0) print s/n; else print 0}')
    avg_mem_mb=$(awk -v m="$avg_mem_kb" 'BEGIN{printf "%.2f", m/1024}')
    avg_io=$(awk -v s="$sum_io" -v n="$count" 'BEGIN{if(n>0) printf "%.2f", s/n; else print 0}')
    elapsed=$(awk -v e="$elapsed_raw" 'BEGIN{printf "%.3f", e}')

    # Terminal output
    printf "%-6s %-8s %-9s %-10s %-8s\n" \
    "$prog+$MODE" \
    "$avg_cpu" \
    "${avg_mem_mb}MB" \
    "$avg_io" \
    "$elapsed"

    # CSV output (no units)
    echo "$NOP,$prog,$MODE,$avg_cpu,$avg_mem_mb,$avg_io,$elapsed" >> "$CSV_FILE"
}

# ================= MAIN LOOP =================

for c in 2 3 4 5 6
do
    echo
    echo "components=$c"
    printf "%-6s %-8s %-9s %-10s %-8s\n" "Prog" "CPU%" "Mem" "IO" "Time(s)"
    echo "------------------------------------------------------"

    for m in cpu mem io
    do
        measure process $m $c
        measure thread  $m $c
    done
done

echo
echo "Results saved to $CSV_FILE"
echo "Making Plots..."
bash ./MT25035_PartD_plots.sh
rm -f a.out b.out try_thread.txt try_proc.txt *.dat
