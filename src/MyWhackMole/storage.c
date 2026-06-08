#include "storage.h"

#include <stdio.h>
#include <string.h>

#define STORAGE_FILE_PATH "/data/whackmole_stats.dat"

static storage_data_t g_storage;

static void storage_save(void)
{
    FILE* fp = fopen(STORAGE_FILE_PATH, "wb");

    if (!fp) {
        printf("[STORAGE] open save file failed\n");
        return;
    }

    fwrite(&g_storage, sizeof(g_storage), 1, fp);
    fclose(fp);

    printf("[STORAGE] saved\n");
}

void storage_init(void)
{
    FILE* fp = fopen(STORAGE_FILE_PATH, "rb");

    memset(&g_storage, 0, sizeof(g_storage));

    if (!fp) {
        printf("[STORAGE] no old data, create new\n");
        storage_save();
        return;
    }

    fread(&g_storage, sizeof(g_storage), 1, fp);
    fclose(fp);

    printf("[STORAGE] loaded\n");
}

void storage_update_result(int versus_mode,
                           int score_a,
                           int score_b,
                           int level,
                           int combo)
{
    g_storage.total_games++;

    if (!versus_mode) {
        if (score_a > g_storage.best_single_score) {
            g_storage.best_single_score = score_a;
        }

        if (combo > g_storage.best_combo) {
            g_storage.best_combo = combo;
        }
    } else {
        g_storage.versus_games++;

        if (score_a > score_b) {
            g_storage.versus_wins++;
        } else if (score_a == score_b) {
            g_storage.versus_draws++;
        }
    }

    printf("[STORAGE] update: versus=%d score=%d:%d level=%d combo=%d\n",
           versus_mode,
           score_a,
           score_b,
           level,
           combo);

    storage_save();
}

void storage_get_data(storage_data_t* out)
{
    if (!out) {
        return;
    }

    *out = g_storage;
}

void storage_print_data(void)
{
    printf("===== SmartMole Statistics =====\n");
    printf("Best Single Score: %d\n", g_storage.best_single_score);
    printf("Best Combo       : %d\n", g_storage.best_combo);
    printf("Total Games      : %d\n", g_storage.total_games);
    printf("Versus Games     : %d\n", g_storage.versus_games);
    printf("Versus Wins      : %d\n", g_storage.versus_wins);
    printf("Versus Draws     : %d\n", g_storage.versus_draws);
}
