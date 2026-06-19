static void hit_effect_delete_cb(lv_timer_t *timer)
{
  lv_obj_t *obj = (lv_obj_t *)timer->user_data;
  if (obj != NULL)
  {
    lv_obj_delete(obj);
  }
  lv_timer_delete(timer);
}

static void show_hit_effect(lv_obj_t *mole)
{
  lv_obj_t *box = lv_obj_create(game_screen);
  lv_obj_set_size(box, lv_obj_get_width(mole) + 12, lv_obj_get_height(mole) + 12);
  lv_obj_align_to(box, mole, LV_ALIGN_CENTER, 0, 0);
  lv_obj_set_style_bg_color(box, lv_color_hex(0xFFFFFF), 0);
  lv_obj_set_style_bg_opa(box, LV_OPA_30, 0);
  lv_obj_set_style_border_color(box, lv_color_hex(0xFFFF00), 0);
  lv_obj_set_style_border_width(box, 3, 0);
  lv_obj_set_style_radius(box, 8, 0);
  lv_obj_remove_flag(box, LV_OBJ_FLAG_CLICKABLE);
  lv_obj_move_foreground(box);
  lv_timer_create(hit_effect_delete_cb, 200, box);
}
