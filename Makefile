CC=gcc
CFLAGS=-Wall
PTHREAD=-pthread

MODE?=cpu
N?=2

.PHONY: partA partB partC partD run clean

partA:
	$(CC) $(CFLAGS) MT25035_Part_A_Program_A.c -o a.out
	$(CC) $(CFLAGS) MT25035_Part_A_Program_B.c -o b.out $(PTHREAD)
	./a.out $(MODE) $(N)
	./b.out $(MODE) $(N)
	rm -f a.out b.out

partB:
	$(CC) $(CFLAGS) MT25035_Part_B_Program_A.c -o a.out $(PTHREAD)
	$(CC) $(CFLAGS) MT25035_Part_B_Program_B.c -o b.out $(PTHREAD)
	./a.out $(MODE) $(N)
	./b.out $(MODE) $(N)
	rm -f a.out b.out

partC:
	chmod +x MT25035_Part_C_main.sh
	./MT25035_Part_C_main.sh

partD:
	chmod +x MT25035_Part_D_main.sh
	./MT25035_Part_D_main.sh

run: partD

clean:
	rm -f a.out b.out try_proc.txt try_thread.txt *.dat 
