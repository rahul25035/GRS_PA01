#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>

#define DEFAULT_LAST_DIGIT 5
#define DEFAULT_COUNT (DEFAULT_LAST_DIGIT * 1000)

static int parse_count(int argc, char **argv) {
    if (argc >= 3) return atoi(argv[2]);
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
    snprintf(fname, sizeof(fname), "/tmp/io_b_%d.bin", (int)getpid());
    FILE *f = fopen(fname, "wb");
    if (!f) { perror("fopen"); return; }
    const char buf[4096] = {0};
    for (int i = 0; i < count; ++i)
        if (fwrite(buf, 1, sizeof(buf), f) != sizeof(buf)) break;
    fclose(f);
    printf("io done (pid=%d) -> %s\n", (int)getpid(), fname);
}

struct argt { char *worker; int count; };

void *thread_fn(void *v) {
    struct argt *a = (struct argt *)v;
    char worker[16];
    int count;
    
    /* CRITICAL FIX: Copy data before freeing memory */
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
    
    /* CRITICAL FIX: Allocate struct on heap instead of stack */
    struct argt *a = malloc(sizeof(*a));
    if (!a) { perror("malloc"); return 1; }
    a->worker = argv[1];
    a->count = count;

    if (pthread_create(&t, NULL, thread_fn, a) != 0) { perror("pthread_create"); return 1; }

    /* main thread runs the same worker */
    if (strcmp(argv[1], "cpu") == 0) cpu_worker(count);
    else if (strcmp(argv[1], "mem") == 0) mem_worker(count);
    else if (strcmp(argv[1], "io") == 0) io_worker(count);

    pthread_join(t, NULL);
    return 0;
}
