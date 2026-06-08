#ifndef WHACKMOLE_H
#define WHACKMOLE_H

#include <lvgl/lvgl.h>

#define RES_ROOT CONFIG_EXAMPLES_LVGLDEMO_DATA_ROOT "/res"
#define ICONS_ROOT RES_ROOT "/icons"
#define FONTS_ROOT RES_ROOT "/fonts"

void init_whack_a_mole_game(lv_obj_t *parent);
void app_create(void);

struct resource_s {

    struct {
        struct {
            lv_font_t *normal;
        } size_14;

        struct {
            lv_font_t *bold;
        } size_22;
    } fonts;

    struct {
        lv_style_t button_default;
        lv_style_t button_pressed;
        lv_style_transition_dsc_t button_transition_dsc;
        lv_style_transition_dsc_t transition_dsc;
    } styles;

    struct {
        const char *hammer;
        const char *mole;
        const char *grassland;
    } images;
};

#endif
