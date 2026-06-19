/* 手册 3.2.4 RR 调度体验：SCHED_RR + sched_yield + CONFIG_RR_INTERVAL=1 */
#include <nuttx/config.h>
#include <stdio.h>
#include <pthread.h>
#include <nuttx/pthread.h>
#include <sched.h>

static volatile int g_a;

static void *add_thread(void *arg)
{
  volatile int *p = (volatile int *)arg;
  while (1)
  {
    (*p)++;
    for (volatile int i = 0; i < 100000000; i++);
    sched_yield();
  }
  return NULL;
}

static void *print_thread(void *arg)
{
  volatile int *p = (volatile int *)arg;
  while (1)
  {
    printf("val = %d\n", *p);
    for (volatile int i = 0; i < 100000000; i++);
    sched_yield();
  }
  return NULL;
}

int main(int argc, FAR char *argv[])
{
  struct sched_param param;
  pthread_t tid1, tid2;
  pthread_attr_t default_attr = {
    225, SCHED_RR, PTHREAD_EXPLICIT_SCHED, PTHREAD_CREATE_JOINABLE,
    0, NULL, PTHREAD_STACK_DEFAULT,
  };
  param.sched_priority = 225;
  sched_setscheduler(0, SCHED_RR, &param);
  pthread_create(&tid1, &default_attr, add_thread, (void *)&g_a);
  pthread_create(&tid2, &default_attr, print_thread, (void *)&g_a);
  while (1)
  {
    printf("Hello, World!! g_a = %d\n", g_a);
    for (volatile int i = 0; i < 100000000; i++);
    sched_yield();
  }
  return 0;
}
