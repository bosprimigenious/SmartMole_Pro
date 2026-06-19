static int spi_lcd_updatearea(struct fb_vtable_s *vtable, FAR const struct fb_area_s *area)
{
  struct spi_dev_s *spi = g_spi_lcd_fb->spi;
  int stride = g_spi_lcd_fb->planeinfo.stride;
  int width_byte = area->w * (g_spi_lcd_fb->planeinfo.bpp >> 3);
  unsigned char *fb = g_spi_lcd_fb->planeinfo.fbmem + area->y * stride + area->x * (g_spi_lcd_fb->planeinfo.bpp >> 3);
  static uint8_t *swapped_datas;
  if (!swapped_datas)
  {
    swapped_datas = malloc(stride);
  }
  LCD_SetWindows(area->x, area->y, area->x + area->w - 1, area->y + area->h - 1);
  lcd_lock();
  LCD_SetDataLine();
  SPI_SELECT(spi, 0, true);
  for (int y = area->y; y < area->y + area->h; y++)
  {
    memcpy(swapped_datas, fb, width_byte);
    sw_rgb565_swap(swapped_datas, area->w);
    SPI_SNDBLOCK(spi, swapped_datas, width_byte);
    fb += stride;
  }
  SPI_SELECT(spi, 0, false);
  lcd_unlock();
  return 0;
}
