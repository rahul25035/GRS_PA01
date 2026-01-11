#!/bin/bash

echo "==================================================================="
echo "  Multi-Process vs Multi-Thread Performance Analysis"
echo "==================================================================="
echo ""

# Compile programs
echo "Compiling programs..."
gcc A.c -o a.out
gcc B.c -o b.out -pthread
echo "Compilation complete!"
echo ""

# Create results directory
mkdir -p results
RESULTS_FILE="results/measurements.csv"

# Function to measure performance
measure() {
    NAME=$1
    CMD=$2
    
    # Clean up old files
    rm -f try*.txt

    # Start the program in background
    $CMD &
    MAIN_PID=$!

    START_TIME=$(date +%s)
    TMP_SAMPLES="/tmp/samples_$$"
    > "$TMP_SAMPLES"

    # Monitor while process is running
    while kill -0 "$MAIN_PID" 2>/dev/null; do
        CHILD_PIDS=$(ps --no-headers -o pid --ppid "$MAIN_PID" 2>/dev/null | awk '{printf ","$1}')
        PID_LIST=$(echo "$MAIN_PID$CHILD_PIDS" | sed 's/^,//')

        if [ -n "$PID_LIST" ]; then
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

    # Calculate averages
    if [ -s "$TMP_SAMPLES" ]; then
        read CPU_AVG MEM_AVG <<< $(awk '{cpu+=$1; mem+=$2; count++} END { if(count>0) printf "%.2f %.2f", cpu/count, mem/count; else printf "0.00 0.00"}' "$TMP_SAMPLES")
    else
        CPU_AVG="0.00"
        MEM_AVG="0.00"
    fi

    # Measure IO by summing all created files
    IO_BYTES=0
    for file in try*.txt; do
        if [ -f "$file" ]; then
            SIZE=$(stat -c "%s" "$file" 2>/dev/null || stat -f "%z" "$file" 2>/dev/null || echo 0)
            IO_BYTES=$((IO_BYTES + SIZE))
        fi
    done

    IO_RATE=$((IO_BYTES / ELAPSED / 1024))

    # Cleanup
    rm -f "$TMP_SAMPLES" try*.txt

    echo "$NAME,$CPU_AVG,$MEM_AVG,$IO_RATE,$ELAPSED"
}

# Initialize CSV file
echo "Program,Function,Count,CPU_Percent,Memory_KB,IO_KBps,Time_Sec" > "$RESULTS_FILE"

echo "Running experiments..."
echo ""

# Test different numbers of processes for Program A
echo "Testing Program A (Processes)..."
for count in 2 3 4 5; do
    echo "  - Testing with $count processes (CPU)..."
    RESULT=$(measure "A_CPU_$count" "taskset -c 0 ./a.out cpu $count")
    echo "A,CPU,$count,$RESULT" >> "$RESULTS_FILE"
    
    echo "  - Testing with $count processes (MEM)..."
    RESULT=$(measure "A_MEM_$count" "taskset -c 0 ./a.out mem $count")
    echo "A,MEM,$count,$RESULT" >> "$RESULTS_FILE"
    
    echo "  - Testing with $count processes (IO)..."
    RESULT=$(measure "A_IO_$count" "taskset -c 0 ./a.out io $count")
    echo "A,IO,$count,$RESULT" >> "$RESULTS_FILE"
done

# Test different numbers of threads for Program B
echo ""
echo "Testing Program B (Threads)..."
for count in 2 3 4 5 6 7 8; do
    echo "  - Testing with $count threads (CPU)..."
    RESULT=$(measure "B_CPU_$count" "taskset -c 0 ./b.out cpu $count")
    echo "B,CPU,$count,$RESULT" >> "$RESULTS_FILE"
    
    echo "  - Testing with $count threads (MEM)..."
    RESULT=$(measure "B_MEM_$count" "taskset -c 0 ./b.out mem $count")
    echo "B,MEM,$count,$RESULT" >> "$RESULTS_FILE"
    
    echo "  - Testing with $count threads (IO)..."
    RESULT=$(measure "B_IO_$count" "taskset -c 0 ./b.out io $count")
    echo "B,IO,$count,$RESULT" >> "$RESULTS_FILE"
done

echo ""
echo "==================================================================="
echo "All tests complete! Results saved to $RESULTS_FILE"
echo "==================================================================="
echo ""

# Generate plots using gnuplot
echo "Generating plots..."

# Plot 1: CPU Usage vs Count
gnuplot <<EOF
set terminal png size 1200,800
set output 'results/cpu_usage.png'
set title 'CPU Usage vs Number of Processes/Threads'
set xlabel 'Number of Processes/Threads'
set ylabel 'Average CPU Usage (%)'
set grid
set key outside right top
set style data linespoints
set datafile separator ","

plot 'results/measurements.csv' using (\$1 eq "A" && \$2 eq "CPU" ? \$3 : 1/0):4 with linespoints lw 2 pt 7 ps 1.5 title 'A (Processes) - CPU', \
     'results/measurements.csv' using (\$1 eq "B" && \$2 eq "CPU" ? \$3 : 1/0):4 with linespoints lw 2 pt 9 ps 1.5 title 'B (Threads) - CPU'
EOF

# Plot 2: Memory Usage vs Count
gnuplot <<EOF
set terminal png size 1200,800
set output 'results/memory_usage.png'
set title 'Memory Usage vs Number of Processes/Threads'
set xlabel 'Number of Processes/Threads'
set ylabel 'Average Memory Usage (KB)'
set grid
set key outside right top
set style data linespoints
set datafile separator ","

plot 'results/measurements.csv' using (\$1 eq "A" && \$2 eq "MEM" ? \$3 : 1/0):4 with linespoints lw 2 pt 7 ps 1.5 title 'A (Processes) - MEM', \
     'results/measurements.csv' using (\$1 eq "B" && \$2 eq "MEM" ? \$3 : 1/0):4 with linespoints lw 2 pt 9 ps 1.5 title 'B (Threads) - MEM'
EOF

# Plot 3: IO Throughput vs Count
gnuplot <<EOF
set terminal png size 1200,800
set output 'results/io_throughput.png'
set title 'IO Throughput vs Number of Processes/Threads'
set xlabel 'Number of Processes/Threads'
set ylabel 'IO Throughput (KB/s)'
set grid
set key outside right top
set style data linespoints
set datafile separator ","

plot 'results/measurements.csv' using (\$1 eq "A" && \$2 eq "IO" ? \$3 : 1/0):5 with linespoints lw 2 pt 7 ps 1.5 title 'A (Processes) - IO', \
     'results/measurements.csv' using (\$1 eq "B" && \$2 eq "IO" ? \$3 : 1/0):5 with linespoints lw 2 pt 9 ps 1.5 title 'B (Threads) - IO'
EOF

# Plot 4: Execution Time vs Count
gnuplot <<EOF
set terminal png size 1200,800
set output 'results/execution_time.png'
set title 'Execution Time vs Number of Processes/Threads'
set xlabel 'Number of Processes/Threads'
set ylabel 'Execution Time (seconds)'
set grid
set key outside right top
set style data linespoints
set datafile separator ","

plot 'results/measurements.csv' using (\$1 eq "A" && \$2 eq "CPU" ? \$3 : 1/0):7 with linespoints lw 2 pt 7 ps 1.5 title 'A (Processes) - CPU', \
     'results/measurements.csv' using (\$1 eq "B" && \$2 eq "CPU" ? \$3 : 1/0):7 with linespoints lw 2 pt 9 ps 1.5 title 'B (Threads) - CPU', \
     'results/measurements.csv' using (\$1 eq "A" && \$2 eq "MEM" ? \$3 : 1/0):7 with linespoints lw 2 pt 5 ps 1.5 title 'A (Processes) - MEM', \
     'results/measurements.csv' using (\$1 eq "B" && \$2 eq "MEM" ? \$3 : 1/0):7 with linespoints lw 2 pt 11 ps 1.5 title 'B (Threads) - MEM'
EOF

echo "Plots generated in results/ directory:"
echo "  - cpu_usage.png"
echo "  - memory_usage.png"
echo "  - io_throughput.png"
echo "  - execution_time.png"
echo ""

# Display the data
echo "==================================================================="
echo "Summary of Results:"
echo "==================================================================="
column -t -s',' results/measurements.csv

echo ""
echo "==================================================================="
echo "ANALYSIS AND OBSERVATIONS:"
echo "==================================================================="
echo ""
echo "1. CPU INTENSIVE WORKLOAD:"
echo "   - Processes (A): Each process gets its own CPU scheduler slot"
echo "   - Threads (B): All threads share the same process context"
echo "   - Expected: Similar CPU % but threads may show better efficiency"
echo ""
echo "2. MEMORY INTENSIVE WORKLOAD:"
echo "   - Processes (A): Each allocates separate memory (higher total)"
echo "   - Threads (B): Threads share address space (lower total memory)"
echo "   - Expected: Processes use N times more memory than threads"
echo ""
echo "3. IO INTENSIVE WORKLOAD:"
echo "   - Processes (A): Each writes to separate files independently"
echo "   - Threads (B): May contend for file system locks"
echo "   - Expected: Similar IO throughput, possible contention in threads"
echo ""
echo "4. SCALABILITY:"
echo "   - As count increases, processes create more overhead (fork cost)"
echo "   - Threads have lower creation overhead but share resources"
echo "   - CPU bound: Both limited by single core (taskset -c 0)"
echo ""
echo "==================================================================="