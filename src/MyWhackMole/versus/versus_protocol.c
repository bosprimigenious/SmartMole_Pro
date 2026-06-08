#include "versus_protocol.h"

#include <string.h>

enum {
    PKT_MAGIC = 0,
    PKT_VERSION = 1,
    PKT_TYPE = 2,
    PKT_SRC = 3,
    PKT_DST = 4,
    PKT_SEQ = 5,
    PKT_FLAGS = 6,
    PKT_TICK0 = 7,
    PKT_SCORE0 = 11,
    PKT_COMBO = 13,
    PKT_EVENT = 14,
    PKT_TARGET = 15,
    PKT_X = 16,
    PKT_Y = 17,
    PKT_REMAIN0 = 18,
    PKT_PARAM0 = 20,
    PKT_CRC0 = 22
};

static uint16_t read_u16_le(const uint8_t *p)
{
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t read_u32_le(const uint8_t *p)
{
    return (uint32_t)p[0] |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static void write_u16_le(uint8_t *p, uint16_t value)
{
    p[0] = (uint8_t)(value & 0xFFu);
    p[1] = (uint8_t)((value >> 8) & 0xFFu);
}

static void write_u32_le(uint8_t *p, uint32_t value)
{
    p[0] = (uint8_t)(value & 0xFFu);
    p[1] = (uint8_t)((value >> 8) & 0xFFu);
    p[2] = (uint8_t)((value >> 16) & 0xFFu);
    p[3] = (uint8_t)((value >> 24) & 0xFFu);
}

static uint8_t default_peer(uint8_t local_id)
{
    if (local_id == VERSUS_DEVICE_A) {
        return VERSUS_DEVICE_B;
    }

    if (local_id == VERSUS_DEVICE_B) {
        return VERSUS_DEVICE_A;
    }

    return VERSUS_BROADCAST_ID;
}

static versus_status_t send_packet(versus_ctx_t *ctx,
                                   uint8_t msg_type,
                                   uint32_t now_ms,
                                   int16_t score,
                                   uint8_t combo,
                                   uint8_t event,
                                   uint8_t target,
                                   uint8_t x,
                                   uint8_t y,
                                   uint16_t remaining_s,
                                   uint16_t param,
                                   uint8_t flags)
{
    uint8_t encoded[VERSUS_PACKET_SIZE];
    versus_packet_t packet;

    if (ctx == 0 || ctx->send == 0) {
        return VERSUS_ERR_ARG;
    }

    memset(&packet, 0, sizeof(packet));
    packet.src_id = ctx->local_id;
    packet.dst_id = ctx->peer_id;
    packet.msg_type = msg_type;
    packet.seq = ctx->next_seq++;
    packet.flags = flags;
    packet.tick_ms = now_ms;
    packet.score = score;
    packet.combo = combo;
    packet.event = event;
    packet.target = target;
    packet.x = x;
    packet.y = y;
    packet.remaining_s = remaining_s;
    packet.param = param;

    if (versus_encode_packet(&packet, encoded) != VERSUS_OK) {
        return VERSUS_ERR_PACKET;
    }

    if (ctx->send(encoded, sizeof(encoded), ctx->send_user) != 0) {
        return VERSUS_ERR_SEND;
    }

    return VERSUS_OK;
}

void versus_init(versus_ctx_t *ctx,
                 uint8_t local_id,
                 uint8_t peer_id,
                 versus_send_fn send,
                 void *send_user)
{
    if (ctx == 0) {
        return;
    }

    memset(ctx, 0, sizeof(*ctx));
    ctx->local_id = local_id;
    ctx->peer_id = peer_id == 0 ? default_peer(local_id) : peer_id;
    ctx->next_seq = 1;
    ctx->last_rx_seq = 0;
    ctx->send = send;
    ctx->send_user = send_user;
    ctx->remaining_s = 0;
    ctx->state = VERSUS_STATE_IDLE;
}

uint16_t versus_crc16(const uint8_t *data, size_t len)
{
    uint16_t crc = 0xFFFFu;
    size_t i;

    if (data == 0) {
        return 0;
    }

    for (i = 0; i < len; ++i) {
        uint8_t bit;
        crc ^= (uint16_t)data[i] << 8;
        for (bit = 0; bit < 8; ++bit) {
            if ((crc & 0x8000u) != 0) {
                crc = (uint16_t)((crc << 1) ^ 0x1021u);
            } else {
                crc <<= 1;
            }
        }
    }

    return crc;
}

versus_status_t versus_encode_packet(const versus_packet_t *packet,
                                      uint8_t out[VERSUS_PACKET_SIZE])
{
    uint16_t crc;

    if (packet == 0 || out == 0) {
        return VERSUS_ERR_ARG;
    }

    memset(out, 0, VERSUS_PACKET_SIZE);
    out[PKT_MAGIC] = VERSUS_MAGIC;
    out[PKT_VERSION] = VERSUS_PROTOCOL_VERSION;
    out[PKT_TYPE] = packet->msg_type;
    out[PKT_SRC] = packet->src_id;
    out[PKT_DST] = packet->dst_id;
    out[PKT_SEQ] = packet->seq;
    out[PKT_FLAGS] = packet->flags;
    write_u32_le(&out[PKT_TICK0], packet->tick_ms);
    write_u16_le(&out[PKT_SCORE0], (uint16_t)packet->score);
    out[PKT_COMBO] = packet->combo;
    out[PKT_EVENT] = packet->event;
    out[PKT_TARGET] = packet->target;
    out[PKT_X] = packet->x;
    out[PKT_Y] = packet->y;
    write_u16_le(&out[PKT_REMAIN0], packet->remaining_s);
    write_u16_le(&out[PKT_PARAM0], packet->param);

    crc = versus_crc16(out, PKT_CRC0);
    write_u16_le(&out[PKT_CRC0], crc);

    return VERSUS_OK;
}

versus_status_t versus_decode_packet(const uint8_t data[VERSUS_PACKET_SIZE],
                                      versus_packet_t *packet)
{
    uint16_t expected_crc;
    uint16_t actual_crc;

    if (data == 0 || packet == 0) {
        return VERSUS_ERR_ARG;
    }

    if (data[PKT_MAGIC] != VERSUS_MAGIC) {
        return VERSUS_ERR_PACKET;
    }

    if (data[PKT_VERSION] != VERSUS_PROTOCOL_VERSION) {
        return VERSUS_ERR_VERSION;
    }

    expected_crc = read_u16_le(&data[PKT_CRC0]);
    actual_crc = versus_crc16(data, PKT_CRC0);
    if (expected_crc != actual_crc) {
        return VERSUS_ERR_CRC;
    }

    memset(packet, 0, sizeof(*packet));
    packet->msg_type = data[PKT_TYPE];
    packet->src_id = data[PKT_SRC];
    packet->dst_id = data[PKT_DST];
    packet->seq = data[PKT_SEQ];
    packet->flags = data[PKT_FLAGS];
    packet->tick_ms = read_u32_le(&data[PKT_TICK0]);
    packet->score = (int16_t)read_u16_le(&data[PKT_SCORE0]);
    packet->combo = data[PKT_COMBO];
    packet->event = data[PKT_EVENT];
    packet->target = data[PKT_TARGET];
    packet->x = data[PKT_X];
    packet->y = data[PKT_Y];
    packet->remaining_s = read_u16_le(&data[PKT_REMAIN0]);
    packet->param = read_u16_le(&data[PKT_PARAM0]);

    return VERSUS_OK;
}

versus_status_t versus_receive(versus_ctx_t *ctx,
                                const uint8_t data[VERSUS_PACKET_SIZE],
                                uint32_t now_ms,
                                versus_event_t *event)
{
    versus_packet_t packet;
    versus_status_t status;
    uint8_t duplicate;

    if (ctx == 0 || data == 0) {
        return VERSUS_ERR_ARG;
    }

    status = versus_decode_packet(data, &packet);
    if (status != VERSUS_OK) {
        return status;
    }

    if (packet.dst_id != ctx->local_id && packet.dst_id != VERSUS_BROADCAST_ID) {
        return VERSUS_ERR_DST;
    }

    if (packet.src_id == ctx->local_id) {
        return VERSUS_ERR_DST;
    }

    duplicate = (ctx->has_peer != 0 &&
                 packet.src_id == ctx->peer_id &&
                 packet.seq == ctx->last_rx_seq);

    ctx->peer_id = packet.src_id;
    ctx->has_peer = 1;
    ctx->peer_online = 1;
    ctx->last_rx_ms = now_ms;

    if (!duplicate) {
        ctx->last_rx_seq = packet.seq;
        ctx->peer_score = packet.score;
        ctx->peer_combo = packet.combo;
        if (packet.remaining_s != 0 || packet.msg_type == VERSUS_MSG_TIME_SYNC) {
            ctx->remaining_s = packet.remaining_s;
        }

        switch (packet.msg_type) {
        case VERSUS_MSG_READY:
            if (ctx->state == VERSUS_STATE_IDLE) {
                ctx->state = VERSUS_STATE_READY;
            }
            break;
        case VERSUS_MSG_START:
            ctx->state = VERSUS_STATE_COUNTDOWN;
            ctx->remaining_s = packet.param;
            break;
        case VERSUS_MSG_TIME_SYNC:
            ctx->remaining_s = packet.remaining_s;
            break;
        case VERSUS_MSG_HIT:
        case VERSUS_MSG_MISS:
        case VERSUS_MSG_SCORE:
        case VERSUS_MSG_INTERFERE:
            if (ctx->state == VERSUS_STATE_COUNTDOWN) {
                ctx->state = VERSUS_STATE_RUNNING;
            }
            break;
        case VERSUS_MSG_FINISH:
            ctx->state = VERSUS_STATE_FINISHED;
            break;
        default:
            break;
        }
    }

    if (event != 0) {
        memset(event, 0, sizeof(*event));
        event->peer_id = packet.src_id;
        event->msg_type = packet.msg_type;
        event->seq = packet.seq;
        event->duplicate = duplicate;
        event->rx_tick_ms = now_ms;
        event->peer_score = packet.score;
        event->peer_combo = packet.combo;
        event->event = packet.event;
        event->target = packet.target;
        event->x = packet.x;
        event->y = packet.y;
        event->remaining_s = packet.remaining_s;
        event->param = packet.param;
    }

    return duplicate ? VERSUS_ERR_DUPLICATE : VERSUS_OK;
}

versus_status_t versus_tick(versus_ctx_t *ctx, uint32_t now_ms)
{
    if (ctx == 0) {
        return VERSUS_ERR_ARG;
    }

    if (ctx->peer_online != 0 &&
        now_ms - ctx->last_rx_ms > VERSUS_OFFLINE_TIMEOUT_MS) {
        ctx->peer_online = 0;
        ctx->state = VERSUS_STATE_OFFLINE;
    }

    if (now_ms - ctx->last_heartbeat_ms >= VERSUS_HEARTBEAT_INTERVAL_MS) {
        ctx->last_heartbeat_ms = now_ms;
        return send_packet(ctx,
                           VERSUS_MSG_HEARTBEAT,
                           now_ms,
                           ctx->local_score,
                           ctx->local_combo,
                           0,
                           0,
                           0,
                           0,
                           ctx->remaining_s,
                           0,
                           0);
    }

    return VERSUS_OK;
}

versus_status_t versus_send_hello(versus_ctx_t *ctx, uint32_t now_ms)
{
    return send_packet(ctx,
                       VERSUS_MSG_HELLO,
                       now_ms,
                       ctx ? ctx->local_score : 0,
                       ctx ? ctx->local_combo : 0,
                       0,
                       0,
                       0,
                       0,
                       ctx ? ctx->remaining_s : 0,
                       0,
                       0);
}

versus_status_t versus_send_ready(versus_ctx_t *ctx, uint32_t now_ms)
{
    if (ctx != 0) {
        ctx->state = VERSUS_STATE_READY;
    }

    return send_packet(ctx,
                       VERSUS_MSG_READY,
                       now_ms,
                       ctx ? ctx->local_score : 0,
                       ctx ? ctx->local_combo : 0,
                       0,
                       0,
                       0,
                       0,
                       ctx ? ctx->remaining_s : 0,
                       0,
                       0);
}

versus_status_t versus_send_start(versus_ctx_t *ctx,
                                   uint32_t now_ms,
                                   uint16_t countdown_s,
                                   uint16_t duration_s)
{
    if (ctx != 0) {
        ctx->state = VERSUS_STATE_COUNTDOWN;
        ctx->remaining_s = duration_s;
    }

    return send_packet(ctx,
                       VERSUS_MSG_START,
                       now_ms,
                       ctx ? ctx->local_score : 0,
                       ctx ? ctx->local_combo : 0,
                       0,
                       0,
                       0,
                       0,
                       countdown_s,
                       duration_s,
                       0);
}

versus_status_t versus_send_time_sync(versus_ctx_t *ctx,
                                       uint32_t now_ms,
                                       uint16_t remaining_s)
{
    if (ctx != 0) {
        ctx->remaining_s = remaining_s;
    }

    return send_packet(ctx,
                       VERSUS_MSG_TIME_SYNC,
                       now_ms,
                       ctx ? ctx->local_score : 0,
                       ctx ? ctx->local_combo : 0,
                       0,
                       0,
                       0,
                       0,
                       remaining_s,
                       0,
                       0);
}

versus_status_t versus_send_hit(versus_ctx_t *ctx,
                                 uint32_t now_ms,
                                 uint8_t x,
                                 uint8_t y,
                                 uint8_t target,
                                 int16_t new_score,
                                 uint8_t combo)
{
    if (ctx != 0) {
        ctx->local_score = new_score;
        ctx->local_combo = combo;
        if (ctx->state == VERSUS_STATE_COUNTDOWN) {
            ctx->state = VERSUS_STATE_RUNNING;
        }
    }

    return send_packet(ctx,
                       VERSUS_MSG_HIT,
                       now_ms,
                       new_score,
                       combo,
                       1,
                       target,
                       x,
                       y,
                       ctx ? ctx->remaining_s : 0,
                       0,
                       0);
}

versus_status_t versus_send_miss(versus_ctx_t *ctx,
                                  uint32_t now_ms,
                                  int16_t new_score,
                                  uint8_t combo)
{
    if (ctx != 0) {
        ctx->local_score = new_score;
        ctx->local_combo = combo;
        if (ctx->state == VERSUS_STATE_COUNTDOWN) {
            ctx->state = VERSUS_STATE_RUNNING;
        }
    }

    return send_packet(ctx,
                       VERSUS_MSG_MISS,
                       now_ms,
                       new_score,
                       combo,
                       0,
                       VERSUS_TARGET_NORMAL,
                       0,
                       0,
                       ctx ? ctx->remaining_s : 0,
                       0,
                       0);
}

versus_status_t versus_send_score(versus_ctx_t *ctx,
                                   uint32_t now_ms,
                                   int16_t new_score,
                                   uint8_t combo)
{
    if (ctx != 0) {
        ctx->local_score = new_score;
        ctx->local_combo = combo;
    }

    return send_packet(ctx,
                       VERSUS_MSG_SCORE,
                       now_ms,
                       new_score,
                       combo,
                       0,
                       VERSUS_TARGET_NORMAL,
                       0,
                       0,
                       ctx ? ctx->remaining_s : 0,
                       0,
                       0);
}

versus_status_t versus_send_interfere(versus_ctx_t *ctx,
                                       uint32_t now_ms,
                                       uint8_t effect_id,
                                       uint16_t duration_ms)
{
    return send_packet(ctx,
                       VERSUS_MSG_INTERFERE,
                       now_ms,
                       ctx ? ctx->local_score : 0,
                       ctx ? ctx->local_combo : 0,
                       effect_id,
                       VERSUS_TARGET_INTERFERE,
                       0,
                       0,
                       ctx ? ctx->remaining_s : 0,
                       duration_ms,
                       0);
}

versus_status_t versus_send_finish(versus_ctx_t *ctx,
                                    uint32_t now_ms,
                                    uint8_t result)
{
    if (ctx != 0) {
        ctx->state = VERSUS_STATE_FINISHED;
    }

    return send_packet(ctx,
                       VERSUS_MSG_FINISH,
                       now_ms,
                       ctx ? ctx->local_score : 0,
                       ctx ? ctx->local_combo : 0,
                       result,
                       0,
                       0,
                       0,
                       ctx ? ctx->remaining_s : 0,
                       0,
                       0);
}

const char *versus_msg_name(uint8_t msg_type)
{
    switch (msg_type) {
    case VERSUS_MSG_HELLO:
        return "HELLO";
    case VERSUS_MSG_READY:
        return "READY";
    case VERSUS_MSG_START:
        return "START";
    case VERSUS_MSG_HIT:
        return "HIT";
    case VERSUS_MSG_MISS:
        return "MISS";
    case VERSUS_MSG_SCORE:
        return "SCORE";
    case VERSUS_MSG_INTERFERE:
        return "INTERFERE";
    case VERSUS_MSG_TIME_SYNC:
        return "TIME_SYNC";
    case VERSUS_MSG_FINISH:
        return "FINISH";
    case VERSUS_MSG_HEARTBEAT:
        return "HEARTBEAT";
    case VERSUS_MSG_ACK:
        return "ACK";
    default:
        return "UNKNOWN";
    }
}

const char *versus_state_name(versus_game_state_t state)
{
    switch (state) {
    case VERSUS_STATE_IDLE:
        return "IDLE";
    case VERSUS_STATE_READY:
        return "READY";
    case VERSUS_STATE_COUNTDOWN:
        return "COUNTDOWN";
    case VERSUS_STATE_RUNNING:
        return "RUNNING";
    case VERSUS_STATE_FINISHED:
        return "FINISHED";
    case VERSUS_STATE_OFFLINE:
        return "OFFLINE";
    default:
        return "UNKNOWN";
    }
}
