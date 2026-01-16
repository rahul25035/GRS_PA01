# Makefile for Process vs Thread Performance Assignment

CC = gcc
CFLAGS = -Wall
PTHREAD = -pthread

A_OUT = a.out
B_OUT = b.out

.PHONY: all clean run plots

# Default target
all: $(A_OUT) $(B_OUT)

# Compile Program A (process-based)
$(A_OUT): A.c
	$(CC) $(CFLAGS) A.c -o $(A_OUT)

# Compile Program B (thread-based)
$(B_OUT): B.c
	$(CC) $(CFLAGS) B.c -o $(B_OUT) $(PTHREAD)

# Run the full experiment (calls main.sh)
run: all
	chmod +x main.sh
	./main.sh

# Generate plots (calls plots.sh)
plots:
	chmod +x plots.sh
	./plots.sh

# Clean generated files
clean:
	rm -f $(A_OUT) $(B_OUT) results.csv *.dat *.png try_proc.txt try_thread.txt
