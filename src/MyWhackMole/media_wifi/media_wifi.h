#ifndef MEDIA_WIFI_H
#define MEDIA_WIFI_H

#include <stdint.h>

#include <lvgl/lvgl.h>

typedef enum {
    MEDIA_SOUND_NONE = 0,
    MEDIA_SOUND_HIT,
    MEDIA_SOUND_START,
} media_sound_id_t;

typedef void (*media_wifi_status_cb_t)(const char* status);

typedef void (*media_wifi_remote_start_cb_t)(void* user);
typedef void (*media_wifi_remote_finish_cb_t)(void* user);
typedef void (*media_wifi_peer_score_cb_t)(int score, void* user);

typedef struct {
    media_wifi_remote_start_cb_t on_remote_start;
    media_wifi_remote_finish_cb_t on_remote_finish;
    media_wifi_peer_score_cb_t on_peer_score;
    void* user;
} media_wifi_game_cb_t;

void media_wifi_init(const media_wifi_game_cb_t* game_cb);
void media_wifi_sound_play(media_sound_id_t id);

void media_wifi_set_status_callback(media_wifi_status_cb_t cb);
int media_wifi_connect(const char* ssid, const char* password);
int media_wifi_scan_ap_names(char names[][32], int max_count);
int media_wifi_save_config(const char* ssid, const char* password);
void media_wifi_ui_show(lv_obj_t* parent);

int media_wifi_is_versus_enabled(void);
void media_wifi_set_versus_enabled(int enabled);
int media_wifi_versus_finish_from_peer(void);
void media_wifi_versus_clear_finish_flag(void);

void media_wifi_versus_send_start(uint32_t tick_ms, uint16_t duration_s);
void media_wifi_versus_send_score(uint32_t tick_ms, int16_t score);
void media_wifi_versus_send_finish(uint32_t tick_ms, uint8_t result);

void media_wifi_timer_poll(void);
uint32_t media_wifi_get_tick_ms(void);
const char* media_wifi_get_last_status(void);

#endif
