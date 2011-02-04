#ifndef __VDP_H__
#define __VDP_H__

#include <stdint.h>
#include <z80/types.h>
#include "sms.h"


enum
{
	CMD_VRAM_READ = 0,
	CMD_VRAM_WRITE = 0x40,	// Writes to the VDP data port will go to VRAM
	CMD_VDP_REG_WRITE = 0x80,
	CMD_CRAM_WRITE = 0xC0,	// Writes to the VDP data port will go to CRAM
};

enum
{
	REG_MODE_CTRL_1 = 0,
	REG_MODE_CTRL_2,
	REG_NAME_TABLE_ADDR,
	REG_COLOR_TABLE_ADDR,
	REG_BG_PATTERN_ADDR,
	REG_SAT_ADDR,
	REG_SPR_PATTERN_ADDR,
	REG_OVERSCAN_COLOR,
	REG_HSCROLL,
	REG_VSCROLL,
	REG_LINE_COUNT,
};


void vdp_set_reg(BYTE rn, BYTE val);

void vdp_set_vram_addr(WORD addr);

void vdp_set_cram_addr(WORD addr);

void vdp_copy_to_vram(WORD dest, BYTE *src, WORD len);


#endif
