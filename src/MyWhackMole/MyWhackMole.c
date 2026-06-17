#include "MyWhackMole.h"
#include "media_wifi/media_wifi.h"
#include "storage.h"
#include "src/display/lv_display.h"
#include "src/font/lv_font.h"
#include <lvgl/lvgl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <pthread.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <nuttx/ioexpander/gpio.h>
#include <stdlib.h>
#include <string.h>

#define GAME_TIME 30

static lv_obj_t* game_screen = NULL;
static lv_obj_t* moles[9];
static lv_obj_t* hit_boxes[9];
static lv_obj_t* score_label;
static lv_obj_t* score_a_label;
static lv_obj_t* score_b_label;
static lv_obj_t* time_label;
static lv_obj_t* hammer_cursor = NULL;

typedef struct {
    int x;
    int y;
} hole_pos_t;

static hole_pos_t hole_positions[9] = {
    { 92, 82 }, { 225, 82 }, { 363, 82 },
    { 69, 149 }, { 225, 149 }, { 363, 149 },
    { 69, 219 }, { 225, 219 }, { 382, 219 }
};


typedef struct {
    int level;
    int refresh_ms;
    int show_ms;
    int mole_count;
    int base_speed;
} level_config_t;

static level_config_t level_configs[] = {
    {1, 1200, 1500, 1, 1},
    {2, 1000, 1300, 1, 2},
    {3, 850, 1100, 2, 3},
    {4, 700, 900, 2, 4},
    {5, 550, 700, 3, 5}
};

#define LEVEL_COUNT (sizeof(level_configs) / sizeof(level_configs[0]))

static int current_level = 1;
static level_config_t current_level_config;
static lv_obj_t* level_label = NULL;
static lv_obj_t* mode_label = NULL;
static lv_obj_t* combo_label = NULL;
static lv_obj_t* wifi_status_label = NULL;

#define MOLE_NORMAL 0
#define MOLE_GOLD   1
#define MOLE_BOMB   2

static int mole_types[9];
static int combo_count = 0;

static int score = 0;
static int score_a = 0;
static int score_b = 0;
static int game_time = GAME_TIME;
static lv_timer_t* game_timer = NULL;
static lv_timer_t* mole_timer = NULL;

static volatile int led_flash_request = 0;
static volatile int start_game_request = 0;

static pthread_t led_thread;

static void apply_level_config(int level);
static void check_level_up(void);
static void update_level_label(void);
static int random_mole_type(void);
static void apply_mole_type_style(int idx);
static void update_combo_label(void);
static int get_combo_bonus(void);
static void level_btn_event_cb(lv_event_t* e);
static void stats_btn_event_cb(lv_event_t* e);


static int random_mole_type(void)
{
    int r = rand() % 100;

    if (r < 5) {
        return MOLE_BOMB;
    }

    if (r < 20) {
        return MOLE_GOLD;
    }

    return MOLE_NORMAL;
}

static void apply_mole_type_style(int idx)
{
    if (idx < 0 || idx >= 9) {
        return;
    }

    if (mole_types[idx] == MOLE_GOLD) {
        lv_obj_set_style_image_recolor(moles[idx],
                                       lv_color_hex(0xFFD700),
                                       0);
        lv_obj_set_style_image_recolor_opa(moles[idx],
                                           LV_OPA_80,
                                           0);
    } else if (mole_types[idx] == MOLE_BOMB) {
        lv_obj_set_style_image_recolor(moles[idx],
                                       lv_color_hex(0xFF0000),
                                       0);
        lv_obj_set_style_image_recolor_opa(moles[idx],
                                           LV_OPA_80,
                                           0);
    } else {
        lv_obj_set_style_image_recolor_opa(moles[idx],
                                           LV_OPA_0,
                                           0);
    }
}


static void update_combo_label(void)
{
    if (!combo_label)
        return;

    lv_label_set_text_fmt(combo_label,
                          "COMBO: %d",
                          combo_count);
}

static int get_combo_bonus(void)
{
    if (combo_count > 0 && combo_count % 10 == 0) {
        return 5;
    }

    if (combo_count > 0 && combo_count % 5 == 0) {
        return 2;
    }

    if (combo_count > 0 && combo_count % 3 == 0) {
        return 1;
    }

    return 0;
}

static void update_mode_label(void)
{
    if (!mode_label)
        return;

    lv_label_set_text_fmt(mode_label,
                          "MODE: %s",
                          media_wifi_is_versus_enabled() ? "VERSUS" : "SINGLE");
}

static void mode_btn_event_cb(lv_event_t* e)
{
    if (mole_timer || game_timer) {
        printf("[MODE] game is running, mode switch ignored\n");
        return;
    }

    media_wifi_set_versus_enabled(!media_wifi_is_versus_enabled());

    update_mode_label();
    update_level_label();

    printf("[MODE] switched to %s\n",
           media_wifi_is_versus_enabled() ? "VERSUS" : "SINGLE");
}

static void hide_mole_cb(lv_timer_t* timer);
static void update_mode_label(void);
static void mode_btn_event_cb(lv_event_t* e);
static volatile int k1_start_request = 0;
static pthread_t key_thread;

static void start_game(lv_event_t* e);
static void mole_click_event(lv_event_t* e);
static void update_game_timer(lv_timer_t* timer);
static void pop_random_mole(lv_timer_t* timer);
static void pointer_event_cb(lv_event_t* e);

static void update_peer_score(int new_score);
static void wifi_status_cb(const char* status);
static void media_remote_start_cb(void* user);
static void media_remote_finish_cb(void* user);
static void media_peer_score_cb(int score, void* user);
static void media_wifi_timer_cb(lv_timer_t* timer);
static void update_level_label(void)
{
    if (!level_label)
        return;

    lv_label_set_text_fmt(level_label,
                          "LEVEL: %d",
                          current_level);
}

static void apply_level_config(int level)
{
    if (level < 1)
        level = 1;

    if (level > LEVEL_COUNT)
        level = LEVEL_COUNT;

    current_level = level;
    current_level_config = level_configs[level - 1];

    update_level_label();

    printf("[LEVEL] level=%d\n",
           current_level);
}

static void check_level_up(void)
{
}


static void hide_mole_cb(lv_timer_t* timer)
{
    lv_obj_t* obj = (lv_obj_t*)lv_timer_get_user_data(timer);

    if (obj) {
        lv_obj_add_flag(obj, LV_OBJ_FLAG_HIDDEN);
    }

    lv_timer_delete(timer);
}

static void level_btn_event_cb(lv_event_t* e)
{
    if (mole_timer || game_timer) {
        printf("[LEVEL] game is running, level switch ignored\n");
        return;
    }

    current_level++;

    if (current_level > LEVEL_COUNT) {
        current_level = 1;
    }

    apply_level_config(current_level);

    printf("[LEVEL] selected level=%d refresh=%d show=%d count=%d speed=%d\n",
           current_level_config.level,
           current_level_config.refresh_ms,
           current_level_config.show_ms,
           current_level_config.mole_count,
           current_level_config.base_speed);
}


static void stats_btn_event_cb(lv_event_t* e)
{
    storage_data_t data;
    char text[256];
    int win_rate = 0;

    storage_get_data(&data);

    if (data.versus_games > 0) {
        win_rate = data.versus_wins * 100 / data.versus_games;
    }

    snprintf(text,
             sizeof(text),
             "Best Score: %d\n"
             "Best Combo: %d\n"
             "Total Games: %d\n\n"
             "Versus Games: %d\n"
             "Versus Wins: %d\n"
             "Versus Draws: %d\n"
             "Win Rate: %d%%",
             data.best_single_score,
             data.best_combo,
             data.total_games,
             data.versus_games,
             data.versus_wins,
             data.versus_draws,
             win_rate);

    lv_obj_t* box = lv_msgbox_create(lv_screen_active());
    lv_msgbox_add_title(box, "Statistics");
    lv_msgbox_add_text(box, text);
    lv_obj_set_size(box, 300, 210);
    lv_msgbox_add_close_button(box);

    storage_print_data();
}

static void wifi_status_cb(const char* status)
{
    if (wifi_status_label == NULL || status == NULL) {
        return;
    }

    lv_label_set_text(wifi_status_label, status);
}

static void media_remote_start_cb(void* user)
{
    (void)user;
    printf("[GAME] remote start accepted\n");
    start_game(NULL);
}

static void media_remote_finish_cb(void* user)
{
    (void)user;
    printf("[GAME] remote finish accepted\n");
    game_time = 1;
}

static void media_peer_score_cb(int score, void* user)
{
    (void)user;
    update_peer_score(score);
}

static void media_wifi_timer_cb(lv_timer_t* timer)
{
    (void)timer;
    media_wifi_timer_poll();
}

static void* led_task(void* arg);
static void* key_task(void* arg);
static void start_game_timer_cb(lv_timer_t* timer);
struct resource_s R;



static void* led_task(void* arg)
{
    int fd_led;

    fd_led = open("/dev/gpio0", O_RDWR);

    if (fd_led < 0) {
        return NULL;
    }

    while (1) {

        if (led_flash_request) {

            led_flash_request = 0;

            ioctl(fd_led, GPIOC_WRITE, 0);

            usleep(120 * 1000);

            ioctl(fd_led, GPIOC_WRITE, 1);
        }

        usleep(20 * 1000);
    }

    return NULL;
}



static void* key_task(void* arg)
{
    int fd_key;
    int value;
    int last = 0;

    fd_key = open("/dev/gpio1", O_RDWR);

    if (fd_key < 0) {
        return NULL;
    }

    while (1) {

        ioctl(fd_key,
              GPIOC_READ,
              (unsigned long)&value);

        if (value == 0 && last == 1) {

            start_game_request = 1;
        }

        last = value;

        usleep(50 * 1000);
    }

    return NULL;
}

static void start_game_timer_cb(lv_timer_t* timer)
{
    if (start_game_request) {

        start_game_request = 0;

        start_game(NULL);
    }
}

static void end_msg_event_cb(lv_event_t* e)
{
    lv_obj_t* btn = lv_event_get_target(e);
    lv_obj_t* footer = lv_obj_get_parent(btn);
    lv_obj_t* mbox = lv_obj_get_parent(footer);
    lv_obj_delete(mbox);

    const char* txt = (const char*)lv_event_get_user_data(e);
    if (strcmp(txt, "Again") == 0) {
        start_game(NULL);
    }
}

static bool init_resource(void)
{
    R.fonts.size_14.normal = lv_freetype_font_create(
        FONTS_ROOT "/MiSans-Normal.ttf", LV_FREETYPE_FONT_RENDER_MODE_BITMAP, 14,
        LV_FREETYPE_FONT_STYLE_NORMAL);

    R.fonts.size_22.bold = lv_freetype_font_create(
        FONTS_ROOT "/MiSans-Normal.ttf", LV_FREETYPE_FONT_RENDER_MODE_BITMAP, 22,
        LV_FREETYPE_FONT_STYLE_NORMAL);

    if (R.fonts.size_14.normal == NULL || R.fonts.size_22.bold == NULL) {
        return false;
    }

    lv_style_init(&R.styles.button_default);
    lv_style_init(&R.styles.button_pressed);
    lv_style_set_opa(&R.styles.button_default, LV_OPA_COVER);
    lv_style_set_opa(&R.styles.button_pressed, LV_OPA_70);

    return true;
}

void init_whack_a_mole_game(lv_obj_t* parent)
{
    srand(time(NULL));

    R.images.hammer = ICONS_ROOT "/hammer.bin";
    R.images.mole = ICONS_ROOT "/mole.bin";
    R.images.grassland = ICONS_ROOT "/grassland.bin";

    game_screen = lv_image_create(parent);
    lv_image_set_src(game_screen, R.images.grassland);
    lv_obj_set_align(game_screen, LV_ALIGN_CENTER);
    lv_obj_set_size(game_screen, LV_PCT(100), LV_PCT(100));
    lv_obj_align(game_screen, LV_ALIGN_CENTER, 0, 0);

    lv_obj_remove_flag(game_screen, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_remove_flag(game_screen, LV_OBJ_FLAG_CLICKABLE);
    lv_obj_remove_flag(game_screen, LV_OBJ_FLAG_SCROLL_ELASTIC);
    lv_obj_remove_flag(game_screen, LV_OBJ_FLAG_SCROLL_MOMENTUM);
    lv_obj_move_background(game_screen);
    lv_obj_move_to_index(game_screen, 0);

    lv_obj_add_event_cb(game_screen, pointer_event_cb, LV_EVENT_PRESSED, NULL);
    lv_obj_add_event_cb(game_screen, pointer_event_cb, LV_EVENT_PRESSING, NULL);

    static const lv_style_prop_t props[] = { LV_STYLE_TRANSFORM_ROTATION, 0 };
    static lv_style_transition_dsc_t trans_pr;
    lv_style_transition_dsc_init(&trans_pr, props, lv_anim_path_linear, 150, 0, NULL);

    hammer_cursor = lv_image_create(game_screen);
    lv_image_set_src(hammer_cursor, R.images.hammer);
    lv_obj_add_flag(hammer_cursor, LV_OBJ_FLAG_HIDDEN);
//    lv_obj_set_style_image_recolor(hammer_cursor, lv_color_black(), 0);
//    lv_obj_set_style_image_recolor_opa(hammer_cursor, LV_OPA_30, 0);
//    lv_obj_set_style_transform_scale_x(hammer_cursor, 60, 0);
//    lv_obj_set_style_transform_scale_y(hammer_cursor, 60, 0);
//    lv_obj_set_style_transform_rotation(hammer_cursor, 0, LV_STATE_DEFAULT);
//    lv_obj_set_style_transform_rotation(hammer_cursor, 300, LV_STATE_PRESSED);
//    lv_obj_set_style_transition(hammer_cursor, &trans_pr, LV_STATE_DEFAULT);
//    lv_obj_set_style_transition(hammer_cursor, &trans_pr, LV_STATE_PRESSED);
//    lv_obj_add_flag(hammer_cursor, LV_OBJ_FLAG_CLICKABLE);
//    lv_obj_remove_flag(hammer_cursor, LV_OBJ_FLAG_IGNORE_LAYOUT);

    lv_obj_t* title = lv_label_create(game_screen);
    lv_label_set_text(title, "Whackmole");
    lv_obj_set_style_text_font(title, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(title, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(title, LV_ALIGN_TOP_MID);
    lv_obj_set_pos(title, 0, 4);

    score_label = lv_label_create(game_screen);
    lv_label_set_text(score_label, "VERSUS");
    lv_obj_set_style_text_font(score_label, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(score_label, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(score_label, LV_ALIGN_TOP_MID);
    lv_obj_set_pos(score_label, 0, 30);

    score_a_label = lv_label_create(game_screen);
    lv_label_set_text(score_a_label, "P1: 0");
    lv_obj_set_style_text_font(score_a_label, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(score_a_label, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(score_a_label, LV_ALIGN_TOP_LEFT);
    lv_obj_set_pos(score_a_label, 8, 4);

    score_b_label = lv_label_create(game_screen);
    lv_label_set_text(score_b_label, "P2: 0");
    lv_obj_set_style_text_font(score_b_label, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(score_b_label, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(score_b_label, LV_ALIGN_TOP_RIGHT);
    lv_obj_set_pos(score_b_label, -8, 4);

    time_label = lv_label_create(game_screen);
    lv_label_set_text_fmt(time_label, "time: %d", game_time);
    lv_obj_set_style_text_font(time_label, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(time_label, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(time_label, LV_ALIGN_TOP_RIGHT);
    lv_obj_set_pos(time_label, -8, 34);

    level_label = lv_label_create(game_screen);
    lv_label_set_text_fmt(level_label, "LEVEL: %d", current_level);
    lv_obj_set_style_text_font(level_label, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(level_label, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(level_label, LV_ALIGN_TOP_MID);
    lv_obj_set_pos(level_label, 0, 58);

    mode_label = lv_label_create(game_screen);
    lv_label_set_text_fmt(mode_label,
                          "MODE: %s",
                          media_wifi_is_versus_enabled() ? "VERSUS" : "SINGLE");
    lv_obj_set_style_text_font(mode_label, R.fonts.size_14.normal, 0);
    lv_obj_set_style_text_color(mode_label, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(mode_label, LV_ALIGN_TOP_LEFT);
    lv_obj_set_pos(mode_label, 8, 34);

    combo_label = lv_label_create(game_screen);
    lv_label_set_text_fmt(combo_label, "COMBO: %d", combo_count);
    lv_obj_set_style_text_font(combo_label, R.fonts.size_14.normal, 0);
    lv_obj_set_style_text_color(combo_label, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_align(combo_label, LV_ALIGN_TOP_LEFT);
    lv_obj_set_pos(combo_label, 8, 58);

    for (int i = 0; i < 9; i++) {
        lv_obj_t* hole = lv_obj_create(game_screen);
        lv_obj_set_size(hole, 80, 60);
        lv_obj_set_pos(hole, hole_positions[i].x - 12, hole_positions[i].y + 2);
        lv_obj_set_style_bg_color(hole, lv_color_hex(0x000000), 0);
        lv_obj_set_style_radius(hole, 10, 0);
        lv_obj_set_style_border_width(hole, 0, 0);
        lv_obj_set_style_shadow_width(hole, 0, 0);
        lv_obj_set_style_shadow_color(hole, lv_color_hex(0x000000), 0);
        lv_obj_set_style_shadow_opa(hole, LV_OPA_30, 0);
        lv_obj_set_style_bg_opa(hole, LV_OPA_TRANSP, 0);
        lv_obj_move_background(hole);
        lv_obj_move_to_index(hole, 0);

        moles[i] = lv_image_create(hole);
        lv_image_set_src(moles[i], R.images.mole);
        lv_obj_set_align(moles[i], LV_ALIGN_CENTER);
        lv_obj_set_style_image_recolor(moles[i], lv_color_black(), 0);
        lv_obj_set_style_image_recolor_opa(moles[i], LV_OPA_30, 0);
        lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);
        lv_obj_set_style_image_opa(moles[i], LV_OPA_COVER, 0);
        lv_obj_set_style_image_recolor_opa(moles[i], LV_OPA_0, 0);
        lv_obj_set_style_transform_scale(moles[i], 200, 0);
        lv_obj_add_flag(moles[i], LV_OBJ_FLAG_CLICKABLE);
        lv_obj_set_style_image_recolor_opa(moles[i], 0, 0);
        lv_obj_move_foreground(moles[i]);

        lv_obj_add_event_cb(moles[i], mole_click_event, LV_EVENT_PRESSED, NULL);
        lv_obj_add_event_cb(moles[i], pointer_event_cb, LV_EVENT_PRESSED, NULL);
        lv_obj_add_event_cb(moles[i], pointer_event_cb, LV_EVENT_PRESSING, NULL);
        lv_obj_add_event_cb(moles[i], pointer_event_cb, LV_EVENT_RELEASED, NULL);

        hit_boxes[i] = lv_obj_create(game_screen);
        lv_obj_set_size(hit_boxes[i], 90, 70);
        lv_obj_set_pos(hit_boxes[i], hole_positions[i].x - 18, hole_positions[i].y - 8);
        lv_obj_set_style_bg_opa(hit_boxes[i], LV_OPA_70, 0);
        lv_obj_set_style_bg_color(hit_boxes[i], lv_color_hex(0x00FF00), 0);
        lv_obj_set_style_border_width(hit_boxes[i], 3, 0);
        lv_obj_set_style_border_color(hit_boxes[i], lv_color_hex(0xFFFFFF), 0);
        lv_obj_add_flag(hit_boxes[i], LV_OBJ_FLAG_HIDDEN);
        lv_obj_move_foreground(hit_boxes[i]);
    }

    lv_obj_t* start_btn = lv_btn_create(game_screen);
    lv_obj_set_size(start_btn, 90, 30);
    lv_obj_set_align(start_btn, LV_ALIGN_BOTTOM_MID);
    lv_obj_set_pos(start_btn, 0, -8);
    lv_obj_add_event_cb(start_btn, start_game, LV_EVENT_CLICKED, NULL);
    lv_obj_set_style_bg_color(start_btn, lv_color_hex(0x228B22), 0);

    lv_obj_t* btn_label = lv_label_create(start_btn);
    lv_label_set_text(btn_label, "START");
    lv_obj_set_style_text_font(start_btn, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(start_btn, lv_color_hex(0xFFFFFF), 0);
    lv_obj_center(btn_label);

    lv_obj_t* level_btn = lv_btn_create(game_screen);
    lv_obj_set_size(level_btn, 90, 30);
    lv_obj_set_align(level_btn, LV_ALIGN_BOTTOM_LEFT);
    lv_obj_set_pos(level_btn, 8, -8);
    lv_obj_add_event_cb(level_btn, level_btn_event_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_set_style_bg_color(level_btn, lv_color_hex(0x4169E1), 0);

    lv_obj_t* level_btn_label = lv_label_create(level_btn);
    lv_label_set_text(level_btn_label, "LEVEL");
    lv_obj_set_style_text_font(level_btn, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(level_btn, lv_color_hex(0xFFFFFF), 0);
    lv_obj_center(level_btn_label);

    lv_obj_t* mode_btn = lv_btn_create(game_screen);
    lv_obj_set_size(mode_btn, 90, 30);
    lv_obj_set_align(mode_btn, LV_ALIGN_BOTTOM_RIGHT);
    lv_obj_set_pos(mode_btn, -8, -8);
    lv_obj_add_event_cb(mode_btn, mode_btn_event_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_set_style_bg_color(mode_btn, lv_color_hex(0x8B4513), 0);

    lv_obj_t* mode_btn_label = lv_label_create(mode_btn);
    lv_label_set_text(mode_btn_label, "MODE");
    lv_obj_set_style_text_font(mode_btn, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(mode_btn, lv_color_hex(0xFFFFFF), 0);
    lv_obj_center(mode_btn_label);

    lv_obj_t* stats_btn = lv_btn_create(game_screen);
    lv_obj_set_size(stats_btn, 80, 26);
    lv_obj_set_align(stats_btn, LV_ALIGN_TOP_RIGHT);
    lv_obj_set_pos(stats_btn, -8, 62);
    lv_obj_add_event_cb(stats_btn, stats_btn_event_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_set_style_bg_color(stats_btn, lv_color_hex(0x555555), 0);

    lv_obj_t* stats_btn_label = lv_label_create(stats_btn);
    lv_label_set_text(stats_btn_label, "STATS");
    lv_obj_set_style_text_font(stats_btn, R.fonts.size_14.normal, 0);
    lv_obj_set_style_text_color(stats_btn, lv_color_hex(0xFFFFFF), 0);
    lv_obj_center(stats_btn_label);



    
    lv_obj_t* wifi_btn = lv_btn_create(game_screen);
    lv_obj_set_size(wifi_btn, 70, 26);
    lv_obj_set_align(wifi_btn, LV_ALIGN_TOP_LEFT);
    lv_obj_set_pos(wifi_btn, 8, 86);
    lv_obj_add_event_cb(wifi_btn, media_wifi_ui_show, LV_EVENT_CLICKED, NULL);
    lv_obj_set_style_bg_color(wifi_btn, lv_color_hex(0x0066CC), 0);

    lv_obj_t* wifi_btn_label = lv_label_create(wifi_btn);
    lv_label_set_text(wifi_btn_label, "WIFI");
    lv_obj_set_style_text_font(wifi_btn, R.fonts.size_14.normal, 0);
    lv_obj_set_style_text_color(wifi_btn, lv_color_hex(0xFFFFFF), 0);
    lv_obj_center(wifi_btn_label);

    wifi_status_label = lv_label_create(game_screen);
    lv_label_set_text(wifi_status_label, "WiFi: idle");
    lv_obj_set_style_text_font(wifi_status_label, R.fonts.size_14.normal, 0);
    lv_obj_set_style_text_color(wifi_status_label, lv_color_hex(0xCCCCCC), 0);
    lv_obj_set_align(wifi_status_label, LV_ALIGN_TOP_LEFT);
    lv_obj_set_pos(wifi_status_label, 8, 116);

    lv_obj_move_foreground(hammer_cursor);
    lv_obj_move_foreground(start_btn);
    lv_obj_move_foreground(score_label);
    lv_obj_move_foreground(time_label);
    lv_obj_move_foreground(level_label);
    lv_obj_move_foreground(mode_label);
    lv_obj_move_foreground(combo_label);
    lv_obj_move_foreground(title);
}

static void pointer_event_cb(lv_event_t* e)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_point_t pos;
    lv_indev_t* indev = lv_indev_active();

    if (indev == NULL) {
        return;
    }

    lv_indev_get_point(indev, &pos);
    lv_obj_remove_flag(hammer_cursor, LV_OBJ_FLAG_HIDDEN);
    lv_obj_set_pos(hammer_cursor, pos.x - 10, pos.y - 10);

    if (code == LV_EVENT_PRESSED) {
        lv_obj_set_state(hammer_cursor, LV_STATE_PRESSED, true);
    } else if (code == LV_EVENT_PRESSING) {
    } else {
        lv_obj_set_state(hammer_cursor, LV_STATE_PRESSED, false);
    }
}

static void start_game(lv_event_t* e)
{
    score = 0;
    score_a = 0;
    score_b = 0;
    game_time = GAME_TIME;
    combo_count = 0;
    update_combo_label();

    if (!media_wifi_is_versus_enabled()) {
        apply_level_config(current_level);
    } else {
        update_level_label();
        update_mode_label();
    }

    if (media_wifi_is_versus_enabled() && e != NULL) {
        media_wifi_versus_send_start(media_wifi_get_tick_ms(), GAME_TIME);
    }

    lv_label_set_text_fmt(score_a_label, "P1: %d", score_a);
    lv_label_set_text_fmt(score_b_label, "P2: %d", score_b);
    lv_label_set_text_fmt(time_label, "time: %d", game_time);

    lv_obj_set_style_text_font(game_screen, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(game_screen, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_style_text_font(game_screen, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(game_screen, lv_color_hex(0xFFFFFF), 0);

    for (int i = 0; i < 9; i++) {
        lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);
        mole_types[i] = MOLE_NORMAL;
        apply_mole_type_style(i);
    }

    if (game_timer) {

        lv_timer_delete(game_timer);
        game_timer = NULL;
    }
    game_timer = lv_timer_create(update_game_timer, 1000, NULL);

    if (mole_timer) {
        lv_timer_delete(mole_timer);
        mole_timer = NULL;
    }
    if (media_wifi_is_versus_enabled()) {
        mole_timer = lv_timer_create(pop_random_mole, 1000, NULL);
    } else {
        mole_timer = lv_timer_create(pop_random_mole,
                                     current_level_config.refresh_ms,
                                     NULL);
    }
}

static void pop_random_mole(lv_timer_t* timer)
{
    for (int i = 0; i < 9; i++) {
        lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);
    }

    if (media_wifi_is_versus_enabled()) {
        int show_count = rand() % 2 + 1;

        for (int i = 0; i < show_count; i++) {
            int mole_idx = rand() % 9;
            lv_obj_remove_flag(moles[mole_idx], LV_OBJ_FLAG_HIDDEN);
        }

        if (game_time < 40) {
            lv_timer_set_period(timer, 800);
        }

        if (game_time < 20) {
            lv_timer_set_period(timer, 600);
        }

        return;
    }

    int used[9] = {0};
    int show_count = current_level_config.mole_count;

    if (show_count > 9) {
        show_count = 9;
    }

    for (int i = 0; i < show_count; i++) {
        int mole_idx = rand() % 9;
        int guard = 0;

        while (used[mole_idx] && guard < 20) {
            mole_idx = rand() % 9;
            guard++;
        }

        used[mole_idx] = 1;

        mole_types[mole_idx] = random_mole_type();
        apply_mole_type_style(mole_idx);

        lv_obj_remove_flag(moles[mole_idx], LV_OBJ_FLAG_HIDDEN);

        lv_timer_t* hide_timer = lv_timer_create(hide_mole_cb,
                                                 current_level_config.show_ms,
                                                 moles[mole_idx]);
        lv_timer_set_repeat_count(hide_timer, 1);
    }

    lv_timer_set_period(timer, current_level_config.refresh_ms);
}

static void update_game_timer(lv_timer_t* timer)
{
    game_time--;
    lv_label_set_text_fmt(time_label, "time: %d", game_time);

    if (game_time <= 0) {
        if (media_wifi_is_versus_enabled() && !media_wifi_versus_finish_from_peer()) {
            uint8_t result = 2;

            if (score_a > score_b) {
                result = 1;
            } else if (score_b > score_a) {
                result = 0;
            }

            media_wifi_versus_send_finish(media_wifi_get_tick_ms(), result);
        }

        media_wifi_versus_clear_finish_flag();

        lv_timer_delete(game_timer);
        game_timer = NULL;

        if (mole_timer) {
            lv_timer_delete(mole_timer);
            mole_timer = NULL;
        }

        for (int i = 0; i < 9; i++) {
            lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);
        }

        storage_update_result(media_wifi_is_versus_enabled(),
                              score_a,
                              score_b,
                              current_level,
                              combo_count);

        lv_obj_t* end_msg = lv_msgbox_create(lv_screen_active());
        lv_msgbox_add_title(end_msg, "Game Over!");

        char result_text[128];

        if (score_a > score_b) {
            snprintf(result_text,
                     sizeof(result_text),
                     "P1: %d\nP2: %d\nP1 Wins!",
                     score_a,
                     score_b);
        } else if (score_b > score_a) {
            snprintf(result_text,
                     sizeof(result_text),
                     "P1: %d\nP2: %d\nP2 Wins!",
                     score_a,
                     score_b);
        } else {
            snprintf(result_text,
                     sizeof(result_text),
                     "P1: %d\nP2: %d\nDraw!",
                     score_a,
                     score_b);
        }

        lv_msgbox_add_text(end_msg, result_text);
        lv_obj_set_size(end_msg, 300, 120);
        lv_msgbox_add_close_button(end_msg);

        const char* btns[] = { "Again", "Close", NULL };

        for (int i = 0; btns[i]; i++) {
            lv_obj_t* btn = lv_msgbox_add_footer_button(end_msg, btns[i]);
            lv_obj_set_style_text_font(btn, R.fonts.size_14.normal, 0);
            lv_obj_add_event_cb(btn, end_msg_event_cb, LV_EVENT_CLICKED, (void*)btns[i]);
        }

        return;
    }
}



static void update_peer_score(int new_score)
{
    score_b = new_score;

    lv_label_set_text_fmt(score_b_label,
                          "P2: %d",
                          score_b);
}

static void notify_local_score_changed(void)
{
    media_wifi_versus_send_score(media_wifi_get_tick_ms(), score_a);
}



static void hide_hitbox_cb(lv_timer_t* timer)
{
    lv_obj_t* obj = (lv_obj_t*)lv_timer_get_user_data(timer);

    lv_obj_add_flag(obj, LV_OBJ_FLAG_HIDDEN);

    lv_timer_delete(timer);
}

static void mole_click_event(lv_event_t* e)
{
    lv_obj_t* mole = lv_event_get_target(e);

    if (!lv_obj_has_flag(mole, LV_OBJ_FLAG_HIDDEN)) {
        for (int i = 0; i < 9; i++) {
            if (mole == moles[i]) {
                if (!media_wifi_is_versus_enabled()) {
                    if (mole_types[i] == MOLE_GOLD) {
                        int bonus;

                        combo_count++;
                        bonus = get_combo_bonus();

                        score_a += 5 + bonus;

                        lv_obj_set_style_bg_color(hit_boxes[i],
                                                  lv_color_hex(0xFFD700),
                                                  0);

                        printf("[SPECIAL] GOLD mole hit +5 combo=%d bonus=%d\n",
                               combo_count,
                               bonus);
                    } else if (mole_types[i] == MOLE_BOMB) {
                        combo_count = 0;
                        score_a -= 2;

                        if (score_a < 0) {
                            score_a = 0;
                        }

                        lv_obj_set_style_bg_color(hit_boxes[i],
                                                  lv_color_hex(0xFF0000),
                                                  0);
                        printf("[SPECIAL] BOMB mole hit -2 combo reset\n");
                    } else {
                        int bonus;

                        combo_count++;
                        bonus = get_combo_bonus();

                        score_a += 1 + bonus;

                        lv_obj_set_style_bg_color(hit_boxes[i],
                                                  lv_color_hex(0x00FF00),
                                                  0);

                        printf("[SPECIAL] NORMAL mole hit +1 combo=%d bonus=%d\n",
                               combo_count,
                               bonus);
                    }

                    update_combo_label();
                } else {
                    score_a++;
                    lv_obj_set_style_bg_color(hit_boxes[i],
                                              lv_color_hex(0x00FF00),
                                              0);
                    notify_local_score_changed();
                }

                lv_label_set_text_fmt(score_a_label, "P1: %d", score_a);
                lv_label_set_text_fmt(score_b_label, "P2: %d", score_b);

                lv_obj_add_flag(mole, LV_OBJ_FLAG_HIDDEN);
                mole_types[i] = MOLE_NORMAL;
                apply_mole_type_style(i);

                lv_obj_remove_flag(hit_boxes[i], LV_OBJ_FLAG_HIDDEN);

                lv_timer_t* t = lv_timer_create(hide_hitbox_cb, 300, hit_boxes[i]);
                lv_timer_set_repeat_count(t, 1);

                media_wifi_sound_play(MEDIA_SOUND_HIT);
                led_flash_request = 1;

                break;
            }
        }
    }
}



void app_create(void)
{

    lv_obj_t* scr = lv_screen_active();
    media_wifi_game_cb_t media_cb = {
        .on_remote_start = media_remote_start_cb,
        .on_remote_finish = media_remote_finish_cb,
        .on_peer_score = media_peer_score_cb,
        .user = NULL,
    };

    if (!init_resource()) {
        return;
    }

    storage_init();

    media_wifi_set_status_callback(wifi_status_cb);
    media_wifi_init(&media_cb);
    init_whack_a_mole_game(scr);

    pthread_create(&led_thread,
                   NULL,
                   led_task,
                   NULL);


    pthread_create(&key_thread,
                   NULL,
                   key_task,
                   NULL);

    lv_timer_create(media_wifi_timer_cb,
                    50,
                    NULL);

    lv_timer_create(start_game_timer_cb,
                    100,
                    NULL);

    /* K1 thread disabled temporarily */
    /* K1 timer disabled temporarily */

}

