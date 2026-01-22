#!/bin/bash
# MT25035_Part_D_plots.sh
# Minimal script: makes 4 plots (cpu, mem, io, time) vs number of components.
# Expects MT25035_Part_D_results.csv in the same folder.

CSV="MT25035_Part_D_results.csv"
if [ ! -f "$CSV" ]; then
  echo "Error: '$CSV' not found in current directory."
  exit 1
fi

# Create simple data files (skip header with NR>1)
awk -F, 'NR>1 && $2=="A" && $3=="cpu" {print $1, $4}' "$CSV" | sort -n > cpu_A.dat
awk -F, 'NR>1 && $2=="B" && $3=="cpu" {print $1, $4}' "$CSV" | sort -n > cpu_B.dat

awk -F, 'NR>1 && $2=="A" && $3=="mem" {print $1, $5}' "$CSV" | sort -n > mem_A.dat
awk -F, 'NR>1 && $2=="B" && $3=="mem" {print $1, $5}' "$CSV" | sort -n > mem_B.dat

awk -F, 'NR>1 && $2=="A" && $3=="io" {print $1, $6}' "$CSV" | sort -n > io_A.dat
awk -F, 'NR>1 && $2=="B" && $3=="io" {print $1, $6}' "$CSV" | sort -n > io_B.dat

# For time plot we use time_sec from the cpu workload (column 7)
awk -F, 'NR>1 && $2=="A" && $3=="cpu" {print $1, $7}' "$CSV" | sort -n > time_A.dat
awk -F, 'NR>1 && $2=="B" && $3=="cpu" {print $1, $7}' "$CSV" | sort -n > time_B.dat

# Create PNGs with gnuplot (simple, clean)
gnuplot <<'GNUPLOT'
set terminal pngcairo size 900,600 enhanced font 'Sans,10'
set grid
set xlabel "Number of components"
set style data linespoints
set pointsize 1.0
set key left top

set output "cpu_vs_components.png"
set ylabel "CPU (%)"
set title "CPU vs Components (function = cpu)"
plot "cpu_A.dat" using 1:2 title "A (process)" lw 2 pt 7, \
     "cpu_B.dat" using 1:2 title "B (thread)" lw 2 pt 5

set output "mem_vs_components.png"
set ylabel "Memory (MB)"
set title "Memory vs Components (function = mem)"
plot "mem_A.dat" using 1:2 title "A (process)" lw 2 pt 7, \
     "mem_B.dat" using 1:2 title "B (thread)" lw 2 pt 5

set output "io_vs_components.png"
set ylabel "IO (KB/s)"
set title "IO vs Components (function = io)"
plot "io_A.dat" using 1:2 title "A (process)" lw 2 pt 7, \
     "io_B.dat" using 1:2 title "B (thread)" lw 2 pt 5

set output "time_vs_components.png"
set ylabel "Time (sec)"
set title "Execution time vs Components (function = cpu)"
plot "time_A.dat" using 1:2 title "A (process)" lw 2 pt 7, \
     "time_B.dat" using 1:2 title "B (thread)" lw 2 pt 5
GNUPLOT

# Cleanup
rm -f cpu_*.dat mem_*.dat io_*.dat time_*.dat

echo "Plots created: cpu_vs_components.png, mem_vs_components.png, io_vs_components.png, time_vs_components.png"
