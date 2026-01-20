CC=gcc
CFLAGS=-Wall
PTHREAD=-pthread

MODE?=cpu
N?=2

.PHONY: partA partB partC partD run clean

partA:
	$(CC) $(CFLAGS) MT25035_PartA_A.c -o a.out
	./a.out $(MODE) $(N)

partB:
	$(CC) $(CFLAGS) MT25035_PartA_B.c -o b.out $(PTHREAD)
	./b.out $(MODE) $(N)

partC:
	chmod +x MT25035_PartC_main.sh
	./MT25035_PartC_main.sh

partD:
	chmod +x MT25035_PartD_main.sh
	./MT25035_PartD_main.sh

run: partD

clean:
	rm -f a.out b.out try_proc.txt try_thread.txt *.csv *.png *.dat
