#!/bin/bash
# MT25035_PartD_main.sh

rm -f a.out b.out try_thread.txt try_proc.txt results.csv

echo "Compiling programs..."
gcc MT25035_PartD_A.c -o a.out
gcc MT25035_PartD_B.c -o b.out -pthread
echo "Compilation done"
echo "=================================="

if ! command -v /usr/bin/time >/dev/null 2>&1; then
    echo "Error: /usr/bin/time (GNU time) not found."
    exit 1
fi

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

    # Start the program in the background
    # taskset -c 0,1 forces it to run on specific cores for consistent measurement
    taskset -c 0,1 /usr/bin/time -f "%e" "$EXE" "$MODE" "$NOP" 2> "$time_file" &
    PID=$!
    
    # Wait briefly for process to initialize
    sleep 0.5

    sum_cpu=0
    sum_mem=0
    sum_io=0
    count=0

    # Loop while the process is still running
    while kill -0 "$PID" 2>/dev/null; do
        
        # 1. CPU Measurement
        # Use top -H (threads). Sum %CPU (col 9) for all lines matching exe_name
        cpu=$(top -b -n 1 -H | grep "$exe_name" | awk '{s+=$9} END {print s+0}')
        
        # 2. Memory Measurement
        # Use top (process view). Sum RES (col 6) for all lines matching exe_name
        # Handles suffixes 'm' (MB) and 'g' (GB) just in case
        mem_kb=$(top -b -n 1 | grep "$exe_name" | awk '
        {
            val=$6
            if(val ~ /m$/) val *= 1024
            else if(val ~ /g$/) val *= 1048576
            s += val
        } END {print s+0}')
        
        # 3. IO Measurement (FIXED for your screenshot)
        # We run "iostat -d -k 1 2". This takes 2 samples.
        # Sample 1: Average since boot (we ignore this).
        # Sample 2: Current speed over the last 1 second (we keep this).
        # We sum columns $3 (Read) and $4 (Write) for any device starting with "sd" (sda, sdb, sdc).
        io=$(iostat -d -k 1 2 | awk '
            /^Device/ { report++ }
            report==2 && $1 ~ /^sd/ { total += $3 + $4 }
            END { print total+0 }
        ')

        # Accumulate sums
        sum_cpu=$(awk -v s="$sum_cpu" -v c="$cpu" 'BEGIN{print s + c}')
        sum_mem=$(awk -v s="$sum_mem" -v m="$mem_kb" 'BEGIN{print s + m}')
        sum_io=$(awk -v s="$sum_io" -v i="$io" 'BEGIN{print s + i}')

        count=$((count + 1))
        
        # The "iostat 1 2" command takes 1 second to run, so we don't need "sleep 1"
    done

    wait "$PID"

    elapsed_raw=$(cat "$time_file")
    rm -f "$time_file"

    # Calculate Averages
    avg_cpu=$(awk -v s="$sum_cpu" -v n="$count" 'BEGIN{if(n>0) printf "%.2f", s/n; else print 0}')
    avg_mem_kb=$(awk -v s="$sum_mem" -v n="$count" 'BEGIN{if(n>0) print s/n; else print 0}')
    avg_mem_mb=$(awk -v m="$avg_mem_kb" 'BEGIN{printf "%.2f", m/1024}')
    avg_io=$(awk -v s="$sum_io" -v n="$count" 'BEGIN{if(n>0) printf "%.2f", s/n; else print 0}')
    elapsed=$(awk -v e="$elapsed_raw" 'BEGIN{printf "%.3f", e}')

    printf "%-6s %-8s %-9s %-10s %-8s\n" \
        "$prog+$MODE" \
        "$avg_cpu" \
        "${avg_mem_mb}MB" \
        "$avg_io" \
        "$elapsed"

    echo "$NOP,$prog,$MODE,$avg_cpu,$avg_mem_mb,$avg_io,$elapsed" >> "$CSV_FILE"
}

for c in 2 3 4 5 6 7 8
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
rm -f a.out b.out try_thread.txt try_proc.txt