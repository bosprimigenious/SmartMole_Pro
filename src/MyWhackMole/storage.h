#ifndef STORAGE_H
#define STORAGE_H

typedef struct
{
    int best_single_score;
    int best_combo;

    int total_games;

    int versus_games;
    int versus_wins;
    int versus_draws;
} storage_data_t;

void storage_init(void);

void storage_update_result(int versus_mode,
                           int score_a,
                           int score_b,
                           int level,
                           int combo);

void storage_get_data(storage_data_t* out);

void storage_print_data(void);

#endif
