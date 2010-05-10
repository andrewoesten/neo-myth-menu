#include "cheats/cheat.h"


#define NCHEATS(c)	(sizeof(c)/sizeof(cheat_t))


const short testconst[] = {1,2,3,4,5,6,7,8};


const cheat_t captain_america_and_the_avengers_u_cheats[] =
{
	{"7E16A820", "Invincibility (Player 1)", CODE_TYPE_AR},
	{"7E16A963", "Invincibility (Player 2)", CODE_TYPE_AR},
	{"7E022663", "Infinite health (Player 1)", CODE_TYPE_AR},
	{"7E022763", "Infinite health (Player 2)", CODE_TYPE_AR},
	{"7E0225FF", "Infinite lives (Player 1)", CODE_TYPE_AR},
	{"7E0227FF", "Infinite lives (Player 2)", CODE_TYPE_AR},
};


const cheat_t contra_3_u_cheats[] =
{
  	{"7E1F88FF", "Invincibility", CODE_TYPE_AR},
    {"7E1F8A64", "Infinite lives", CODE_TYPE_AR},
    {"7E1F8C09", "Infinite bombs", CODE_TYPE_AR},
    {"2264D760", "Unlimited bombs on side-view levels", CODE_TYPE_GG},
    {"22B80766", "Unlimited bombs on top-view levels", CODE_TYPE_GG},
    {"7E1F8400", "Player 1 always has normal gun", CODE_TYPE_AR},
    {"7E1F8401", "Player 1 always has S gun", CODE_TYPE_AR},
    {"7E1F8402", "Player 1 always has C gun", CODE_TYPE_AR},
    {"7E1F8403", "Player 1 always has H gun", CODE_TYPE_AR},
    {"7E1F8404", "Player 1 always has F gun", CODE_TYPE_AR},
    {"7E1F8405", "Player 1 always has L gun", CODE_TYPE_AR},
    {"7E1F8600", "Player 2 always has normal gun", CODE_TYPE_AR},
    {"7E1F8601", "Player 2 always has S gun", CODE_TYPE_AR},
    {"7E1F8602", "Player 2 always has C gun", CODE_TYPE_AR},
    {"7E1F8603", "Player 2 always has H gun", CODE_TYPE_AR},
    {"7E1F8604", "Player 2 always has F gun", CODE_TYPE_AR},
    {"7E1F8605", "Player 2 always has L gun", CODE_TYPE_AR},
    {"7E09C6FF", "Eternal tank", CODE_TYPE_AR},
    {"598B2235", "Keep gun after losing life", CODE_TYPE_GG},
    {"6986AD01", "Less enemies on side-view levels", CODE_TYPE_GG},
};


const cheat_t megaman_x_u_cheats[] =
{
	{"7E0C1311", "Unlimited energy", CODE_TYPE_AR},
	{"9DB04F01", "Automatic rapid fire", CODE_TYPE_GG},
	{"DBBE446F", "Start with 10 lives", CODE_TYPE_GG},
	{"D58A1FBC", "Jump higher", CODE_TYPE_GG},
	{"FFA309A4DDA301D465A30104", "All enemies are defeated with 1 X-Buster hit", CODE_TYPE_GG},
};


const cheat_t super_castlevania_4_u_cheats[] =
{
	{"BBB2D4AFDDB2D7DF69B2D70F", "99 lives", CODE_TYPE_GG},
	{"BBB3D40F", "Start with 99 hearts", CODE_TYPE_GG},
	{"A6890FD7", "Unlimited ammo for most weapons", CODE_TYPE_GG},
	{"D22107D7", "Weapons keep hitting enemies until destroyed", CODE_TYPE_GG},
	{"6D6DDF06", "Stop timer", CODE_TYPE_GG},
};


const cheat_t super_ghouls_n_ghosts_u_cheats[] =
{
	{"7E02A409", "9 lives", CODE_TYPE_AR},
	{"D427640F1027646FDD2764AF", "99 lives", CODE_TYPE_GG},
	{"1025A4A9D325A7D93125A709", "Invincible", CODE_TYPE_GG},
	{"C22DDDA1", "No bouncing", CODE_TYPE_GG},
	{"DDB667FF", "Unlimited continues", CODE_TYPE_GG},
	{"D72767DFDF27670FDB27676F", "Start at mid-level 1", CODE_TYPE_GG},
	{"D02767DFDF27670FDB27676F", "Start at level 2", CODE_TYPE_GG},
	{"D92767DFDF27670FDB27676F", "Start at mid-level 2", CODE_TYPE_GG},
	{"D12767DFDF27670FDB27676F", "Start at level 3", CODE_TYPE_GG},
	{"D62767DFDF27670FDB27676F", "Start at level 4", CODE_TYPE_GG},
	{"DC2767DFDF27670FDB27676F", "Start at level 5", CODE_TYPE_GG},
	{"DA2767DFDF27670FDB27676F", "Start at level 6", CODE_TYPE_GG},
	{"D32767DFDF27670FDB27676F", "Start at level 7", CODE_TYPE_GG},
	{"A2860F01", "Stop timer", CODE_TYPE_GG},
};


const cheat_t super_mario_world_u_cheats[] =
{
   	{"DDB46F07", "Start with 1 life", CODE_TYPE_GG},
   	{"D6B46F07", "Start with 9 lives", CODE_TYPE_GG},
   	{"009E2562", "Start with 99 lives", CODE_TYPE_AR},
	{"C222D4DD","Infinite lives", CODE_TYPE_GG},

   	{"7E0DAA80", "Can't jump", CODE_TYPE_AR},
   	{"D02CAF6F", "Low jump", CODE_TYPE_GG},
   	{"D42CAF6F", "Super jump", CODE_TYPE_GG},
   	{"DF2CAF6F", "Mega jump", CODE_TYPE_GG},
   	{"3E2CAF6F", "Unlimited jumps", CODE_TYPE_GG},

   	{"7E0DC101", "Always have Yoshi", CODE_TYPE_AR},
	{"7E001900","Always Small Mario", CODE_TYPE_AR},
	{"7E001901","Always Big Mario", CODE_TYPE_AR},
	{"7E001902","Always Cape Mario", CODE_TYPE_AR},
	{"7E001903","Always Fire Mario", CODE_TYPE_AR},
   	{"009E35E6", "Start as Super Mario", CODE_TYPE_AR},
   	{"CBB76D67D4B76DA73CB76FD769B76F07",   "Start as Caped Mario", CODE_TYPE_GG},

	{"89E4AFD989C6D4DB","Invincibility (Yoshi)", CODE_TYPE_GG},
	{"7E1497FF","Invincibility (Walk Though Enemies)", CODE_TYPE_AR},
	{"7E1490FF","Invincibility (Starman Effect)", CODE_TYPE_AR},
	{"C2EC0700","Infinite flying time for Yoshi", CODE_TYPE_GG},

   	{"7E0F3099", "Fast timer", CODE_TYPE_AR},
   	{"008E2888", "Timer doesn't count down", CODE_TYPE_AR},
   	{"7E0DBF63", "Infinite coins", CODE_TYPE_AR},

   	{"00D0B6A9", "Keep powerups when you fall and die", CODE_TYPE_AR},

	{"DDC164DDDDC56DAD","Nintendo's Debug", CODE_TYPE_GG},
	{"DDA6DF07","Nintendo's Debug 2", CODE_TYPE_GG},

   	{"DFCE64A0", "Little Yoshi grows into big Yoshi after eating 1 enemy", CODE_TYPE_GG},
};


const cheat_t super_metroid_u_cheats[] =
{
	{"7E09C2DB7E09C305", "Max current energy", CODE_TYPE_AR},
	{"7E09C4DB7E09C505", "Max energy limit", CODE_TYPE_AR},
	{"7E09C6E77E09C703", "Max current missiles", CODE_TYPE_AR},
	{"7E09C8E77E09C903", "Max missile limit", CODE_TYPE_AR},
	{"7E09A400", "No armor", CODE_TYPE_AR},
	{"7E09A402", "Spring Ball", CODE_TYPE_AR},
	{"7E09A404", "Morphing Ball", CODE_TYPE_AR},
	{"7E09A407", "Varia Suit, Spring Ball & Morphing Ball", CODE_TYPE_AR},
	{"7E09A420", "Gravity Suit", CODE_TYPE_AR},
	{"7E09A422", "Spring Ball & Gravity Suit", CODE_TYPE_AR},
	{"7E09A501", "High Jump Boots", CODE_TYPE_AR},
	{"7E09A502", "Space Jump", CODE_TYPE_AR},
	{"7E09A510", "Bomb", CODE_TYPE_AR},
	{"7E09A520", "Speed Boster", CODE_TYPE_AR},
	{"7E09A533", "High Jump Boots, Space Jumps, Bomb & Speed Booster", CODE_TYPE_AR},
	{"7E09A580", "X-Ray", CODE_TYPE_AR},
	{"7E09A801", "Wave Beam", CODE_TYPE_AR},
	{"7E09A802", "Ice Beam", CODE_TYPE_AR},
	{"7E09A804", "Spazer Beam", CODE_TYPE_AR},
	{"7E09A807", "Wave, Ice and Spazer Beam", CODE_TYPE_AR},
	{"7E09A808", "Plasma Beam", CODE_TYPE_AR},
	{"7E09A80F", "All beams", CODE_TYPE_AR},
	{"7E0908FF", "Crateria fully mapped", CODE_TYPE_AR},
	{"7E0909FF", "Brinstar fully mapped", CODE_TYPE_AR},
	{"7E090AFF", "Norfair fully mapped", CODE_TYPE_AR},
	{"9097ADFF", "Run faster", CODE_TYPE_AR},
};


const cheat_t xmen_mutant_apocalypse_u_cheats[] =
{
	{"7E0C4C21", "Untouchable", CODE_TYPE_AR},
	{"33DBE407", "Infinite health", CODE_TYPE_GG},
	{"C2D18F67", "Infinite lives (training mode)", CODE_TYPE_GG},
	{"C2D75F64", "Infinite lives (mission mode)", CODE_TYPE_GG},
	{"7E0B7E08", "Infinite lives (Wolverine)", CODE_TYPE_AR},
	{"7E0B7F08", "Infinite lives (Cyclops)", CODE_TYPE_AR},
	{"7E0B8208", "Infinite lives (Beast)", CODE_TYPE_AR},
	{"7E0B8008", "Infinite lives (Psylocke)", CODE_TYPE_AR},
	{"7E0B8108", "Infinite lives (Gambit)", CODE_TYPE_AR},
	{"7E0B8901", "Use 1 button specials from practice mode in mission mode", CODE_TYPE_AR},
};



const cheatDbEntry_t cheatDatabase[] =
{
	// Super Mario World (E) (V1.1) [!]
	{0xC536, 0x3AC9, super_mario_world_u_cheats, NCHEATS(super_mario_world_u_cheats)},
	// Super Mario World (U) [!]
	{0xA0DA, 0x5F25, super_mario_world_u_cheats, NCHEATS(super_mario_world_u_cheats)},
	// Contra 3 (U)
	{0x0C3C, 0xF3C3, contra_3_u_cheats, NCHEATS(contra_3_u_cheats)},
	// Captain America And The Avengers (U)
	{0xC971, 0x368E, captain_america_and_the_avengers_u_cheats, NCHEATS(captain_america_and_the_avengers_u_cheats)},
	// X-Men - Mutant Apocalypse (U)
	{0x3807, 0xC7F8, xmen_mutant_apocalypse_u_cheats, NCHEATS(xmen_mutant_apocalypse_u_cheats)},

	{0,0,0,0}	// Terminator
};