#ifndef __SHARED_H__
#define __SHARED_H__

#include <z80/types.h>

#define NUMBER_OF_GAMES_TO_SHOW 9

typedef struct
{
    WORD firstShown;
    WORD highlighted;
    WORD count;
} FileList;



enum
{
    TASK_LOAD_BG,
};


extern FileList games;
extern BYTE region;
extern BYTE pad, padLast;

extern BYTE idLo,idHi;

#ifdef EMULATOR
extern const char dummyGameList[];
#endif

extern const BYTE *gbacGameList;

#endif