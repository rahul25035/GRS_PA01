#include <stdio.h>
#include <unistd.h>

int main(){
    printf("Hello before fork\n");
    pid_t p;

    p=fork();

    if (p<0){
        printf("Fork failed");
    }
    else if (p==0){
        printf("Child process with PID=%d \n", getpid());
    }
    else{
        printf("Parent process with PID=%d \n", getpid());

    }
    return 0;



}