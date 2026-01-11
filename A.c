#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <fcntl.h>   
#include <string.h>

#define ITER (5 * 1000)

void cpu_func() {
    volatile long long counter = 0;
    for (long long i = 0; i < ITER; i++) {
        for (long long j = 0; j < 1000000; j++) {
            counter++;
        }
    }
}

void mem_func() {
    size_t size = 256UL * 1024 * 1024;
    char *buf = malloc(size);
    if (buf == NULL) {
        perror("malloc");
        exit(1);
    }
    for (long long j = 0; j < ITER; j++) {
        for (size_t i = 0; i < size; i += 4096) {
            buf[i] = 1;
        }
    }
    sleep(30);
    free(buf);
}

void io_func() {
    char filename[50];
    sprintf(filename, "try_%d.txt", getpid());
    int fd = open(filename, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        exit(1);
    }
    char buf[4096];
    memset(buf, 'A', sizeof(buf));
    for (int i = 0; i < ITER; i++) {
        write(fd, buf, sizeof(buf));
        fsync(fd);
    }
    close(fd);
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        printf("Usage: %s <cpu|mem|io> <num_processes>\n", argv[0]);
        return 1;
    }

    int num_procs = atoi(argv[2]);
    if (num_procs < 1 || num_procs > 10) {
        printf("Number of processes should be between 1 and 10\n");
        return 1;
    }

    // Parent prints its PID first
    printf("PARENT_PID: %d\n", getpid());
    fflush(stdout);
    
    sleep(1);  // Give script time to see parent PID

    // Create specified number of child processes
    for (int i = 0; i < num_procs; i++) {
        pid_t pid = fork();
        if (pid < 0) {
            perror("fork");
            return 1;
        }
        
        if (pid == 0) {
            // Child process
            printf("CHILD_PID: %d\n", getpid());
            fflush(stdout);
            sleep(1);  // Ensure script captures PID
            
            if (strcmp(argv[1], "cpu") == 0) cpu_func();
            else if (strcmp(argv[1], "mem") == 0) mem_func();
            else if (strcmp(argv[1], "io") == 0) io_func();
            
            exit(0);
        }
    }

    // Parent waits for all children
    for (int i = 0; i < num_procs; i++) {
        wait(NULL);
    }
    
    return 0;
}