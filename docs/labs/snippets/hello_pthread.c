static volatile int g_a;

void *add_thread(void *arg) {
    volatile int *p = (volatile int *)arg;
    while (1) { (*p)++; sleep(1); }
    return NULL;
}

void *print_thread(void *arg) {
    volatile int *p = (volatile int *)arg;
    while (1) { printf("val = %d\n", *p); sleep(1); }
    return NULL;
}

int main(int argc, FAR char *argv[]) {
    pthread_t tid1, tid2;
    pthread_create(&tid1, NULL, add_thread, &g_a);
    pthread_create(&tid2, NULL, print_thread, &g_a);
    while (1) { printf("Hello, World!!\n"); sleep(5); }
    return 0;
}
