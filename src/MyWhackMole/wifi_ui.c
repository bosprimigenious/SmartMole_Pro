#include "wifi_ui.h"

#include <stdio.h>
#include <stdlib.h>
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
    char cmd[256];

    if (!ssid || strlen(ssid) == 0) {
        lv_label_set_text(status_label, "SSID is empty");
        return;
    }

    lv_label_set_text(status_label, "Connecting...");
    printf("[WIFI_UI] connect ssid=%s\n", ssid);

    system("ifup wlan0");
    system("wapi mode wlan0 2");

    if (pwd && strlen(pwd) > 0) {
        snprintf(cmd, sizeof(cmd), "wapi psk wlan0 \"%s\" 3", pwd);
        system(cmd);
    }

    snprintf(cmd, sizeof(cmd), "wapi essid wlan0 \"%s\" 1", ssid);
    system(cmd);

    system("renew wlan0");
    system("ifconfig");

    lv_label_set_text(status_label, "Done. Check IP on serial.");
    printf("[WIFI_UI] connect command finished\n");
}

static void wifi_scan_cb(lv_event_t* e)
{
    lv_label_set_text(status_label, "Scanning...");
    system("wapi scan wlan0");
    system("wapi scan_results wlan0 > /data/wifi_scan.txt");
    lv_label_set_text(status_label, "Scan saved: /data/wifi_scan.txt");
    printf("[WIFI_UI] scan result saved to /data/wifi_scan.txt\n");
}

void wifi_ui_show(lv_obj_t* parent)
{
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
