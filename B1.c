/* program_a.c  - creates 2 processes using fork() */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#define LAST_DIGIT 5        
#define COUNT (LAST_DIGIT * 1000)

void cpu(int count) {
    volatile unsigned long x = 0;
    for (int i = 0; i < count; ++i) {
        for (int j = 0; j < 1000; ++j) {
            x += (i * 17u + j * 31u) % 1000003u;
        }
    }
    (void)x;
    printf("CPU worker done (pid=%d)\n", getpid());
}

void mem(int count) {
    size_t n = (size_t)count * 1000; /* size scales with count */
    int *a = malloc(n * sizeof(int));
    if (!a) { perror("malloc"); return; }
    for (size_t i = 0; i < n; ++i) a[i] = (int)(i & 0x7fffffff);
    /* touch again to ensure memory activity */
    for (size_t i = 0; i < n; ++i) a[i] += 1;
    free(a);
    printf("MEM worker done (pid=%d)\n", getpid());
}

void io_worker(int count) {
    char fname[64];
    snprintf(fname, sizeof(fname), "/tmp/io_worker_%d.bin", (int)getpid());
    FILE *f = fopen(fname, "wb");
    if (!f) { perror("fopen"); return; }
    const char buf[4096] = {0};
    for (int i = 0; i < count; ++i) {
        if (fwrite(buf, 1, sizeof(buf), f) != sizeof(buf)) { perror("fwrite"); break; }
    }
    fclose(f);
    printf("IO worker done (pid=%d) -> %s\n", getpid(), fname);
}

int main(void) {
    pid_t p = fork();
    if (p < 0) {
        perror("fork");
        return 1;
    } else if (p == 0) {
        /* child */
        printf("Child (pid=%d): running mem worker\n", getpid());
        mem(COUNT);
        return 0;
    } else {
        /* parent */
        printf("Parent (pid=%d): running cpu worker; child pid=%d\n", getpid(), (int)p);
        cpu(COUNT);
        /* optional: wait for child so it doesn't become a zombie */
        wait(NULL);
        /* parent can also run IO if you want:
           io_worker(COUNT);
         */
        return 0;
    }
}
