/* C1.c - fork() version: both parent and child run the chosen worker
   Compile: gcc -O2 C1.c -o c1.out
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include <errno.h>

#define DEFAULT_LAST_DIGIT 5
#define DEFAULT_COUNT (DEFAULT_LAST_DIGIT * 1000)

static int parse_count(int argc, char **argv) {
    if (argc >= 3) {
        char *endptr = NULL;
        long v = strtol(argv[2], &endptr, 10);
        if (endptr == argv[2] || v <= 0) {
            fprintf(stderr, "Invalid count '%s', using default %d\n", argv[2], DEFAULT_COUNT);
            return DEFAULT_COUNT;
        }
        return (int)v;
    }
    return DEFAULT_COUNT;
}

void cpu_worker(int count) {
    volatile unsigned long x = 0;
    for (int i = 0; i < count; ++i)
        for (int j = 0; j < 1000; ++j)
            x += (i * 17u + j * 31u) % 1000003u;
    (void)x;
    printf("cpu done (pid=%d)\n", (int)getpid());
}

void mem_worker(int count) {
    size_t n = (size_t)count * 1000;
    int *a = malloc(n * sizeof(int));
    if (!a) { perror("malloc"); return; }
    for (size_t i = 0; i < n; ++i) a[i] = (int)(i & 0x7fffffff);
    for (size_t i = 0; i < n; ++i) a[i] += 1;
    free(a);
    printf("mem done (pid=%d)\n", (int)getpid());
}

void io_worker(int count) {
    char fname[64];
    snprintf(fname, sizeof(fname), "/tmp/io_a_%d.bin", (int)getpid());
    FILE *f = fopen(fname, "wb");
    if (!f) { fprintf(stderr, "fopen(%s): %s\n", fname, strerror(errno)); return; }
    const char buf[4096] = {0};
    for (int i = 0; i < count; ++i)
        if (fwrite(buf, 1, sizeof(buf), f) != sizeof(buf)) break;
    fclose(f);
    printf("io done (pid=%d) -> %s\n", (int)getpid(), fname);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <cpu|mem|io> [count]\n", argv[0]); return 1; }
    int count = parse_count(argc, argv);

    pid_t p = fork();
    if (p < 0) { perror("fork"); return 1; }
    if (p == 0) {
        /* child runs the worker */
        if (strcmp(argv[1], "cpu") == 0) cpu_worker(count);
        else if (strcmp(argv[1], "mem") == 0) mem_worker(count);
        else if (strcmp(argv[1], "io") == 0) io_worker(count);
        return 0;
    } else {
        /* parent runs the worker too */
        if (strcmp(argv[1], "cpu") == 0) cpu_worker(count);
        else if (strcmp(argv[1], "mem") == 0) mem_worker(count);
        else if (strcmp(argv[1], "io") == 0) io_worker(count);

        wait(NULL);
        return 0;
    }
}
