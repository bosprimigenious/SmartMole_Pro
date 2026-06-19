/* 实验三：process_other_json 中 stt 分支挂接 LED 控制 */
} else if (strcmp(type->valuestring, "stt") == 0) {
  cJSON *text = cJSON_GetObjectItem(root, "text");
  if (text != NULL && cJSON_IsString(text)) {
    send_stt(text->valuestring);              /* 原逻辑：送 lvgldemo 显示 */
    process_voice_led_command(text->valuestring); /* 进阶新增：本地关键词控灯 */
  }
}
