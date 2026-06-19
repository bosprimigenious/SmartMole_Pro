static void play_hit_sound(void)
{
  static char *argv[] = {"aplay", "/data/res/hit.wav", NULL};
  extern int aplay_main(int argc, char *argv[]);
  task_create("hit_sound", 100, 81920, aplay_main, argv);
}
