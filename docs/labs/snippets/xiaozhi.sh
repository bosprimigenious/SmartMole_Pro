#!/bin/sh
# 板端 /data/xiaozhi.sh（由 pack 打入 usrdata）
wifi_manager &
amixer set 6 180
amixer set 7 180
amixer set 15 7
arecord &
aplay &
control_center &
lvgldemo &
