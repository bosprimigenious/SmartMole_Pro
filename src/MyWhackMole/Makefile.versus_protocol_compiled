include $(APPDIR)/Make.defs

PROGNAME = mywhackmole
PRIORITY = $(CONFIG_EXAMPLES_MYWHACKMOLE_PRIORITY)
STACKSIZE = $(CONFIG_EXAMPLES_MYWHACKMOLE_STACKSIZE)
MODULE = $(CONFIG_EXAMPLES_MYWHACKMOLE)

CSRCS = MyWhackMole.c lv_100ask_xz_ai_main.c storage.c \
        media_wifi/media_wifi.c \
        media_wifi/media_wifi_ui.c \
        versus/versus_protocol.c
MAINSRC = MyWhackMole_main.c

include $(APPDIR)/Application.mk
