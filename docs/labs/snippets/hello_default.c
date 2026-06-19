/* 实验一：手册默认 hello_main.c（仅主循环打印） */
#include <nuttx/config.h>
#include <stdio.h>

int main(int argc, FAR char *argv[])
{
  while (1)
  {
    printf("Hello, World!!\n");
    sleep(1);
  }
  return 0;
}
