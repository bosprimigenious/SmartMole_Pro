#include "MyWhackMole.h"
#include "src/display/lv_display.h"
#include "src/font/lv_font.h"
#include "versus/versus_protocol.h"
#include "versus/versus_wifi_transport.h"
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
#include <time.h>

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

static int score = 0;
static int score_a = 0;
static int score_b = 0;
static versus_ctx_t versus;
static versus_wifi_transport_t wifi;
static int versus_enabled = 0;
static int game_time = GAME_TIME;
static lv_timer_t* game_timer = NULL;
static lv_timer_t* mole_timer = NULL;

static volatile int play_sound_request = 0;
static volatile int led_flash_request = 0;
static volatile int start_game_request = 0;

static pthread_t sound_thread;
static pthread_t led_thread;

static volatile int k1_start_request = 0;
static pthread_t key_thread;

static void start_game(lv_event_t* e);
static void mole_click_event(lv_event_t* e);
static void update_game_timer(lv_timer_t* timer);
static void pop_random_mole(lv_timer_t* timer);
static void pointer_event_cb(lv_event_t* e);
static void update_peer_score(int new_score);
static void peer_test_event_cb(lv_event_t* e);
static void notify_local_score_changed(void);


static void versus_init_if_enabled(void);
static uint32_t get_tick_ms(void);

static void* sound_task(void* arg);
static void* led_task(void* arg);
static void* key_task(void* arg);
static void start_game_timer_cb(lv_timer_t* timer);
struct resource_s R;
static void* sound_task(void* arg)
{
    while (1) {

        if (play_sound_request) {

            play_sound_request = 0;


            system("aplay -D hw:audiocodec /data/res/hit.wav");
        }

        usleep(50 * 1000);
    }

    return NULL;
}



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

        lv_obj_add_event_cb(moles[i], mole_click_event, LV_EVENT_CLICKED, NULL);
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


    lv_obj_t* peer_btn = lv_btn_create(game_screen);
    lv_obj_set_size(peer_btn, 70, 30);
    lv_obj_set_align(peer_btn, LV_ALIGN_BOTTOM_RIGHT);
    lv_obj_set_pos(peer_btn, -8, -8);
    lv_obj_add_event_cb(peer_btn, peer_test_event_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_set_style_bg_color(peer_btn, lv_color_hex(0x8B0000), 0);

    lv_obj_t* peer_label = lv_label_create(peer_btn);
    lv_label_set_text(peer_label, "P2+1");
    lv_obj_set_style_text_font(peer_btn, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(peer_btn, lv_color_hex(0xFFFFFF), 0);
    lv_obj_center(peer_label);

    lv_obj_move_foreground(hammer_cursor);
    lv_obj_move_foreground(start_btn);
    lv_obj_move_foreground(score_label);
    lv_obj_move_foreground(time_label);
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

    lv_label_set_text_fmt(score_a_label, "P1: %d", score_a);
    lv_label_set_text_fmt(score_b_label, "P2: %d", score_b);
    lv_label_set_text_fmt(time_label, "time: %d", game_time);

    lv_obj_set_style_text_font(game_screen, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(game_screen, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_style_text_font(game_screen, R.fonts.size_22.bold, 0);
    lv_obj_set_style_text_color(game_screen, lv_color_hex(0xFFFFFF), 0);

    for (int i = 0; i < 9; i++) {
        lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);
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
    mole_timer = lv_timer_create(pop_random_mole, 1000, NULL);
}

static void pop_random_mole(lv_timer_t* timer)
{
    for (int i = 0; i < 9; i++) {
        lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);
    }

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
}

static void update_game_timer(lv_timer_t* timer)
{
    game_time--;
    lv_label_set_text_fmt(time_label, "time: %d", game_time);

    if (game_time <= 0) {
        lv_timer_delete(game_timer);
        game_timer = NULL;

        if (mole_timer) {
            lv_timer_delete(mole_timer);
            mole_timer = NULL;
        }

        for (int i = 0; i < 9; i++) {
            lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);
        }

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
    if (!versus_enabled) {
        return;
    }

    versus_send_score(&versus,
                      get_tick_ms(),
                      score_a,
                      0);
}


static void peer_test_event_cb(lv_event_t* e)
{
    update_peer_score(score_b + 1);
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
        score_a++;
        lv_label_set_text_fmt(score_a_label, "P1: %d", score_a);
        lv_label_set_text_fmt(score_b_label, "P2: %d", score_b);
        notify_local_score_changed();
        lv_obj_add_flag(mole, LV_OBJ_FLAG_HIDDEN);

        for (int i = 0; i < 9; i++) {
            if (mole == moles[i]) {
                lv_obj_remove_flag(hit_boxes[i], LV_OBJ_FLAG_HIDDEN);

                lv_timer_t* t = lv_timer_create(hide_hitbox_cb, 300, hit_boxes[i]);
                lv_timer_set_repeat_count(t, 1);

                play_sound_request = 1;
                led_flash_request = 1;

                break;
            }
        }
    }
}



static uint32_t get_tick_ms(void)
{
    struct timespec ts;

    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }

    return (uint32_t)(ts.tv_sec * 1000u + ts.tv_nsec / 1000000u);
}

static void versus_init_if_enabled(void)
{
    if (!versus_enabled) {
        return;
    }

    /*
     * Wi-Fi 联机初始化预留：
     * 后续在这里配置本机ID、对方IP、本机端口、对方端口。
     */
}

void app_create(void)
{

    lv_obj_t* scr = lv_screen_active();

    if (!init_resource()) {
        return;
    }


    versus_init_if_enabled();
    init_whack_a_mole_game(scr);

    pthread_create(&sound_thread,
                   NULL,
                   sound_task,
                   NULL);

    pthread_create(&led_thread,
                   NULL,
                   led_task,
                   NULL);

    pthread_t key_thread;

    pthread_create(&key_thread,
                   NULL,
                   key_task,
                   NULL);

    lv_timer_create(start_game_timer_cb,
                    100,
                    NULL);

    /* K1 thread disabled temporarily */
    /* K1 timer disabled temporarily */

}

