#include <stdio.h>
#include <pthread.h>

void* func1(void* arg) {
    int i = (int)arg;   
    printf("Thread with argument %d\n", i);
    return NULL;
}

int main() {
    pthread_t t;

    pthread_create(&t, NULL, func1, (void*)1);
    pthread_join(t, NULL);

    printf("Main thread\n");
    return 0;
}
