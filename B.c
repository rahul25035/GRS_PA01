#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <fcntl.h>

#define ITER (5 * 1000)

void* cpu_func(void* args) {
    volatile long long counter = 0;
    for (long long i = 0; i < ITER; i++) {
        for (long long j = 0; j < 1000000; j++) {
            counter++;
        }
    }
    return NULL;
}

void* mem_func(void* args) {
    size_t size = 256UL * 1024 * 1024;
    char* buf = malloc(size);
    if (buf == NULL) {
        perror("malloc");
        return NULL;
    }
    for (long long j = 0; j < ITER; j++) {
        for (size_t i = 0; i < size; i += 4096) {
            buf[i] = 1;
        }
    }
    sleep(30);
    free(buf);
    return NULL;
}

void* io_func(void* args) {
    int thread_id = *(int*)args;
    char filename[50];
    sprintf(filename, "try_thread_%d.txt", thread_id);
    int fd = open(filename, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        return NULL;
    }
    char buf[4096];
    memset(buf, 'A', sizeof(buf));
    for (int i = 0; i < ITER; i++) {
        write(fd, buf, sizeof(buf));
        fsync(fd);  
    }
    close(fd);
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        printf("Usage: %s <cpu|mem|io> <num_threads>\n", argv[0]);
        return 1;
    }

    int num_threads = atoi(argv[2]);
    if (num_threads < 1 || num_threads > 10) {
        printf("Number of threads should be between 1 and 10\n");
        return 1;
    }

    printf("PID: %d\n", getpid());
    fflush(stdout);
    sleep(2);

    pthread_t threads[num_threads];
    int thread_ids[num_threads];

    // Create threads
    for (int i = 0; i < num_threads; i++) {
        thread_ids[i] = i;
        if (strcmp(argv[1], "cpu") == 0) {
            pthread_create(&threads[i], NULL, cpu_func, NULL);
        }
        else if (strcmp(argv[1], "mem") == 0) {
            pthread_create(&threads[i], NULL, mem_func, NULL);
        }
        else if (strcmp(argv[1], "io") == 0) {
            pthread_create(&threads[i], NULL, io_func, &thread_ids[i]);
        }
        else {
            printf("Invalid argument. Use cpu, mem, or io\n");
            return 1;
        }
    }

    // Wait for all threads
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    
    return 0;
}