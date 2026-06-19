/* 横屏触摸：FT5X06_SWAPXY 开启后，X 由芯片 Y 换算并镜像 */
#ifdef CONFIG_FT5X06_SWAPXY
  x = 480 - TOUCH_POINT_GET_Y(touch[0]);
  /* 多点触摸同理： */
  point[i].x = 480 - TOUCH_POINT_GET_Y(touch[i]);
#endif
