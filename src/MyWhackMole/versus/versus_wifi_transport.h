#ifndef VERSUS_WIFI_TRANSPORT_H
#define VERSUS_WIFI_TRANSPORT_H

#include <stdint.h>
#include <stddef.h>

#include "versus_protocol.h"

#ifdef __cplusplus
extern "C" {
#endif

#define VERSUS_WIFI_DEFAULT_PORT 43045u
#define VERSUS_WIFI_IP_STR_LEN 16u

typedef struct {
    const char *peer_ip;
    uint16_t local_port;
    uint16_t peer_port;
    uint8_t nonblocking;
} versus_wifi_config_t;

typedef struct {
    int sockfd;
    char peer_ip[VERSUS_WIFI_IP_STR_LEN];
    uint16_t local_port;
    uint16_t peer_port;
    uint8_t opened;
} versus_wifi_transport_t;

int versus_wifi_open(versus_wifi_transport_t *wifi,
                     const versus_wifi_config_t *config);

void versus_wifi_close(versus_wifi_transport_t *wifi);

int versus_wifi_send_callback(const uint8_t *data, size_t len, void *user);

int versus_wifi_poll_packet(versus_wifi_transport_t *wifi,
                            uint8_t packet[VERSUS_PACKET_SIZE]);

#ifdef __cplusplus
}
#endif

#endif
