#!/bin/bash
# openvela 标准编译、打包、定位镜像（三项实验通用）
cd ~/vela-opensource/vendor/allwinnertech/lichee/
source vela_env.sh
source envsetup.sh
lunch_nuttx    # 选 2：r528s3-velaevb1
m
pack
find ~/vela-opensource/vendor/allwinnertech/lichee/out \
  -name "rtos_nuttx_r528s3-velaevb1_uart0_256Mnand.img"

# Windows：将 img 拷到本机，PhoenixSuit → 一键刷机 → 全盘擦除升级
# 按住 FEL，短按 RST，等待烧录完成
# MobaXterm：Serial，1500000，Flow Control = none
