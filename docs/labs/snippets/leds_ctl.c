/* leds.c：LED1 低电平点亮（与 MyWhackMole flash_led1 一致） */
int leds_ctl(int led, bool on)
{
  if (led == 0) {
    /* LED1 → /dev/gpio0，写 0 亮，写 1 灭 */
    return gpio_write(led1_fd, on ? 0 : 1);
  }
  return -1;
}
