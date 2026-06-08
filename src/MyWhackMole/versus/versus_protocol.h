#ifndef VERSUS_PROTOCOL_H
#define VERSUS_PROTOCOL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VERSUS_PROTOCOL_VERSION 1u
#define VERSUS_PACKET_SIZE 24u
#define VERSUS_MAGIC 0xA5u
#define VERSUS_BROADCAST_ID 0xFFu
#define VERSUS_OFFLINE_TIMEOUT_MS 3000u
#define VERSUS_HEARTBEAT_INTERVAL_MS 500u

typedef enum {
    VERSUS_OK = 0,
    VERSUS_ERR_ARG = -1,
    VERSUS_ERR_SEND = -2,
    VERSUS_ERR_PACKET = -3,
    VERSUS_ERR_CRC = -4,
    VERSUS_ERR_VERSION = -5,
    VERSUS_ERR_DST = -6,
    VERSUS_ERR_DUPLICATE = -7
} versus_status_t;

typedef enum {
    VERSUS_DEVICE_A = 1,
    VERSUS_DEVICE_B = 2
} versus_device_id_t;

typedef enum {
    VERSUS_STATE_IDLE = 0,
    VERSUS_STATE_READY,
    VERSUS_STATE_COUNTDOWN,
    VERSUS_STATE_RUNNING,
    VERSUS_STATE_FINISHED,
    VERSUS_STATE_OFFLINE
} versus_game_state_t;

typedef enum {
    VERSUS_MSG_HELLO = 1,
    VERSUS_MSG_READY,
    VERSUS_MSG_START,
    VERSUS_MSG_HIT,
    VERSUS_MSG_MISS,
    VERSUS_MSG_SCORE,
    VERSUS_MSG_INTERFERE,
    VERSUS_MSG_TIME_SYNC,
    VERSUS_MSG_FINISH,
    VERSUS_MSG_HEARTBEAT,
    VERSUS_MSG_ACK
} versus_msg_type_t;

typedef enum {
    VERSUS_TARGET_NORMAL = 0,
    VERSUS_TARGET_GOLDEN,
    VERSUS_TARGET_BOMB,
    VERSUS_TARGET_SPEED,
    VERSUS_TARGET_INTERFERE
} versus_target_type_t;

typedef enum {
    VERSUS_FINISH_DRAW = 0,
    VERSUS_FINISH_LOCAL_WIN,
    VERSUS_FINISH_PEER_WIN
} versus_finish_result_t;

typedef struct {
    uint8_t src_id;
    uint8_t dst_id;
    uint8_t msg_type;
    uint8_t seq;
    uint8_t flags;
    uint32_t tick_ms;
    int16_t score;
    uint8_t combo;
    uint8_t event;
    uint8_t target;
    uint8_t x;
    uint8_t y;
    uint16_t remaining_s;
    uint16_t param;
} versus_packet_t;

typedef struct {
    uint8_t peer_id;
    uint8_t msg_type;
    uint8_t seq;
    uint8_t duplicate;
    uint32_t rx_tick_ms;
    int16_t peer_score;
    uint8_t peer_combo;
    uint8_t event;
    uint8_t target;
    uint8_t x;
    uint8_t y;
    uint16_t remaining_s;
    uint16_t param;
} versus_event_t;

typedef int (*versus_send_fn)(const uint8_t *data, size_t len, void *user);

typedef struct {
    uint8_t local_id;
    uint8_t peer_id;
    uint8_t next_seq;
    uint8_t last_rx_seq;
    uint8_t has_peer;
    uint8_t peer_online;
    uint32_t last_rx_ms;
    uint32_t last_heartbeat_ms;
    int16_t local_score;
    int16_t peer_score;
    uint8_t local_combo;
    uint8_t peer_combo;
    uint16_t remaining_s;
    versus_game_state_t state;
    versus_send_fn send;
    void *send_user;
} versus_ctx_t;

void versus_init(versus_ctx_t *ctx,
                 uint8_t local_id,
                 uint8_t peer_id,
                 versus_send_fn send,
                 void *send_user);

uint16_t versus_crc16(const uint8_t *data, size_t len);

versus_status_t versus_encode_packet(const versus_packet_t *packet,
                                      uint8_t out[VERSUS_PACKET_SIZE]);

versus_status_t versus_decode_packet(const uint8_t data[VERSUS_PACKET_SIZE],
                                      versus_packet_t *packet);

versus_status_t versus_receive(versus_ctx_t *ctx,
                                const uint8_t data[VERSUS_PACKET_SIZE],
                                uint32_t now_ms,
                                versus_event_t *event);

versus_status_t versus_tick(versus_ctx_t *ctx, uint32_t now_ms);

versus_status_t versus_send_hello(versus_ctx_t *ctx, uint32_t now_ms);
versus_status_t versus_send_ready(versus_ctx_t *ctx, uint32_t now_ms);
versus_status_t versus_send_start(versus_ctx_t *ctx,
                                   uint32_t now_ms,
                                   uint16_t countdown_s,
                                   uint16_t duration_s);
versus_status_t versus_send_time_sync(versus_ctx_t *ctx,
                                       uint32_t now_ms,
                                       uint16_t remaining_s);
versus_status_t versus_send_hit(versus_ctx_t *ctx,
                                 uint32_t now_ms,
                                 uint8_t x,
                                 uint8_t y,
                                 uint8_t target,
                                 int16_t new_score,
                                 uint8_t combo);
versus_status_t versus_send_miss(versus_ctx_t *ctx,
                                  uint32_t now_ms,
                                  int16_t new_score,
                                  uint8_t combo);
versus_status_t versus_send_score(versus_ctx_t *ctx,
                                   uint32_t now_ms,
                                   int16_t new_score,
                                   uint8_t combo);
versus_status_t versus_send_interfere(versus_ctx_t *ctx,
                                       uint32_t now_ms,
                                       uint8_t effect_id,
                                       uint16_t duration_ms);
versus_status_t versus_send_finish(versus_ctx_t *ctx,
                                    uint32_t now_ms,
                                    uint8_t result);

const char *versus_msg_name(uint8_t msg_type);
const char *versus_state_name(versus_game_state_t state);

#ifdef __cplusplus
}
#endif

#endif
