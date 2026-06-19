static void flash_led1(void)
{
  int fd_led = open("/dev/gpio0", O_RDWR);
  if (fd_led < 0)
  {
    return;
  }
  ioctl(fd_led, GPIOC_SETPINTYPE, GPIO_OUTPUT_PIN);
  ioctl(fd_led, GPIOC_WRITE, 0);
  usleep(150 * 1000);
  ioctl(fd_led, GPIOC_WRITE, 1);
  close(fd_led);
}
