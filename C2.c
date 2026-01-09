/* C2.c - pthread version: main thread + one created thread run the chosen worker
   Compile: gcc -O2 C2.c -o c2.out -pthread
*/

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
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
    printf("cpu done (pid=%d tid=%lu)\n", (int)getpid(), (unsigned long)pthread_self());
}

void mem_worker(int count) {
    size_t n = (size_t)count * 1000;
    int *a = malloc(n * sizeof(int));
    if (!a) { perror("malloc"); return; }
    for (size_t i = 0; i < n; ++i) a[i] = (int)(i & 0x7fffffff);
    for (size_t i = 0; i < n; ++i) a[i] += 1;
    free(a);
    printf("mem done (pid=%d tid=%lu)\n", (int)getpid(), (unsigned long)pthread_self());
}

void io_worker(int count) {
    char fname[128];
    /* include pid and thread id so multiple threads don't clobber the same file */
    snprintf(fname, sizeof(fname), "/tmp/io_b_%d_%lu.bin",
             (int)getpid(), (unsigned long)pthread_self());
    FILE *f = fopen(fname, "wb");
    if (!f) { fprintf(stderr, "fopen(%s): %s\n", fname, strerror(errno)); return; }
    const char buf[4096] = {0};
    for (int i = 0; i < count; ++i)
        if (fwrite(buf, 1, sizeof(buf), f) != sizeof(buf)) break;
    fclose(f);
    printf("io done (pid=%d tid=%lu) -> %s\n", (int)getpid(), (unsigned long)pthread_self(), fname);
}

struct argt { char worker[16]; int count; };

void *thread_fn(void *v) {
    struct argt *a = (struct argt *)v;
    char worker[16];
    int count;

    /* copy data locally and free heap struct */
    strncpy(worker, a->worker, sizeof(worker) - 1);
    worker[sizeof(worker) - 1] = '\0';
    count = a->count;
    free(a);

    if (strcmp(worker, "cpu") == 0) cpu_worker(count);
    else if (strcmp(worker, "mem") == 0) mem_worker(count);
    else if (strcmp(worker, "io") == 0) io_worker(count);
    return NULL;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <cpu|mem|io> [count]\n", argv[0]); return 1; }
    int count = parse_count(argc, argv);
    pthread_t t;

    /* allocate argument on heap and copy worker string into struct */
    struct argt *a = malloc(sizeof(*a));
    if (!a) { perror("malloc"); return 1; }
    strncpy(a->worker, argv[1], sizeof(a->worker) - 1);
    a->worker[sizeof(a->worker) - 1] = '\0';
    a->count = count;

    if (pthread_create(&t, NULL, thread_fn, a) != 0) { perror("pthread_create"); free(a); return 1; }

    /* main thread runs the same worker */
    if (strcmp(argv[1], "cpu") == 0) cpu_worker(count);
    else if (strcmp(argv[1], "mem") == 0) mem_worker(count);
    else if (strcmp(argv[1], "io") == 0) io_worker(count);

    pthread_join(t, NULL);
    return 0;
}
