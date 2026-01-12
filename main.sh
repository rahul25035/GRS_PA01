#!/bin/bash

echo "Compiling programs..."
gcc A.c -o a.out
gcc B.c -o b.out -pthread

echo -e "Program+Function\tAvgCPU(%)\tAvgMem(KB)\tIO_wkB/s\tTime(s)"
echo "----------------------------------------------------------------------"

measure() {
    NAME=$1
    CMD=$2
    
    rm -f try.txt try_thread.txt

    # Start the program in background
    $CMD &
    MAIN_PID=$!

    echo "Monitoring PID: $MAIN_PID" >&2

    START_TIME=$(date +%s)

    TMP_SAMPLES="/tmp/samples_$$"
    > "$TMP_SAMPLES"

    # Loop while the main process exists. Sample every 0.5s
    while kill -0 "$MAIN_PID" 2>/dev/null; do
        # Build list of parent + direct children
        CHILD_PIDS=$(ps --no-headers -o pid --ppid "$MAIN_PID" 2>/dev/null | awk '{printf ","$1}')
        PID_LIST=$(echo "$MAIN_PID$CHILD_PIDS" | sed 's/^,//')

        if [ -n "$PID_LIST" ]; then
            # ps: for these PIDs, sum %CPU and RSS (KB)
            read SAMPLE_CPU SAMPLE_MEM <<< $(ps -p "$PID_LIST" -o %cpu= -o rss= 2>/dev/null | \
                awk '{cpu+=$1; mem+=$2} END { if (cpu=="") cpu=0; if(mem=="") mem=0; printf "%.2f %.0f", cpu, mem }')
        else
            SAMPLE_CPU="0.00"
            SAMPLE_MEM="0"
        fi

        echo "$SAMPLE_CPU $SAMPLE_MEM" >> "$TMP_SAMPLES"
        sleep 0.5
    done

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    if [ $ELAPSED -eq 0 ]; then
        ELAPSED=1
    fi

    # Compute averages from samples
    if [ -s "$TMP_SAMPLES" ]; then
        read CPU_AVG MEM_AVG <<< $(awk '{cpu+=$1; mem+=$2; count++} END { if(count>0) printf "%.2f %.2f", cpu/count, mem/count; else printf "0.00 0.00"}' "$TMP_SAMPLES")
    else
        CPU_AVG="0.00"
        MEM_AVG="0.00"
    fi

    # Measure IO by file size (either try.txt or try_thread.txt)
    IO_BYTES=0
    if [ -f try.txt ]; then
        IO_BYTES=$(stat -c "%s" try.txt 2>/dev/null || stat -f "%z" try.txt 2>/dev/null || echo 0)
    elif [ -f try_thread.txt ]; then
        IO_BYTES=$(stat -c "%s" try_thread.txt 2>/dev/null || stat -f "%z" try_thread.txt 2>/dev/null || echo 0)
    fi

    IO_RATE=$((IO_BYTES / ELAPSED / 1024))

    # Cleanup
    rm -f "$TMP_SAMPLES"

    printf "%s\t%.2f\t\t%.2f\t\t%d\t\t%d\n" "$NAME" "$CPU_AVG" "$MEM_AVG" "$IO_RATE" "$ELAPSED"
}

measure "A+CPU" "taskset -c 0 ./a.out cpu"
measure "A+MEM" "taskset -c 0 ./a.out mem"
measure "A+IO"  "taskset -c 0 ./a.out io"
measure "B+CPU" "taskset -c 0 ./b.out cpu"
measure "B+MEM" "taskset -c 0 ./b.out mem"
measure "B+IO"  "taskset -c 0 ./b.out io"

rm -f try.txt try_thread.txt

echo ""
echo "Analysis:"
echo "- CPU-intensive programs should show high CPU% (near 100% per busy core)."
echo "- Memory-intensive programs should show high memory (RSS in KB)."
echo "- IO-intensive programs should show file write bytes / second (approx)."
echo "- Threads (B) share the same process so we monitor the single PID."
echo "- Processes (A) spawn children — we now monitor parent + its children."