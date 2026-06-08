include $(APPDIR)/Make.defs

PROGNAME = mywhackmole
PRIORITY = $(CONFIG_EXAMPLES_MYWHACKMOLE_PRIORITY)
STACKSIZE = $(CONFIG_EXAMPLES_MYWHACKMOLE_STACKSIZE)
MODULE = $(CONFIG_EXAMPLES_MYWHACKMOLE)

CSRCS = MyWhackMole.c lv_100ask_xz_ai_main.c storage.c wifi_ui.c \
        versus/versus_protocol.c \
        versus/versus_wifi_transport.c
MAINSRC = MyWhackMole_main.c

include $(APPDIR)/Application.mk
