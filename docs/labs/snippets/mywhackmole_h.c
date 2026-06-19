#ifndef __APPS_EXAMPLES_MYWHACKMOLE_MYWHACKMOLE_H
#define __APPS_EXAMPLES_MYWHACKMOLE_MYWHACKMOLE_H
#include <lvgl/lvgl.h>
#define RES_ROOT CONFIG_EXAMPLES_MYWHACKMOLE_DATA_ROOT
#define ICONS_ROOT RES_ROOT "/icons"
#define FONTS_ROOT RES_ROOT "/fonts"
#define HIT_WAV RES_ROOT "/hit.wav"
void init_whack_a_mole_game(void);
void app_create(void);
#endif
