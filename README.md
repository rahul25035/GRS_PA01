# Process vs Thread Performance Analysis in C

## Overview

This assignment studies the performance characteristics of **processes** and **threads** under different workload types using the C programming language. Two programs are implemented:

* **Program A**: Uses `fork()` to create multiple processes
* **Program B**: Uses `pthread` to create multiple threads

Each program executes one of three worker functions:

* **CPU-intensive**
* **Memory-intensive**
* **I/O-intensive**

System behavior is observed using standard Linux tools such as `top`, `iostat`, `time`, and `taskset`.

---

## Files in the Repository

```
.
├── A.c          # Process-based program using fork()
├── B.c          # Thread-based program using pthreads
├── main.sh      # Automates execution and metric collection
├── plots.sh     # Generates performance plots using gnuplot
├── Makefile     # Build and automation rules
├── results.csv  # Generated performance metrics (after run)
└── README.md
```

---

## Workload Description

Each worker function runs a loop with a fixed iteration count (`ITER = 5000`), representing a scaled workload.

### 1. CPU-intensive (`cpu`)

Performs nested arithmetic loops that keep the CPU busy with minimal memory or I/O interaction.

### 2. Memory-intensive (`mem`)

Allocates a large memory buffer (256 MB) and repeatedly touches memory pages, stressing the memory subsystem.

### 3. I/O-intensive (`io`)

Performs repeated disk writes followed by `fsync()`, forcing synchronous disk I/O.

The same worker logic is shared between process-based and thread-based implementations.

---

## Compilation

Compile both programs using:

```bash
make
```

This generates:

* `a.out` (process-based program)
* `b.out` (thread-based program)

---

## Running Experiments

To run all experiments automatically:

```bash
make run
```

This performs:

* Execution of all program + workload combinations
* CPU pinning using `taskset`
* Periodic sampling of:

  * CPU usage (`top`)
  * Memory usage (`top`)
  * Disk I/O statistics (`iostat`)
* Execution time measurement using GNU `time`

Results are saved to `results.csv`.

---

## Plot Generation

To generate plots from the collected data:

```bash
make plots
```

This creates graphs such as:

* Execution time vs number of components
* CPU utilization vs number of components
* Memory usage vs number of components

Plots are generated using **gnuplot** and saved as `.png` files.

---

## Cleanup

To remove all generated binaries, data files, and plots:

```bash
make clean
```

---

## Experimental Setup Notes

* Programs are pinned to specific CPU cores using `taskset` to ensure controlled CPU scheduling.
* CPU, memory, and I/O statistics are sampled once per second and averaged over execution time.
* The number of processes and threads is varied to study scalability effects.
* All measurements are automated via shell scripts for reproducibility.

---

## Conclusion

This assignment demonstrates how workload type significantly influences system performance and scalability, and highlights the practical differences between process-based and thread-based parallelism on a Linux system.
