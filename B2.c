/* program_b.c - creates 2 threads using pthreads */
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

#define LAST_DIGIT 5
#define COUNT (LAST_DIGIT * 1000)

void cpu(int count) {
    volatile unsigned long x = 0;
    for (int i = 0; i < count; ++i) {
        for (int j = 0; j < 1000; ++j) x += (i * 17u + j * 31u) % 1000003u;
    }
    (void)x;
    printf("CPU worker done (tid=main)\n");
}

void mem(int count) {
    size_t n = (size_t)count * 1000;
    int *a = malloc(n * sizeof(int));
    if (!a) { perror("malloc"); return; }
    for (size_t i = 0; i < n; ++i) a[i] = (int)(i & 0x7fffffff);
    for (size_t i = 0; i < n; ++i) a[i] += 1;
    free(a);
    printf("MEM worker done (tid=main)\n");
}

void io_worker(int count) {
    char fname[64];
    snprintf(fname, sizeof(fname), "/tmp/io_thread_%d.bin", (int)getpid());
    FILE *f = fopen(fname, "wb");
    if (!f) { perror("fopen"); return; }
    const char buf[4096] = {0};
    for (int i = 0; i < count; ++i) {
        if (fwrite(buf, 1, sizeof(buf), f) != sizeof(buf)) { perror("fwrite"); break; }
    }
    fclose(f);
    printf("IO worker done (thread)\n");
}

/* thread start: run io worker */
void *thread_fn(void *arg) {
    long count = (long)arg;
    io_worker((int)count);
    return NULL;
}

int main(void) {
    pthread_t t;
    if (pthread_create(&t, NULL, thread_fn, (void*)(long)COUNT) != 0) {
        perror("pthread_create");
        return 1;
    }

    /* main thread runs cpu and mem sequentially (so total threads = 2) */
    cpu(COUNT);
    mem(COUNT);

    pthread_join(t, NULL);
    return 0;
}
