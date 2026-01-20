/* MT25035_PartA_A.c */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(void) {
    pid_t pid1 = fork();
    if (pid1 < 0) { perror("fork"); exit(1); }

    if (pid1 == 0) {
        printf("Child 1: pid=%d\n", getpid());
        return 0;
    }

    pid_t pid2 = fork();
    if (pid2 < 0) { perror("fork"); exit(1); }

    if (pid2 == 0) {
        printf("Child 2: pid=%d\n", getpid());
        return 0;
    }

    wait(NULL);
    wait(NULL);
    return 0;
}
