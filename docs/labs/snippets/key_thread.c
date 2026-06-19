static void *key_thread(void *arg)
{
  int fd_key = open("/dev/gpio1", O_RDONLY);
  bool key_value;
  if (fd_key < 0)
  {
    return NULL;
  }
  ioctl(fd_key, GPIOC_SETPINTYPE, GPIO_INPUT_PIN_PULLDOWN);
  while (1)
  {
    ioctl(fd_key, GPIOC_READ, (unsigned long)((uintptr_t)&key_value));
    if (key_value == true)
    {
      lvgl_lock();
      start_game(NULL);
      lvgl_unlock();
      usleep(300 * 1000);
    }
    usleep(20 * 1000);
  }
  return NULL;
}
