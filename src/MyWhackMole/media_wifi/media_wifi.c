#include "media_wifi.h"

#include "../versus/versus_protocol.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>

#define MEDIA_WIFI_DEFAULT_PORT 43045u
#define MEDIA_WIFI_PEER_IP "192.168.137.91"
#define MEDIA_WIFI_SCAN_FILE "/data/wifi_scan.txt"
#define MEDIA_WIFI_IFCONFIG_FILE "/data/wifi_ifconfig.txt"
#define MEDIA_WIFI_CONFIG_FILE "/data/wifi.cfg"

typedef struct {
    int sockfd;
    char peer_ip[16];
    uint16_t local_port;
    uint16_t peer_port;
    uint8_t opened;
} media_udp_transport_t;

static volatile media_sound_id_t pending_sound = MEDIA_SOUND_NONE;
static pthread_t sound_thread;
static pthread_t versus_rx_thread;

static media_wifi_status_cb_t status_callback;
static media_wifi_game_cb_t game_callback;

static versus_ctx_t versus;
static media_udp_transport_t udp;
static int versus_enabled = 1;

static volatile int remote_start_request = 0;
static volatile int remote_finish_request = 0;
static volatile int finish_from_peer = 0;
static volatile int peer_score_pending = 0;
static volatile int peer_score_value = 0;
static char last_status[96] = "WiFi: idle";

static void notify_status(const char* text)
{
    if (text != NULL) {
        strncpy(last_status, text, sizeof(last_status) - 1);
        last_status[sizeof(last_status) - 1] = '\0';
    }

    if (status_callback != NULL && text != NULL) {
        status_callback(text);
    }
}

static const char* sound_path(media_sound_id_t id)
{
    switch (id) {
    case MEDIA_SOUND_HIT:
        return "/data/res/hit.wav";
    case MEDIA_SOUND_START:
        return "/data/res/start.wav";
    default:
        return NULL;
    }
}

static void play_sound_file(media_sound_id_t id)
{
    const char* path = sound_path(id);
    char cmd[128];

    if (path == NULL) {
        return;
    }

    snprintf(cmd, sizeof(cmd), "aplay -D hw:audiocodec %s", path);
    system(cmd);
}

static void* sound_task(void* arg)
{
    (void)arg;

    while (1) {
        media_sound_id_t id = pending_sound;

        if (id != MEDIA_SOUND_NONE) {
            pending_sound = MEDIA_SOUND_NONE;
            play_sound_file(id);
        }

        usleep(50 * 1000);
    }

    return NULL;
}

static int set_nonblocking(int fd)
{
    int flags = fcntl(fd, F_GETFL, 0);

    if (flags < 0) {
        return -1;
    }

    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static uint16_t choose_port(uint16_t port)
{
    return port == 0 ? MEDIA_WIFI_DEFAULT_PORT : port;
}

static int udp_open(media_udp_transport_t* transport,
                    const char* peer_ip,
                    uint16_t local_port,
                    uint16_t peer_port)
{
    struct sockaddr_in local_addr;
    int opt = 1;

    if (transport == NULL || peer_ip == NULL) {
        return -1;
    }

    memset(transport, 0, sizeof(*transport));
    transport->sockfd = -1;
    transport->local_port = choose_port(local_port);
    transport->peer_port = choose_port(peer_port);
    strncpy(transport->peer_ip, peer_ip, sizeof(transport->peer_ip) - 1);

    transport->sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (transport->sockfd < 0) {
        return -2;
    }

    (void)setsockopt(transport->sockfd,
                     SOL_SOCKET,
                     SO_REUSEADDR,
                     (const void*)&opt,
                     sizeof(opt));

    memset(&local_addr, 0, sizeof(local_addr));
    local_addr.sin_family = AF_INET;
    local_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    local_addr.sin_port = htons(transport->local_port);

    if (bind(transport->sockfd,
             (const struct sockaddr*)&local_addr,
             sizeof(local_addr)) < 0) {
        close(transport->sockfd);
        transport->sockfd = -1;
        return -3;
    }

    if (set_nonblocking(transport->sockfd) < 0) {
        close(transport->sockfd);
        transport->sockfd = -1;
        return -4;
    }

    transport->opened = 1;
    return 0;
}

static int udp_send_callback(const uint8_t* data, size_t len, void* user)
{
    media_udp_transport_t* transport = (media_udp_transport_t*)user;
    struct sockaddr_in peer_addr;
    ssize_t sent;

    if (transport == NULL || data == NULL || len == 0 || transport->opened == 0) {
        return -1;
    }

    memset(&peer_addr, 0, sizeof(peer_addr));
    peer_addr.sin_family = AF_INET;
    peer_addr.sin_port = htons(transport->peer_port);

    if (inet_pton(AF_INET, transport->peer_ip, &peer_addr.sin_addr) != 1) {
        return -2;
    }

    sent = sendto(transport->sockfd,
                  data,
                  len,
                  0,
                  (const struct sockaddr*)&peer_addr,
                  sizeof(peer_addr));

    return sent == (ssize_t)len ? 0 : -3;
}

static int udp_poll_packet(media_udp_transport_t* transport,
                           uint8_t packet[VERSUS_PACKET_SIZE])
{
    struct sockaddr_in from_addr;
    socklen_t from_len = sizeof(from_addr);
    ssize_t received;

    if (transport == NULL || packet == NULL || transport->opened == 0) {
        return -1;
    }

    received = recvfrom(transport->sockfd,
                        packet,
                        VERSUS_PACKET_SIZE,
                        0,
                        (struct sockaddr*)&from_addr,
                        &from_len);

    if (received < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0;
        }

        return -2;
    }

    if (received != VERSUS_PACKET_SIZE) {
        return -3;
    }

    return 1;
}

static int read_wlan0_ip(char* ip_buf, size_t ip_len)
{
    FILE* fp;
    char line[256];
    char* start;
    char* end;

    if (ip_buf == NULL || ip_len == 0) {
        return -1;
    }

    ip_buf[0] = '\0';
    system("ifconfig wlan0 > " MEDIA_WIFI_IFCONFIG_FILE);

    fp = fopen(MEDIA_WIFI_IFCONFIG_FILE, "r");
    if (fp == NULL) {
        return -1;
    }

    while (fgets(line, sizeof(line), fp) != NULL) {
        start = strstr(line, "inet addr:");
        if (start != NULL) {
            start += strlen("inet addr:");
            end = strchr(start, ' ');
            if (end != NULL) {
                *end = '\0';
            }
            strncpy(ip_buf, start, ip_len - 1);
            ip_buf[ip_len - 1] = '\0';
            fclose(fp);
            return 0;
        }

        start = strstr(line, "inet ");
        if (start != NULL && strstr(line, "inet6") == NULL) {
            start += strlen("inet ");
            end = strchr(start, ' ');
            if (end != NULL) {
                *end = '\0';
            }
            strncpy(ip_buf, start, ip_len - 1);
            ip_buf[ip_len - 1] = '\0';
            fclose(fp);
            return 0;
        }
    }

    fclose(fp);
    return -1;
}

static int parse_scan_file(const char* path, char names[][32], int max_count)
{
    FILE* fp;
    char line[256];
    int count = 0;

    fp = fopen(path, "r");
    if (fp == NULL) {
        return 0;
    }

    while (fgets(line, sizeof(line), fp) != NULL && count < max_count) {
        char* ssid;

        if (strstr(line, "bssid") != NULL) {
            continue;
        }

        ssid = strrchr(line, '\t');
        if (ssid == NULL) {
            ssid = strrchr(line, ' ');
        }

        if (ssid == NULL) {
            continue;
        }

        ssid++;
        ssid[strcspn(ssid, "\r\n")] = '\0';
        if (ssid[0] == '\0') {
            continue;
        }

        strncpy(names[count], ssid, 31);
        names[count][31] = '\0';
        count++;
    }

    fclose(fp);
    return count;
}

static void versus_init_if_enabled(void)
{
    printf("===== VERSUS ENTER =====\n");

    if (!versus_enabled) {
        return;
    }

    if (udp_open(&udp, MEDIA_WIFI_PEER_IP, 43046, 43045) != 0) {
        printf("[MEDIA_WIFI] versus udp open failed\n");
        versus_enabled = 0;
        return;
    }

    versus_init(&versus,
                VERSUS_DEVICE_B,
                VERSUS_DEVICE_A,
                udp_send_callback,
                &udp);

    printf("[MEDIA_WIFI] versus enabled: B -> %s\n", MEDIA_WIFI_PEER_IP);
}

static void* versus_rx_task(void* arg)
{
    uint8_t packet[VERSUS_PACKET_SIZE];

    (void)arg;

    while (1) {
        if (versus_enabled) {
            int ret = udp_poll_packet(&udp, packet);

            if (ret > 0) {
                versus_event_t event;
                versus_status_t status;

                status = versus_receive(&versus,
                                        packet,
                                        media_wifi_get_tick_ms(),
                                        &event);

                if (status == VERSUS_OK ||
                    status == VERSUS_ERR_DUPLICATE) {
                    if (event.msg_type == VERSUS_MSG_START) {
                        remote_start_request = 1;
                        media_wifi_sound_play(MEDIA_SOUND_START);
                        printf("[MEDIA_WIFI] START received\n");
                    } else if (event.msg_type == VERSUS_MSG_FINISH) {
                        finish_from_peer = 1;
                        remote_finish_request = 1;
                        printf("[MEDIA_WIFI] FINISH received\n");
                    } else {
                        peer_score_value = event.peer_score;
                        peer_score_pending = 1;

                        printf("[MEDIA_WIFI] msg=%s score=%d\n",
                               versus_msg_name(event.msg_type),
                               event.peer_score);
                    }
                } else {
                    printf("[MEDIA_WIFI] invalid status=%d\n", status);
                }
            }
        }

        usleep(10000);
    }

    return NULL;
}

void media_wifi_init(const media_wifi_game_cb_t* game_cb)
{
    if (game_cb != NULL) {
        game_callback = *game_cb;
    } else {
        memset(&game_callback, 0, sizeof(game_callback));
    }

    pthread_create(&sound_thread, NULL, sound_task, NULL);
    versus_init_if_enabled();
    pthread_create(&versus_rx_thread, NULL, versus_rx_task, NULL);
}

void media_wifi_sound_play(media_sound_id_t id)
{
    if (id != MEDIA_SOUND_NONE) {
        pending_sound = id;
    }
}

void media_wifi_set_status_callback(media_wifi_status_cb_t cb)
{
    status_callback = cb;
}

int media_wifi_connect(const char* ssid, const char* password)
{
    char cmd[256];
    char ip[32];
    char status[96];

    if (ssid == NULL || strlen(ssid) == 0) {
        notify_status("SSID is empty");
        return -1;
    }

    notify_status("Connecting...");
    printf("[MEDIA_WIFI] connect ssid=%s\n", ssid);

    system("ifup wlan0");
    system("wapi mode wlan0 2");

    if (password != NULL && strlen(password) > 0) {
        snprintf(cmd, sizeof(cmd), "wapi psk wlan0 \"%s\" 3", password);
        system(cmd);
    }

    snprintf(cmd, sizeof(cmd), "wapi essid wlan0 \"%s\" 1", ssid);
    system(cmd);

    system("renew wlan0");
    system("ifconfig");

    if (read_wlan0_ip(ip, sizeof(ip)) == 0 && ip[0] != '\0') {
        snprintf(status, sizeof(status), "Connected: %s", ip);
        notify_status(status);
        printf("[MEDIA_WIFI] connected ip=%s\n", ip);
        return 0;
    }

    notify_status("Connected (no IP yet)");
    printf("[MEDIA_WIFI] connected but ip not found\n");
    return 1;
}

int media_wifi_scan_ap_names(char names[][32], int max_count)
{
    int count;

    if (names == NULL || max_count <= 0) {
        return 0;
    }

    notify_status("Scanning...");
    system("wapi scan wlan0");
    system("wapi scan_results wlan0 > " MEDIA_WIFI_SCAN_FILE);

    count = parse_scan_file(MEDIA_WIFI_SCAN_FILE, names, max_count);

    if (count > 0) {
        notify_status("Scan complete");
    } else {
        system("sh /data/get_wifi.sh > /tmp/wifi_scan_result.txt");
        count = parse_scan_file("/tmp/wifi_scan_result.txt", names, max_count);
        if (count > 0) {
            notify_status("Scan complete (script)");
        } else {
            notify_status("Scan saved: " MEDIA_WIFI_SCAN_FILE);
        }
    }

    printf("[MEDIA_WIFI] scan found %d ap(s)\n", count);
    return count;
}

int media_wifi_save_config(const char* ssid, const char* password)
{
    FILE* fp;

    fp = fopen(MEDIA_WIFI_CONFIG_FILE, "w");
    if (fp == NULL) {
        printf("[MEDIA_WIFI] failed to open %s\n", MEDIA_WIFI_CONFIG_FILE);
        return -1;
    }

    fprintf(fp, "SSID=%s\n", ssid != NULL ? ssid : "");
    fprintf(fp, "PASSWORD=%s\n", password != NULL ? password : "");
    fclose(fp);

    printf("[MEDIA_WIFI] config saved ssid=%s\n", ssid != NULL ? ssid : "");
    return 0;
}

int media_wifi_is_versus_enabled(void)
{
    return versus_enabled;
}

void media_wifi_set_versus_enabled(int enabled)
{
    versus_enabled = enabled ? 1 : 0;
}

int media_wifi_versus_finish_from_peer(void)
{
    return finish_from_peer;
}

void media_wifi_versus_clear_finish_flag(void)
{
    finish_from_peer = 0;
}

void media_wifi_versus_send_start(uint32_t tick_ms, uint16_t duration_s)
{
    if (!versus_enabled) {
        return;
    }

    versus_send_start(&versus, tick_ms, 0, duration_s);
    media_wifi_sound_play(MEDIA_SOUND_START);
    printf("[MEDIA_WIFI] START sent\n");
}

void media_wifi_versus_send_score(uint32_t tick_ms, int16_t score)
{
    if (!versus_enabled) {
        return;
    }

    versus_send_score(&versus, tick_ms, score, 0);
}

void media_wifi_versus_send_finish(uint32_t tick_ms, uint8_t result)
{
    if (!versus_enabled) {
        return;
    }

    versus_send_finish(&versus, tick_ms, result);
    printf("[MEDIA_WIFI] FINISH sent result=%d\n", result);
}

void media_wifi_timer_poll(void)
{
    if (peer_score_pending) {
        peer_score_pending = 0;

        if (game_callback.on_peer_score != NULL) {
            game_callback.on_peer_score(peer_score_value, game_callback.user);
        }
    }

    if (remote_start_request) {
        remote_start_request = 0;

        if (game_callback.on_remote_start != NULL) {
            game_callback.on_remote_start(game_callback.user);
        }
    }

    if (remote_finish_request) {
        remote_finish_request = 0;

        if (game_callback.on_remote_finish != NULL) {
            game_callback.on_remote_finish(game_callback.user);
        }
    }
}

uint32_t media_wifi_get_tick_ms(void)
{
    struct timespec ts;

    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }

    return (uint32_t)(ts.tv_sec * 1000u + ts.tv_nsec / 1000000u);
}

const char* media_wifi_get_last_status(void)
{
    return last_status;
}
