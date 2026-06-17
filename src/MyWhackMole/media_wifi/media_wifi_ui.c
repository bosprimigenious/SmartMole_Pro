#include "media_wifi.h"

#include <stdio.h>
#include <string.h>
#include <lvgl/lvgl.h>

static lv_obj_t* ssid_ta;
static lv_obj_t* pwd_ta;
static lv_obj_t* status_label;
static lv_obj_t* kb;

static void ta_event_cb(lv_event_t* e)
{
    lv_obj_t* ta = lv_event_get_target(e);
    lv_keyboard_set_textarea(kb, ta);
}

static void wifi_connect_cb(lv_event_t* e)
{
    const char* ssid = lv_textarea_get_text(ssid_ta);
    const char* pwd = lv_textarea_get_text(pwd_ta);

    (void)e;

    lv_label_set_text(status_label, "Connecting...");
    media_wifi_connect(ssid, pwd);
    lv_label_set_text(status_label, media_wifi_get_last_status());
}

static void wifi_scan_cb(lv_event_t* e)
{
    char names[16][32];
    int count;
    int i;

    (void)e;

    count = media_wifi_scan_ap_names(names, 16);
    lv_label_set_text(status_label, media_wifi_get_last_status());
    if (count > 0 && ssid_ta != NULL) {
        lv_textarea_set_text(ssid_ta, names[0]);
        for (i = 1; i < count && i < 4; i++) {
            printf("[MEDIA_WIFI_UI] ap[%d]=%s\n", i, names[i]);
        }
    }
}

void media_wifi_ui_show(lv_obj_t* parent)
{
    (void)parent;

    lv_obj_t* box = lv_msgbox_create(lv_screen_active());
    lv_msgbox_add_title(box, "WiFi Connect");
    lv_obj_set_size(box, 360, 300);

    lv_obj_t* cont = lv_obj_create(box);
    lv_obj_set_size(cont, 330, 230);
    lv_obj_set_style_bg_opa(cont, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(cont, 0, 0);

    lv_obj_t* ssid_label = lv_label_create(cont);
    lv_label_set_text(ssid_label, "SSID:");
    lv_obj_set_pos(ssid_label, 5, 5);

    ssid_ta = lv_textarea_create(cont);
    lv_obj_set_size(ssid_ta, 220, 32);
    lv_obj_set_pos(ssid_ta, 70, 0);
    lv_textarea_set_one_line(ssid_ta, true);
    lv_obj_add_event_cb(ssid_ta, ta_event_cb, LV_EVENT_FOCUSED, NULL);

    lv_obj_t* pwd_label = lv_label_create(cont);
    lv_label_set_text(pwd_label, "PWD:");
    lv_obj_set_pos(pwd_label, 5, 42);

    pwd_ta = lv_textarea_create(cont);
    lv_obj_set_size(pwd_ta, 220, 32);
    lv_obj_set_pos(pwd_ta, 70, 38);
    lv_textarea_set_one_line(pwd_ta, true);
    lv_textarea_set_password_mode(pwd_ta, true);
    lv_obj_add_event_cb(pwd_ta, ta_event_cb, LV_EVENT_FOCUSED, NULL);

    lv_obj_t* scan_btn = lv_btn_create(cont);
    lv_obj_set_size(scan_btn, 90, 30);
    lv_obj_set_pos(scan_btn, 5, 80);
    lv_obj_add_event_cb(scan_btn, wifi_scan_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_t* scan_label = lv_label_create(scan_btn);
    lv_label_set_text(scan_label, "SCAN");
    lv_obj_center(scan_label);

    lv_obj_t* conn_btn = lv_btn_create(cont);
    lv_obj_set_size(conn_btn, 120, 30);
    lv_obj_set_pos(conn_btn, 110, 80);
    lv_obj_add_event_cb(conn_btn, wifi_connect_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_t* conn_label = lv_label_create(conn_btn);
    lv_label_set_text(conn_label, "CONNECT");
    lv_obj_center(conn_label);

    status_label = lv_label_create(cont);
    lv_label_set_text(status_label, "Input SSID/PWD");
    lv_obj_set_pos(status_label, 5, 118);

    kb = lv_keyboard_create(cont);
    lv_obj_set_size(kb, 320, 90);
    lv_obj_set_pos(kb, 0, 140);
    lv_keyboard_set_textarea(kb, ssid_ta);

    lv_msgbox_add_close_button(box);
}
