/* 手册 3.2.3 FIFO 调度体验：三线程均为最高优先级 225，忙等不占 sleep */
static volatile int g_a;

static void set_max_priority(void) {
    struct sched_param sp;
    sp.sched_priority = 225;
    pthread_setschedparam(pthread_self(), SCHED_FIFO, &sp);
}

void *add_thread(void *arg) {
    volatile int *p = (volatile int *)arg;
    volatile int i;
    set_max_priority();
    while (1) {
        (*p)++;
        for (i = 0; i < 100000000; i++) { }
    }
    return NULL;
}

void *print_thread(void *arg) {
    volatile int *p = (volatile int *)arg;
    volatile int i;
    set_max_priority();
    while (1) {
        printf("val = %d\n", *p);
        for (i = 0; i < 100000000; i++) { }
    }
    return NULL;
}

int main(int argc, FAR char *argv[]) {
    pthread_t tid1, tid2;
    volatile int i;
    set_max_priority();
    pthread_create(&tid1, NULL, add_thread, &g_a);
    pthread_create(&tid2, NULL, print_thread, &g_a);
    while (1) {
        printf("Hello, World!! g_a = %d\n", g_a);
        for (i = 0; i < 100000000; i++) { }
    }
    return 0;
}
