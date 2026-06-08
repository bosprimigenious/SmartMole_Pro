#include "versus_wifi_transport.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>

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
    return port == 0 ? VERSUS_WIFI_DEFAULT_PORT : port;
}

int versus_wifi_open(versus_wifi_transport_t *wifi,
                     const versus_wifi_config_t *config)
{
    struct sockaddr_in local_addr;
    int opt = 1;

    if (wifi == 0 || config == 0 || config->peer_ip == 0) {
        return -1;
    }

    memset(wifi, 0, sizeof(*wifi));
    wifi->sockfd = -1;
    wifi->local_port = choose_port(config->local_port);
    wifi->peer_port = choose_port(config->peer_port);
    strncpy(wifi->peer_ip, config->peer_ip, sizeof(wifi->peer_ip) - 1u);

    wifi->sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (wifi->sockfd < 0) {
        return -2;
    }

    (void)setsockopt(wifi->sockfd,
                     SOL_SOCKET,
                     SO_REUSEADDR,
                     (const void *)&opt,
                     sizeof(opt));

    memset(&local_addr, 0, sizeof(local_addr));
    local_addr.sin_family = AF_INET;
    local_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    local_addr.sin_port = htons(wifi->local_port);

    if (bind(wifi->sockfd,
             (const struct sockaddr *)&local_addr,
             sizeof(local_addr)) < 0) {
        versus_wifi_close(wifi);
        return -3;
    }

    if (config->nonblocking != 0 && set_nonblocking(wifi->sockfd) < 0) {
        versus_wifi_close(wifi);
        return -4;
    }

    wifi->opened = 1;
    return 0;
}

void versus_wifi_close(versus_wifi_transport_t *wifi)
{
    if (wifi == 0) {
        return;
    }

    if (wifi->sockfd >= 0) {
        (void)close(wifi->sockfd);
    }

    wifi->sockfd = -1;
    wifi->opened = 0;
}

int versus_wifi_send_callback(const uint8_t *data, size_t len, void *user)
{
    versus_wifi_transport_t *wifi = (versus_wifi_transport_t *)user;
    struct sockaddr_in peer_addr;
    ssize_t sent;

    if (wifi == 0 || data == 0 || len == 0 || wifi->opened == 0) {
        return -1;
    }

    memset(&peer_addr, 0, sizeof(peer_addr));
    peer_addr.sin_family = AF_INET;
    peer_addr.sin_port = htons(wifi->peer_port);

    if (inet_pton(AF_INET, wifi->peer_ip, &peer_addr.sin_addr) != 1) {
        return -2;
    }

    sent = sendto(wifi->sockfd,
                  data,
                  len,
                  0,
                  (const struct sockaddr *)&peer_addr,
                  sizeof(peer_addr));

    return sent == (ssize_t)len ? 0 : -3;
}

int versus_wifi_poll_packet(versus_wifi_transport_t *wifi,
                            uint8_t packet[VERSUS_PACKET_SIZE])
{
    struct sockaddr_in from_addr;
    socklen_t from_len = sizeof(from_addr);
    ssize_t received;

    if (wifi == 0 || packet == 0 || wifi->opened == 0) {
        return -1;
    }

    received = recvfrom(wifi->sockfd,
                        packet,
                        VERSUS_PACKET_SIZE,
                        0,
                        (struct sockaddr *)&from_addr,
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
