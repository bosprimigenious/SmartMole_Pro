/* 实验二：mole_click_event 完整调用链（基础 + 进阶） */
static void mole_click_event(lv_event_t *e)
{
  lv_obj_t *mole = lv_event_get_target(e);
  if (!lv_obj_has_flag(mole, LV_OBJ_FLAG_HIDDEN))
  {
    score++;
    lv_label_set_text_fmt(score_label, "score: %d", score);
    show_hit_effect(mole);   /* 进阶：半透明方框 200ms */
    play_hit_sound();        /* 进阶：task_create → aplay hit.wav */
    flash_led1();            /* 进阶：GPIO0 亮 150ms */
    lv_obj_add_flag(mole, LV_OBJ_FLAG_HIDDEN);
  }
}
