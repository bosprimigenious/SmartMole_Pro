static void process_voice_led_command(const char *text)
{
    if (text == NULL) {
        return;
    }
    if (strstr(text, "开灯") || strstr(text, "打开灯") ||
        strstr(text, "打开LED") || strstr(text, "打开LED1")) {
        printf("voice command: turn on LED1\n");
        leds_ctl(0, true);
    } else if (strstr(text, "关灯") || strstr(text, "关闭灯") ||
               strstr(text, "关闭LED") || strstr(text, "关闭LED1")) {
        printf("voice command: turn off LED1\n");
        leds_ctl(0, false);
    }
}
