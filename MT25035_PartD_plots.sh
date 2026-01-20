#MT25035_PartD_plots.sh
#!/bin/bash

CSV="MT25035_PartD_results.csv"

if [ ! -f "$CSV" ]; then
    echo "Error: $CSV not found. Run main.sh first."
    exit 1
fi

echo "Preparing data for plots..."

# Create temp data files (components value)
awk -F, '$2=="A" && $3=="cpu" {print $1, $7}' "$CSV" | sort -n > cpu_time_A.dat
awk -F, '$2=="B" && $3=="cpu" {print $1, $7}' "$CSV" | sort -n > cpu_time_B.dat

awk -F, '$2=="A" && $3=="mem" {print $1, $7}' "$CSV" | sort -n > mem_time_A.dat
awk -F, '$2=="B" && $3=="mem" {print $1, $7}' "$CSV" | sort -n > mem_time_B.dat

awk -F, '$2=="A" && $3=="cpu" {print $1, $4}' "$CSV" | sort -n > cpu_util_A.dat
awk -F, '$2=="B" && $3=="cpu" {print $1, $4}' "$CSV" | sort -n > cpu_util_B.dat

awk -F, '$2=="A" && $3=="mem" {print $1, $5}' "$CSV" | sort -n > mem_util_A.dat
awk -F, '$2=="B" && $3=="mem" {print $1, $5}' "$CSV" | sort -n > mem_util_B.dat

echo "Generating plots..."

gnuplot <<EOF
set terminal pngcairo size 900,600
set grid
set key left top
set xlabel "Components"

# -------- Time vs Components (CPU workload) --------
set output "time_cpu.png"
set title "Execution Time vs Components (CPU workload)"
set ylabel "Time (sec)"
plot \
    "cpu_time_A.dat" using 1:2 with linespoints lw 2 pt 7 ps 1.0 title "A (process)", \
    "cpu_time_B.dat" using 1:2 with linespoints lw 2 pt 5 ps 1.0 title "B (thread)"

# -------- Time vs Components (MEM workload) --------
set output "time_mem.png"
set title "Execution Time vs Components (MEM workload)"
set ylabel "Time (sec)"
plot \
    "mem_time_A.dat" using 1:2 with linespoints lw 2 pt 7 ps 1.0 title "A (process)", \
    "mem_time_B.dat" using 1:2 with linespoints lw 2 pt 5 ps 1.0 title "B (thread)"

# -------- CPU Utilization vs Components --------
set output "cpu_usage.png"
set title "CPU Utilization vs Components (CPU workload)"
set ylabel "CPU %"
plot \
    "cpu_util_A.dat" using 1:2 with linespoints lw 2 pt 7 ps 1.0 title "A (process)", \
    "cpu_util_B.dat" using 1:2 with linespoints lw 2 pt 5 ps 1.0 title "B (thread)"

# -------- Memory Usage vs Components --------
set output "mem_usage.png"
set title "Memory Usage vs Components (MEM workload)"
set ylabel "Memory (MB)"
plot \
    "mem_util_A.dat" using 1:2 with linespoints lw 2 pt 7 ps 1.0 title "A (process)", \
    "mem_util_B.dat" using 1:2 with linespoints lw 2 pt 5 ps 1.0 title "B (thread)"
EOF

# Cleanup temp files
rm -f *.dat

echo "Plots created:"
ls *.png
