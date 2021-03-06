#ifndef _NEO2_H_
#define _NEO2_H_

#include "snes.h"
#include "integer.h"

extern void copy_ram_code();

extern void neo2_myth_current_rom_read(char *dest, u16 romBank, u16 romOffset, u16 length);
extern void neo2_myth_bootcart_rom_read(char *dest, u16 romBank, u16 romOffset, u16 length);

//extern void neo2_check_gbac_psram();

extern u16 neo2_read_id();

extern void neo2_myth_psram_read(char *dest, u16 psramBank, u16 psramOffset, u16 length);
extern void neo2_myth_psram_write(char *src, u16 psramBank, u16 psramOffset, u16 length);
extern void neo2_myth_psram_write_test_data(char *src, u16 psramBank, u16 psramOffset, u16 length);
extern void neo2_gbac_psram_write_test_data(char *src, u16 psramBank, u16 psramOffset, u16 length);
extern void neo2_gbac_psram_read(char *dest, u16 psramBank, u16 psramOffset, u16 length);
extern void neo2_sram_read(char *dest, u16 sramBank, u16 sramOffset, u16 length);
extern void neo2_sram_write(char *src, u16 sramBank, u16 sramOffset, u16 length);

// Copy data from one area of PSRAM to another
extern void neo2_myth_psram_copy(DWORD dest, DWORD src, DWORD length);

// Don't call these two functions from C. The prototypes are only included so that pointers to them can
// be created
extern void neo2_recv_sd_psram_multi(WORD prbank, WORD proffs, WORD count);
extern void neo2_recv_sd_psram_multi_hwaccel(WORD prbank, WORD proffs, WORD count);


extern void neo2_recv_sd(unsigned char *buf);
extern void neo2_pre_sd();
extern void neo2_post_sd();
extern void neo2_enable_sd();
extern void neo2_disable_sd();

extern void run_game_from_gba_card();
extern void run_game_from_sd_card();

// Used for running the secondary cart (plugged in at the back of the Myth)
extern void run_secondary_cart();

extern void play_spc_from_gba_card();
extern void play_spc_from_sd_card();
extern long long play_vgm_from_sd_card();
extern void stop_vgm();
extern void vgm_echo();

extern void show_loading_progress();

//extern void inflate_start();
extern DWORD inflate(DWORD dest, DWORD src);
extern DWORD inflate_game();

#endif
