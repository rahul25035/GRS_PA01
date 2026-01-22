/* MT25035_PartB_threads.c */
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>
#include <pthread.h>

#define ITER (5 * 1000) /* last digit 5 -> 5*10^3 = 5000 */

void cpu_func(void) {
    volatile long long counter = 0;
    for (long long i = 0; i < ITER; i++) {
        for (long long j = 0; j < 1000000; j++) {
            counter++;
        }
    }
}

void mem_func(void) {
    size_t size = 256UL * 1024 * 1024; /* 256 MB */
    char *buf = malloc(size);
    if (!buf) {
        perror("malloc");
        exit(1);
    }

    for (long long j = 0; j < ITER; j++) {
        for (size_t i = 0; i < size; i += 4096) {
            buf[i] = 1;
        }
    }

    free(buf);
}

void io_func(void) {
    int fd = open("try_proc.txt", O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        exit(1);
    }

    char buf[4096];
    memset(buf, 'A', sizeof(buf));

    for (int i = 0; i < ITER; i++) {
        if (write(fd, buf, sizeof(buf)) < 0) {
            perror("write");
            close(fd);
            exit(1);
        }
        fsync(fd);
    }

    close(fd);
}

void *thread_func(void *arg) {
    char *mode = (char *)arg;

    if (strcmp(mode, "cpu") == 0) cpu_func();
    else if (strcmp(mode, "mem") == 0) mem_func();
    else if (strcmp(mode, "io")  == 0) io_func();

    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s cpu|mem|io <num_threads>\n", argv[0]);
        return 1;
    }

    int num_threads = atoi(argv[2]);

    pthread_t t[num_threads];

    for (int i = 0; i < num_threads; i++) {
        if (pthread_create(&t[i], NULL, thread_func, argv[1]) != 0) {
            perror("pthread_create");
            exit(1);
        }
    }

    for (int i = 0; i < num_threads; i++) {
        pthread_join(t[i], NULL);
    }

    return 0;
}
