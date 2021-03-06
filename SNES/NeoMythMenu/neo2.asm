; Various support code in assembly for the SNES Myth Menu
; Neo TeAm, 2010
; /Mic, 2010-2011

.include "hdr.asm"
.include "snes_io.inc"
.include "myth_io.inc"


.section ".text_neo2" superfree


.IFDEF EMULATOR
.DEFINE PSRAM_BANK $7f
.DEFINE PSRAM_OFFS $8000
.DEFINE PSRAM_ADDR $7f8000
.ELSE
.DEFINE PSRAM_BANK $50
.DEFINE PSRAM_OFFS $0000
.DEFINE PSRAM_ADDR $500000
.ENDIF

;;.DEFINE CART_TESTS


copy_ram_code:
	php
	rep		#$10
	sep		#$20
	; Note: it's very important that the correct labels are used here. Look in NEOSNES.SYM if you suspect that
	; the order of the sections involved has been changed by the linker.
	ldy		#$4000 ;(inflate_ram_code_end - ppu_ram_code_begin)
	ldx		#0
-:
	lda.l	$018000,x ;ppu_ram_code_begin,x
	sta.l	$7e8000,x
	inx
	dey
	bne		-
	plp
	rtl


.ends


.bank 3 slot 0
.org 0
.section "text_neo2_two"

ram_code_begin:

;===============================================================================
; Copy 1 Mbit of data from the GBA Card to PSRAM
;
; DBR is set to the source bank ($4x) so that word addressing can be used
; when reading data from the GBA Card, thus saving 1 cycle per read.
;
; Then 512 kb (64 kB) are copied at 16 bytes per iteration. The destination bank
; is then incremented by overwriting parts of the code, and then another 512 kb
; are copied.
copy_1mbit_from_gbac_to_psram:
	PHP
    SEP		#$20
    REP		#$10
    PHB        	   ; Save DBR
    LDA   	#$40   ; +$07
	LDY		#2	   ; Copy 2 * 512 kbit
MOV_512K:
    PHA
    PLB        	   ; Set DBR

    REP		#$30   ; A,16 & X,Y 16 BIT
    LDX     #$1FFE
-:
    LDA.W   $0000,X   	 	; READ GBA CARD
    STA.L   PSRAM_ADDR,X  	; WRITE PSRAM ;+$18
    LDA.W   $2000,X    		; READ GBA CARD
    STA.L   PSRAM_ADDR+$2000,X  ; WRITE PSRAM
    LDA.W   $4000,X    ; ...
    STA.L   PSRAM_ADDR+$4000,X
    LDA.W   $6000,X
    STA.L   PSRAM_ADDR+$6000,X
    LDA.W   $8000,X
    STA.L   PSRAM_ADDR+$8000,X
    LDA.W   $A000,X
    STA.L   PSRAM_ADDR+$A000,X
    LDA.W   $C000,X
    STA.L   PSRAM_ADDR+$C000,X
    LDA.W   $E000,X
    STA.L   PSRAM_ADDR+$E000,X
    DEX
    DEX
    BPL     -

	DEY
	BEQ	+
;+$51
	SEP		#$20
	LDA		#PSRAM_BANK+1		;+$54
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$18	; Increase the MSB of all the addresses above on the form $5xxxxx
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$1F	; ...
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$26
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$2D
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$34
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$3B
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$42
	STA.L	$7d0000+copy_1mbit_from_gbac_to_psram+$49

	; Increase DBR
	PHB
	PLA
	INA
	BRA	MOV_512K
+:
    PLB        	   ; Restore DBR
    PLP
    RTS


.EQU cpldJoyData $3900
.EQU cpldJoyMask $3902
.EQU cpldArEnabled $3904
.EQU cpldSlowMo	 $3905
.EQU cpldSaveTimEn $3906


; Used for running the secondary cart (plugged in at the back of the Myth)
run_3800:
	sep	#$30
    LDA     #$01                 ;
    STA.L   $C00E                ; HARD REST IO

	lda.l	resetType
	sta.l	$C050
	
    LDA     #$01                 ;
    STA.L   $C012                ; CPLD RAM ON
    STA.L   $C015                ; CPLD RAM ON

    LDA     #$FF                 ; RUN
    STA.L   MYTH_RST_IO          ; RUN

    LDA     #$0   ;#$00 0000     ;MYTH
    PHA                          ;
    PLB

    LDX     #$00                 ;0  MOVE BOOT CODE TO SRAM
-:  LDA.L   CPLD_RAM+$7D0000,X  ;0
    STA.L   $3800,X             ;0  CPLD SRAM
    INX
    BNE     -                   ;0

	ldx		#0
	ldy		#1
	lda		#<ram_cheat1
	sta		tcc__r0
	lda		#>ram_cheat1
	sta		tcc__r0+1
	lda		#$7e
	sta		tcc__r0h
	lda		#0
	sta		tcc__r0h+1
-:
	lda.l	ggCodes,x
	cmp		#2
	bne		+
	sta		[tcc__r0],y
	iny
	iny
	iny
	iny
	lda.l	ggCodes+2,x			; val
	sta		[tcc__r0],y
	iny
	iny
	lda.l	ggCodes+4,x			; offset low
	sta		[tcc__r0],y
	iny
	lda.l	ggCodes+5,x			; offset high
	sta		[tcc__r0],y
	iny
	lda.l	ggCodes+1,x			; bank
	sta		[tcc__r0],y
	iny
	iny
	bra		++
	+:
	tya
	clc
	adc		#10
	tay
++:
	txa
	clc
	adc		#14
	tax
	cpx		#8*14
	bne		-

	lda		#0
	sta.l	cpldJoyData
	sta.l	cpldJoyData+1
	sta.l	cpldJoyMask
	sta.l	cpldJoyMask+1
	sta.l	cpldSlowMo
	lda		#1
	sta.l	cpldArEnabled

    LDX     #$00                 ;0  MOVE CHEAT CODE TO SRAM
-:  LDA.L   CHEAT+$7D0000,X     ;0
    STA.L   $3E00,X             ;0  CPLD SRAM
    INX
    BNE     -                   ;0

    JMP.L   $003800
;===============================================================================
; EXT RAM  $003800~003FFF
;===============================================================================
CPLD_RAM:
    	REP	#$30        ; A,8 & X,Y 16 BIT
    	LDX    	#$0000
    	LDA    	#$0000
	; Clear RAM
-:
    	STA.L   $7E0000,X
    	INX
    	INX
    	BNE     -
    	SEP	#$20

    	LDA     #$80                 ;
    	STA.L   REG_DISPCNT
    	lda	#$00

	; Clear VRAM
	sta.l	REG_VRAM_ADDR_L
	sta.l	REG_VRAM_ADDR_H
	lda	#VRAM_WORD_ACCESS
	sta.l	REG_VRAM_INC
	ldx	#0
	lda	#0
-:
	sta.l	REG_VRAM_DATAW1
	sta.l	REG_VRAM_DATAW2
	inx
	bne	-
	sep	#$30
	
    	STA.L   REG_MDMAEN
    	STA.L   REG_HDMAEN
	STA.L   REG_NMI_TIMEN
	STA.L	REG_BG0MAP
	STA.L	REG_BG1MAP
	STA.L	REG_CHRBASE_L
	STA.L	REG_CHRBASE_H
	STA.L	REG_VRAM_INC
	STA.L	REG_VRAM_ADDR_L
	STA.L	REG_VRAM_ADDR_H
	STA.L	REG_BGCNT
	LDA	#$20
	STA.L	REG_COLDATA
	LDA	#$40
	STA.L	REG_COLDATA
	LDA	#$80
	STA.L	REG_COLDATA

    SEI
    SEC
    XCE             ; SET 65C02 MODE
    JMP     ($FFFC)	; Branch to emulation mode RESET vector


CHEAT:
	php
	rep		#$30
	pha
	phx
	phb
	
	sep		#$20
	lda		#0
	pha
	plb
	
	sei
	;lda		REG_NMI_TIMEN
	;sta		cpldSaveTimEn
	;lda		#1
	;sta		REG_NMI_TIMEN
	
	
	rep		#$20
	lda.l $4218
	cmp #$6030		; Select, Y, L, R
	bne	+
	jmp.l $3800		; reset the game
+:

;lda $4218
;sta	cpldJoyData
;	lda		cpldJoyData
;	tax
;	eor		cpldJoyMask
;	stx		cpldJoyMask
;	and		cpldJoyMask
;	sta		cpldJoyData
;	lda		cpldJoyMask
;	and		#$C04 ;D0C			; don't block Select, L, R
;	sta		cpldJoyMask

;	lda		cpldJoyData
;	and		#$D04 ;20B			; Select, L, R, A
;	cmp		#$D04 ;20B
;	bne		+
;	sep		#$20
;	lda		cpldArEnabled
;	eor		#1
;	sta		cpldArEnabled
	;beq		ram_cheats_disabled
+:

	sep		#$20
;bra slowmo_disabled
;	lda		cpldArEnabled
;	beq		ram_cheats_disabled	
ram_cheat1:
	lda		#0		;#0@+4
	beq		+
	lda		#1		;#1@+8
	sta.l	$030201	;addr@+10
+:
ram_cheat2:
	lda		#0		;#0@+14
	beq		+
	lda		#2		;#2@+18
	sta.l	$030201	;addr@+20
+:
ram_cheat3:
	lda		#0		;#0@+24
	beq		+
	lda		#3		;#3@+28
	sta.l	$030201	;addr@+30
+:
ram_cheat4:
	lda		#0		;#0@+34
	beq		+
	lda		#4		;#4@+38
	sta.l	$030201	;addr@+40
+:

ram_cheat5:
	lda		#0
	beq		+
	lda		#1
	sta.l	$030201
+:
ram_cheat6:
	lda		#0
	beq		+
	lda		#2
	sta.l	$030201
+:
ram_cheat7:
	lda		#0
	beq		+
	lda		#3
	sta.l	$030201
+:
ram_cheat8:
	lda		#0
	beq		+
	lda		#4
	sta.l	$030201
+:
ram_cheats_disabled:

bra slowmo_disabled

	rep		#$20
	lda		cpldJoyData
	and		#$E04 ;207			; Select, L, R, X
	cmp		#$E04 ;207
	bne		+
	sep		#$20
	lda		cpldSlowMo
	eor		#1
	sta		cpldSlowMo
	;beq		slowmo_disabled
+:
	sep		#$20
	lda		cpldSlowMo
	beq		slowmo_disabled
	
	; Wait one frame
-:
	lda.l	REG_RDNMI
	bmi	-
-:
	lda.l	REG_RDNMI
	bpl	-
slowmo_disabled:
	lda		cpldSaveTimEn
	;sta		REG_NMI_TIMEN	
	
	plb
	rep		#$30
	plx
	pla
	plp
branch_to_real_nmi:
	jmp.l	$000000	;addr@+85






run_secondary_cart:
	rep		#$30
	phx

	jsl		mosaic_up + $7D0000

	jsl		clear_screen

	sep		#$20
	lda		#1
	sta.l		$00c017
	lda		#$05
	sta.l		MYTH_OPTION_IO

	; Fill in the cartridge name
	ldx		#0
-:
	lda.l		$00ffc0,x
	sta.l		MS3+4,x
	inx
	cpx		#20
	bne		-

	lda		#MAP_MENU_FLASH_TO_ROM
	sta.l		MYTH_OPTION_IO

	rep		#$20
	pea		3
	jsl		print_meta_string			; Print cart name
	pla
	pea		0
	jsl		print_meta_string			; Print instructions
	pla
	pea		58
	jsl		print_meta_string			; Print instructions
	pla
	jsl		print_hw_card_rev

	; Print region and CPU/PPU1/PPU2 versions
	lda.l		REG_STAT78
	lsr		a
	lsr		a
	lsr		a
	lsr		a
	and		#1
	clc
	adc		#59
	pha
	jsl		print_meta_string
	pla
	lda.l		REG_RDNMI
	and		#3
	clc
	adc		#61
	pha
	jsl		print_meta_string
	pla
	lda.l		REG_STAT77
	and		#3
	clc
	adc		#65
	pha
	jsl		print_meta_string
	pla
	lda.l		REG_STAT78
	and		#3
	clc
	adc		#69
	pha
	jsl		print_meta_string
	pla

	jsl		update_screen

	jsl		mosaic_down + $7D0000

	; Wait until B or Y is pressed
-:
	jsl		read_joypad
	lda.b		tcc__r0
	and		#$c000
	beq		-

	lda.b		tcc__r0
	and		#$4000
	beq		+
	; Y was pressed
	lda		#0
	sep		#$20
	sta.l		$00c017
	jsl		mosaic_up + $7D0000
	rep		#$20
	jsl		clear_screen
	pea		0
	jsl		print_meta_string
	pla
	pea		75
	jsl		print_meta_string
	pla
	pea		4
	jsl		print_meta_string
	pla
	jsl		print_hw_card_rev
	jsl		print_games_list
	jsl		update_screen
	jsl		mosaic_down + $7D0000
	plx
	rtl

+:
	lda.b	tcc__r0
	and		#$8000
	beq		+
	; B was pressed
	sep		#$20
	lda		#$05
	sta.l	MYTH_OPTION_IO
	lda		#0
	sta.l	$00c017
	lda		#$05
	sta.l	MYTH_OPTION_IO
	plx
	jmp.w	run_3800 & $ffff

+:
	rep		#$30
	plx
	rtl



; Apply Game Genie / Action Replay codes to game ROM data that has been copied to PSRAM
apply_cheat_codes:
	sep		#$30
	phx
	phy
	rep		#$10			; 16-bit X/Y

	ldx		#0
	ldy		#8				; Maximum number of codes
_acc_loop:
	lda.l	ggCodes,x		; used
	cmp		#1				; Does this code apply to ROM?
	beq		_cheat_type_rom
	jmp.l	$7d0000+_next_cheat_code
_cheat_type_rom:
	lda.l	ggCodes+1,x		; bank (64kB)
	cmp		tcc__r3			; Should this gg code be applied to the lower 512 kbit that we just copied to PSRAM?
	bne		_cheat_upper_bank
	phx						; Save X
	lda		#0
	xba						; Clear high byte of A
	lda.l	ggCodes+2,x		; val
	rep		#$20
	sta		tcc__r4
	lda.l	ggCodes+4,x		; offset
	bit		#1				; Odd address?
	bne		+				; ..Yes
	tax
	lda.l	PSRAM_ADDR,x	; Read one word ($xxyy) of the game ROM that has been copied to PSRAM
	and		#$ff00			; Keep $xx00
	ora		tcc__r4			; val
	sta.l	PSRAM_ADDR,x	; Write back $xxvv, where vv comes from the game genie code
	plx						; Restore X
	bra		_next_cheat_code
+:
	dea
	tax
	lda.l	PSRAM_ADDR,x
	and		#$00ff
	xba
	ora		tcc__r4			; val
	xba
	sta.l	PSRAM_ADDR,x
	plx						; Restore X
	bra		_next_cheat_code
_cheat_upper_bank:
	sep		#$20
	dea
	cmp		tcc__r3			; Should this gg code be applied to the upper 512 kbit that we just copied to PSRAM?
	bne		_next_cheat_code
	phx						; Save X
	lda	#0
	xba						; Clear high byte of A
	lda.l	ggCodes+2,x		; val
	rep		#$20
	sta		tcc__r4
	lda.l	ggCodes+4,x		; offset
	bit		#1				; Odd address?
	bne		+				;; ..Yes
	tax
	lda.l	PSRAM_ADDR+$010000,x
	and		#$ff00
	ora		tcc__r4			; val
	sta.l	PSRAM_ADDR+$010000,x
	plx						; Restore X
	bra		_next_cheat_code
+:
	dea
	tax
	lda.l	PSRAM_ADDR+$010000,x
	and		#$00ff
	xba
	ora		tcc__r4			; val
	xba
	sta.l	PSRAM_ADDR+$010000,x
	plx						; Restore X
	bra		_next_cheat_code
_next_cheat_code:
	rep		#$20
	txa
	clc
	adc		#14
	tax
	sep		#$20
	dey
	beq		_apply_cheat_codes_done
	jmp.l	$7d0000+_acc_loop
_apply_cheat_codes_done:
	sep		#$10			; 8-bit X/Y
	ply
	plx
	rts



; Region-checking patterns found in some NTSC games - and what to replace them with
; to make them run on a PAL system.
ntsc_game_pattern0: .db $AD, $3F, $21, $29, $10			; lda $213f / and #$10
ntsc_game_pattern1: .db $AF, $3F, $21, $00, $89, $10		; lda.l $00213f / bit #$10
ntsc_game_pattern2: .db $AD, $3F, $21, $89, $10			; lda $213f / bit #$10
ntsc_game_pattern3: .db $AF, $3F, $21, $00, $29, $10		; lda.l $00213f / and #$10

; Region-checking patterns found in some PAL games - and what to replace them with
; to make them run on a NTSC system.
pal_game_pattern0: .db $AD, $3F, $21, $29, $10			; lda $213f / and #$10
pal_game_pattern1: .db $AF, $3F, $21, $00, $89, $10		; lda.l $00213f / bit #$10
pal_game_pattern2: .db $AD, $3F, $21, $89, $10			; lda $213f / bit #$10
pal_game_pattern3: .db $AF, $3F, $21, $00, $29, $10		; lda.l $00213f / and #$10


.db 0
suspect_pattern: .db 0,0,0,0,0,0,0,0,0,0


 .macro REGION_CHECK_SCAN_AND_REPLACE  ;pattern, length-1, replacementOffset, newValue1, newValue2, labelDone
	sep	#$20	; 8-bit A
	ldx	#\2
-:
	lda.l	$7d0000+suspect_pattern,x
	cmp.l	$7d0000+\1,x
	bne	++
	dex
	bpl	-
	
; The pattern matched
	ply	; PSRAM position
phy ;NEW
	tya
	ldx	#1
	and	#1
	beq	+
	dex
	dey
+:
	lda	#\4
	sta.l	$7d0000+suspect_pattern+1+\3
	lda	#\5
	sta.l	$7d0000+suspect_pattern+2+\3
	rep	#$20	; 16-bit A
	lda.l	$7d0000+suspect_pattern+\3,x
	sta.w	PSRAM_OFFS+1+\3,y	; Write to PSRAM
	lda.l	$7d0000+suspect_pattern+2+\3,x
	sta.w	PSRAM_OFFS+3+\3,y
plx ;NEW

	jmp.l	$7d0000+\6
++:
 .endm


; IN:
; tcc__r2: first PSRAM bank
; tcc__r3: Number of 64kB banks that have been copied so far
fix_region_checks:
	sep		#$30			; 8-bit A/X/Y
	phb
	phx
	phy

	lda.l	doRegionPatch
	beq		++
	dea
	bne		+
	cmp.b	tcc__r3			; make sure that ((doRegionPatch == 2) || (banksCopied == 0)) is true
	bne		++
+:
	lda.b	tcc__r2
	sta.b	tcc__r4
	jsr		_fix_region_checks
	inc.b	tcc__r4
	jsr		_fix_region_checks
++:
	sep		#$30			; 8-bit A/X/Y
	ply
	plx
	plb
	rts


_fix_region_checks:
	rep		#$10			; 16-bit X/Y
	sep		#$20			; 8-bit A

	.IFDEF EMULATOR
	lda		#PSRAM_BANK
	.ELSE
	lda.b 	tcc__r4
	.ENDIF
	pha
	plb						; DBR = $5x (PSRAM)

	lda.l	REG_STAT78
	and		#$10
	beq		_frc_ppu_is_60hz
	rep		#$30			; 16-bit A/X/Y
	ldx		#0
-:
	lda.w	PSRAM_OFFS,x
	phx		; psram position
	tay
	and		#$ff
	cmp		#$ad
	beq		_frc_possible_ntsc_pattern
	cmp		#$af
	beq		_frc_possible_ntsc_pattern
	tya
	xba
	and		#$ff
	cmp		#$ad
	beq		_frc_possible_ntsc_pattern_odd
	cmp		#$af
	beq		_frc_possible_ntsc_pattern_odd
_frc_50hz_next:
	plx		; psram position
	inx
	inx
	bne		-
	rts

_frc_ppu_is_60hz:
	rep		#$30
	ldx		#0
-:
	lda.w	PSRAM_OFFS,x
	phx			; psram position
	tay
	and		#$ff
	cmp		#$ad
	beq		_frc_possible_pal_pattern
	cmp		#$af
	beq		_frc_possible_pal_pattern
	tya
	xba
	and		#$ff
	cmp		#$ad
	beq		_frc_possible_pal_pattern_odd
	cmp		#$af
	beq		_frc_possible_pal_pattern_odd
_frc_60hz_next:
	plx		; psram position
	inx
	inx
	bne		-
	rts

_frc_possible_pal_pattern_odd:
	rep		#$30
	inx
_frc_possible_pal_pattern:
	jmp.l	$7d0000+_frc_check_for_pal_patterns

_frc_possible_ntsc_pattern_odd:
	inx
_frc_possible_ntsc_pattern:
	rep		#$30
	phx
	jsr		_frc_copy_pattern
	REGION_CHECK_SCAN_AND_REPLACE ntsc_game_pattern0,4,2,$a9,$00,_frc_50hz_next
	REGION_CHECK_SCAN_AND_REPLACE ntsc_game_pattern2,4,2,$a9,$00,_frc_50hz_next
	REGION_CHECK_SCAN_AND_REPLACE ntsc_game_pattern1,5,3,$a9,$00,_frc_50hz_next
	REGION_CHECK_SCAN_AND_REPLACE ntsc_game_pattern3,5,3,$a9,$00,_frc_50hz_next
	rep		#$30
	plx
	jmp.l	$7d0000+_frc_50hz_next

_frc_check_for_pal_patterns
	rep		#$30
	phx
	jsr		_frc_copy_pattern
	REGION_CHECK_SCAN_AND_REPLACE pal_game_pattern0,4,2,$a9,$10,_frc_60hz_next
	REGION_CHECK_SCAN_AND_REPLACE pal_game_pattern2,4,2,$a9,$10,_frc_60hz_next
	REGION_CHECK_SCAN_AND_REPLACE pal_game_pattern1,5,3,$a9,$10,_frc_60hz_next
	REGION_CHECK_SCAN_AND_REPLACE pal_game_pattern3,5,3,$a9,$10,_frc_60hz_next
	rep		#$30
	plx
	jmp.l	$7d0000+_frc_60hz_next

_frc_copy_pattern:
	; In: X=PSRAM offset where the AD/AF byte was found
	rep		#$30
	txy
	ldx		#1
	tya
	and		#1
	beq		+
	dex
	dey
+:
-:
	lda.w	PSRAM_OFFS,y
	iny
	iny
	sta.l	$7d0000+suspect_pattern-1,x
	inx
	inx
	cpx	#8
	beq	+
	cpx	#9
	beq	+
	bra	-
+:
	rts



; Updates and displays the "LOADING......(nn)" string
_show_loading_progress:
	jsr.w	_wait_nmi
	rep	#$30
	lda	#$22a3			; VRAM base address
	sta.l	REG_VRAM_ADDR_L
	sep	#$20
	plx
	phx
	lda.l	loadProgress+15
	dea
	cmp	#'0'-1			; Do we need to wrap from 0 to 9?
	bne	+
	lda.l	loadProgress+14
	dea
	sta.l	loadProgress+14
	lda	#'9'
+:
	sta.l	loadProgress+15
	ldx	#0
-:
	lda.l	loadProgress,x
	beq	+
	sta.l	REG_VRAM_DATAW1		; Write the character number
	lda	#8
	sta.l	REG_VRAM_DATAW2		; Write attributes (palette number)
	inx
	bra	-
+:
	rts

; Updates and displays the "LOADING......(nn)" string
show_loading_progress:
	php
	rep #$30
	pha
	phx
	phy
	jsr.w	_wait_nmi
	rep		#$30
	lda		#$22a3			; VRAM base address
	sta.l	REG_VRAM_ADDR_L
	sep		#$20
	plx
	phx
	lda.l	loadProgress+15
	dea
	cmp	#'0'-1			; Do we need to wrap from 0 to 9?
	bne	+
	lda.l	loadProgress+14
	dea
	sta.l	loadProgress+14
	lda	#'9'
+:
	sta.l	loadProgress+15
	ldx	#0
-:
	lda.l	loadProgress,x
	beq	+
	sta.l	REG_VRAM_DATAW1		; Write the character number
	lda	#8
	sta.l	REG_VRAM_DATAW2		; Write attributes (palette number)
	inx
	bra	-
+:
	rep		#$30
	ply
	plx
	pla
	plp
	rtl


show_debug_data:
	php
	rep #$30
	pha
	phx
	phy
	
 	jsr.w	_wait_nmi

	rep	#$30
	lda	#$22c3
	sta.l	REG_VRAM_ADDR_L
	sep	#$20
	

	ldx	#0
-:
	lda.l	pfmountbuf,x
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	clc
	adc	#'0'
	cmp	#58
	bcc	+
	clc
	adc	#7
+:
	sta.l	REG_VRAM_DATAW1
	lda	#8
	sta.l	REG_VRAM_DATAW2
	lda.l	pfmountbuf,x
	and	#15
	clc
	adc	#'0'
	cmp	#58
	bcc	+
	clc
	adc	#7
+:
	sta.l	REG_VRAM_DATAW1
	lda	#8
	sta.l	REG_VRAM_DATAW2
	inx
	cpx	#4
	bne	-

	rep		#$30
	ply
	plx
	pla
	plp
	rtl
	
	
show_copied_data:
 .DEFINE SHOWCOPYADDR $500140 ;7FF8
 .DEFINE NEO2_DEBUG 1
 .IFDEF NEO2_DEBUG
 	jsr.w	_wait_nmi
  	; Read back some of the data that has been copied to PSRAM and display
 	; it on-screen.
	rep	#$30
	lda	#$22c3
	sta.l	REG_VRAM_ADDR_L
	sep	#$20
	ldx	#0
-:
;rep #$20
	lda.l	SHOWCOPYADDR,x
;sep #$20
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	clc
	adc	#'0'
	cmp	#58
	bcc	+
	clc
	adc	#7
+:
	sta.l	REG_VRAM_DATAW1
	lda	#8
	sta.l	REG_VRAM_DATAW2
;rep #$20
	lda.l	SHOWCOPYADDR,x
;sep #$20
	and	#15
	clc
	adc	#'0'
	cmp	#58
	bcc	+
	clc
	adc	#7
+:
	sta.l	REG_VRAM_DATAW1
	lda	#8
	sta.l	REG_VRAM_DATAW2
	inx
	cpx	#7
	bne	-
	

	ldx	#0
-:
	lda.l	pfmountbuf,x
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	clc
	adc	#'0'
	cmp	#58
	bcc	+
	clc
	adc	#7
+:
	sta.l	REG_VRAM_DATAW1
	lda	#8
	sta.l	REG_VRAM_DATAW2
	lda.l	pfmountbuf,x
	and	#15
	clc
	adc	#'0'
	cmp	#58
	bcc	+
	clc
	adc	#7
+:
	sta.l	REG_VRAM_DATAW1
	lda	#8
	sta.l	REG_VRAM_DATAW2
	inx
	cpx	#4
	bne	-

 .ENDIF
	rep #$20
	rts



; Reads the 64-byte "header" (ROM title, country code, checksum etc) from the currently highlighted ROM and stores it in snesRomInfo.
;get_rom_info:
; void neo2_myth_current_rom_read(char *dest, u16 romBank, u16 romOffset, u16 length)
neo2_myth_current_rom_read:
	php
	rep		#$30
	phx
	phy
	phb

	sep		#$20
	lda.l	romAddressPins
	sta		tcc__r2h

	LDA    #$20      	; OFF A21
	STA.L  MYTH_GBAC_ZIO
	JSR    SET_NEOCMA  	;
	JSR    SET_NEOCMB  	;
	JSR    SET_NEOCMC  	; ON_NEO CARD A24 & A25 + SA16 & SA17

	LDA.L   romAddressPins+1
	STA.L   MYTH_GBAC_HIO	; SET AH25,AH25

	LDA     #$01
	STA.L   MYTH_EXTM_ON   ; A25,A24 ON

	LDA    #GBAC_TO_PSRAM_COPY_MODE
	STA.L  MYTH_OPTION_IO

	LDA    #$F8
	STA.L  MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE

	LDA.L  romAddressPins
	STA.L  MYTH_GBAC_LIO

	lda		12,s			; dest bank
	sta		tcc__r2h
	stz		tcc__r2h+1
	lda		14,s			; romBank
	clc
	adc		#$40
	pha
	plb
	rep		#$20
	lda		10,s			; dest offset
	tay
	stz		tcc__r2
	lda		16,s			; romOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b	tcc__r1
-:
	lda.w	$0000,x
	sta		[tcc__r2],y
	inx
	inx
	iny
	iny
	dec		tcc__r1
	bne		-
	
	sep	#$20

	LDA     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
	STA.L   MYTH_OPTION_IO

	LDA     #$00
	STA.L   MYTH_EXTM_ON   ; A25,A24 OFF

	LDA     #$20       	; OFF A21
	STA.L   MYTH_GBAC_ZIO
	JSR     SET_NEOCMD	; SET MENU

	LDA     #$00
	STA.L   MYTH_GBAC_LIO
	STA.L   MYTH_GBAC_HIO
	STA.L   MYTH_GBAC_ZIO

	plb
 	ply
 	plx
 	plp
	rtl


; void neo2_myth_bootcart_rom_read(char *dest, u16 romBank, u16 romOffset, u16 length);
neo2_myth_bootcart_rom_read:
	php
	rep		#$30
	phx
	phy
	phb

	sep		#$20
	lda		#1
	sta.l		$C017
	lda		#5
	sta.l		MYTH_OPTION_IO
lda		#0
sta.l		$C017

	lda		12,s			; dest bank
	sta		tcc__r2h
	stz		tcc__r2h+1
	lda		14,s			; romBank
	;clc
	;adc		#$80			
	pha
	plb
	rep		#$20
	lda		10,s			; dest offset
	tay
	stz		tcc__r2
	lda		16,s			; romOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b		tcc__r1
-:
	lda.w		$0000,x
	sta		[tcc__r2],y
	inx
	inx
	iny
	iny
	dec		tcc__r1
	bne		-
	
	sep		#$20

	lda		#MAP_MENU_FLASH_TO_ROM 
	sta.l		MYTH_OPTION_IO
	lda		#0
	sta.l		$C017

	plb
 	ply
 	plx
 	plp
	rtl
	

; void neo2_myth_psram_read(char *dest, u16 psramBank, u16 psramOffset, u16 length)
neo2_myth_psram_read:
	php
	rep		#$30
	phx
	phy
	phb

	lda		14,s		; psramBank
	tax
	lsr		a
	lsr		a
	lsr		a
	lsr		a
	sep		#$20
	pha

	LDA    #$20      		; OFF A21
	STA.L  MYTH_GBAC_ZIO
	JSR    SET_NEOCMA  		;
	JSR    SET_NEOCMB  		;
	JSR    SET_NEOCMC  		; ON_NEO CARD A24 & A25 + SA16 & SA17
	LDA    #$01
	STA.L  MYTH_EXTM_ON  	; A25,A24 ON
	LDA    #$04       		; COPY MODE !
	STA.L  MYTH_OPTION_IO
	LDA    #$01       		; PSRAM WE ON !
	STA.L  MYTH_WE_IO
	LDA    #$F8
	STA.L  MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
	STA.L  MYTH_PRAM_ZIO  	; PSRAM    8M SIZE
	pla
	STA.L  MYTH_PRAM_BIO

	;jsr		show_copied_data
	;sep		#$20
	
	lda		12,s			; dest bank
	pha
	plb
	txa						; psramBank lower 8 bits
	and		#$0F
	ora		#$50
	sta.l	$7d0000+_ncfmp_read+3

	rep		#$20
	lda		16,s			; psramOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b	tcc__r4
	lda		10,s			; dest offset
	tay
_ncfmp_read:
	lda.l	PSRAM_ADDR,x
	sta.w	$0000,y
	inx
	inx
	iny
	iny
	dec		tcc__r4
	bne		_ncfmp_read

	;sep		#$20
    ;lda     #$00       ;
    ;sta.l   MYTH_WE_IO     ; PSRAM WRITE OFF
	;lda     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
	;sta.l   MYTH_OPTION_IO
	;lda     #$00
	;sta.l   MYTH_EXTM_ON   ; A25,A24 OFF

  	sep		#$20
    LDA     #$00       ;
    STA.L   MYTH_WE_IO     ; PSRAM WRITE OFF
    LDA     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
    STA.L   MYTH_OPTION_IO
    LDA     #$20       		; OFF A21
    STA.L   MYTH_GBAC_ZIO
    JSR     SET_NEOCMD		; SET MENU
    LDA     #$00
    STA.L   MYTH_GBAC_LIO
    STA.L   MYTH_GBAC_HIO
    STA.L   MYTH_GBAC_ZIO
    
    lda.l	sourceMedium
    beq		+
    jsr		neo2_enable_sd
+:

 	plb
 	ply
 	plx
 	plp
	rtl


; void neo2_myth_psram_write(char *src, u16 psramBank, u16 psramOffset, u16 length)
neo2_myth_psram_write:
	php
	rep		#$30
	phx
	phy
	phb

	lda		14,s		; psramBank
	tax
	lsr		a
	lsr		a
	lsr		a
	lsr		a
	sep		#$20
	pha

 	LDA    #$20      		; OFF A21
	STA.L  MYTH_GBAC_ZIO
	JSR    SET_NEOCMA  		;
	JSR    SET_NEOCMB  		;
	JSR    SET_NEOCMC  		; ON_NEO CARD A24 & A25 + SA16 & SA17
	LDA    #$01
	STA.L  MYTH_EXTM_ON  	; A25,A24 ON
	LDA    #$04       		; COPY MODE !
	STA.L  MYTH_OPTION_IO
	LDA    #$01       		; PSRAM WE ON !
	STA.L  MYTH_WE_IO
	LDA    #$F8
	STA.L  MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
	STA.L  MYTH_PRAM_ZIO  	; PSRAM    8M SIZE
	pla
	STA.L  MYTH_PRAM_BIO
	
	lda		12,s			; src bank
	pha
	plb
	txa						; psramBank lower 8 bits
	and		#$0F
	ora		#$50
	sta.l	$7d0000+_nctmp_write+3

	rep		#$20
	lda		16,s			; psramOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b	tcc__r4
	lda		10,s			; src offset
	tay
-:
	lda.w	$0000,y
_nctmp_write:
	sta.l	PSRAM_ADDR,x
	inx
	inx
	iny
	iny
	dec		tcc__r4
	bne		-


  	sep		#$20
    LDA     #$00       ;
    STA.L   MYTH_WE_IO     ; PSRAM WRITE OFF
    LDA     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
    STA.L   MYTH_OPTION_IO
    LDA     #$20       		; OFF A21
    STA.L   MYTH_GBAC_ZIO
    JSR     SET_NEOCMD		; SET MENU
    LDA     #$00
    STA.L   MYTH_GBAC_LIO
    STA.L   MYTH_GBAC_HIO
    STA.L   MYTH_GBAC_ZIO

    lda.l	sourceMedium
    beq		+
    jsr		neo2_enable_sd
+:
    
 	plb
 	ply
 	plx
 	plp
	rtl


; void neo2_myth_psram_write_test_data(char *src, u16 psramBank, u16 psramOffset, u16 length)
neo2_myth_psram_write_test_data:
.IFDEF CART_TESTS
	php
	rep		#$30
	phx
	phy
	phb

	lda		14,s		; psramBank
	tax
	lsr		a
	lsr		a
	lsr		a
	lsr		a
	sep		#$20
	pha

	LDA    		#$20      		; OFF A21
	STA.L  		MYTH_GBAC_ZIO
	JSR    		SET_NEOCMA  		;
	JSR    		SET_NEOCMB  		;
	JSR    		SET_NEOCMC  		; ON_NEO CARD A24 & A25 + SA16 & SA17
	LDA    		#$01
	STA.L  		MYTH_EXTM_ON  	; A25,A24 ON
	LDA    		#$04       		; COPY MODE !
	STA.L  		MYTH_OPTION_IO
	LDA    		#$01       		; PSRAM WE ON !
	STA.L  		MYTH_WE_IO
	LDA    		#$F8
	STA.L  		MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
	STA.L  		MYTH_PRAM_ZIO  	; PSRAM    8M SIZE
	pla		
	STA.L  		MYTH_PRAM_BIO
	
	txa						; psramBank lower 8 bits
	and		#$0F
	ora		#$50
	sta.l		$7d0000+_psram_testdata_write+3
	sta.b		tcc__r0
	stz		tcc__r0+1
	
	rep		#$20
	lda		16,s			; psramOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b		tcc__r4
	lda		10,s			; src offset
	tay
-:
	txa	
	clc
	adc		tcc__r0
_psram_testdata_write:
	sta.l		PSRAM_ADDR,x
	inx
	inx
	iny
	iny
	dec		tcc__r4
	bne		-

  	sep		#$20
    	LDA     #$00       ;
    	STA.L   MYTH_WE_IO     ; PSRAM WRITE OFF
    	LDA     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
    	STA.L   MYTH_OPTION_IO
    	LDA     #$20       		; OFF A21
    	STA.L   MYTH_GBAC_ZIO
    	JSR     SET_NEOCMD		; SET MENU
    	LDA     #$00
    	STA.L   MYTH_GBAC_LIO
    	STA.L   MYTH_GBAC_HIO
    	STA.L   MYTH_GBAC_ZIO

    	lda.l	sourceMedium
    	beq	+
    	jsr	neo2_enable_sd
+:
    
 	plb
 	ply
 	plx
 	plp
 .ENDIF
	rtl


; void neo2_gbac_psram_write_test_data(char *src, u16 psramBank, u16 psramOffset, u16 length)
neo2_gbac_psram_write_test_data:
.IFDEF CART_TESTS
    	php
    	rep     	#$30
    	phx
    	phy
	phb

	lda		14,s		; psramBank
	sta	tcc__r0		; r0 = bank
	tax			; x = bank
	;lsr		a
	;lsr		a
	;lsr		a
	;lsr 		a
	and #$F0
	lsr a
	sep		#$20
	pha
	
    	jsr     	_neo_select_psram
    	sep		#$20
    	lda    		#$F8
    	sta.l  		MYTH_PRAM_ZIO	; PSRAM 8M SIZE
	LDA    		#GBAC_TO_PSRAM_COPY_MODE
	STA.L  		MYTH_OPTION_IO
	lda 		#1
	sta.l 		MYTH_WE_IO
	lda		#0
	sta.l		MYTH_PRAM_BIO
	
	LDA    		#$F8
	STA.L  		MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
	pla
	STA.L  		MYTH_GBAC_LIO
	
	txa						; psramBank lower 8 bits
	and		#$0F
	ora		#$40
	sta.l		$7d0000+_gbac_psram_testdata_write+3
	
	rep		#$20
	lda		16,s			; psramOffset
	tax
lsr a
clc
adc tcc__r0
sta tcc__r0
	lda		18,s			; length
	lsr		a
	sta.b		tcc__r4
	lda		10,s			; src offset
	tay
-:
	lda		tcc__r0
_gbac_psram_testdata_write:
	sta.l		$400000,x
	inc		tcc__r0
	inx
	inx
	iny
	iny
	dec		tcc__r4
	bne		-

	sep		#$20
  	ldx		#$00E2
  	ldy		#$D200
	jsr		_neo_asic_cmd	
    	jsr		_neo_select_menu
    	jsr		neo2_post_sd
    	rep		#$30
    	
 	plb
 	ply
 	plx
 	plp
 .ENDIF
	rtl
    
    
; void neo2_gbac_psram_read(char *dest, u16 psramBank, u16 psramOffset, u16 length)
neo2_gbac_psram_read:
.IFDEF CART_TESTS
	php
	rep		#$30
	phx
	phy
	phb

	lda		14,s		; psramBank
	tax
	;lsr		a
	;lsr		a
	;lsr		a
	;lsr 		a
	and #$F0
	lsr a
	sep		#$20
	pha

    	jsr     	_neo_select_psram
    	sep		#$20
    	lda    		#$F0
    	sta.l  		MYTH_PRAM_ZIO	; PSRAM 8M SIZE
	LDA    		#GBAC_TO_PSRAM_COPY_MODE
	STA.L  		MYTH_OPTION_IO
	lda 		#1
	sta.l 		MYTH_WE_IO
	lda		#0
	sta.l		MYTH_PRAM_BIO
	LDA    		#$F8
	STA.L  		MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
	pla		
	STA.L  		MYTH_GBAC_LIO	; LIO = bank>>4
	
 	
	lda		12,s			; dest bank
	pha
	plb
	txa					; psramBank lower 8 bits
	and		#$0F
	ora		#$40
	sta.l		$7d0000+neo2_gbac_psram_read_op+3

	rep		#$20
	lda		16,s			; psramOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b		tcc__r4
	lda		10,s			; dest offset
	tay
neo2_gbac_psram_read_op:
	lda.l		$400000,x
	sta.w		$0000,y
	inx
	inx
	iny
	iny
	dec		tcc__r4
	bne		neo2_gbac_psram_read_op

	sep		#$20
  	ldx		#$00E2
  	ldy		#$D200
	jsr		_neo_asic_cmd	
    	jsr		_neo_select_menu
    	jsr		neo2_post_sd
    	rep		#$30
    	
 	plb
 	ply
 	plx
 	plp
 .ENDIF
	rtl



neo2_enable_id:
	sep	#$20
	rep	#$10
	
	lda	#0
	sta.l	MYTH_OPTION_IO	; set mode 0
	lda	#$20
	sta.l	MYTH_GBAC_ZIO	; A21 off
	
 	ldx	#$00E2		; GBA WE on
 	ldy	#$1500	
	jsr	_neo_asic_cmd	
 	ldx	#$0037		; Select menu flash
 	ldy	#$2003
	jsr	_neo_asic_cmd	
 	ldx	#$00EE		; Enable extended address bus
 	ldy	#$0630
	jsr	_neo_asic_cmd	

 	ldx	#$0090		; Enable ID
 	ldy	#$3500
	jsr	_neo_asic_cmd	

        lda     #$00
        sta.l   MYTH_GBAC_ZIO   ; SET A16~A23
        sta.l   MYTH_GBAC_HIO   ; SET A24,A25
        lda     #$01
        sta.l   MYTH_EXTM_ON   	; A25,A24 ON
        lda     #$04
        sta.l   MYTH_SRAM_TYPE  ; SET SRAM SAVE TYPE
        lda     #$0F
        sta.l   MYTH_SRAM_MAP  	; Map SRAM to $700000
        lda     #$01
        sta.l   MYTH_SRAM_WE  ; SRAM ON !  
	rts
	

neo2_disable_id:
	sep 	#$20
	rep	#$10

	lda	#0
	sta.l	MYTH_OPTION_IO				; set mode 0
	lda	#$20
	sta.l	MYTH_GBAC_ZIO	
	
 	ldx	#$0090
 	ldy	#$4900
	jsr	_neo_asic_cmd	

	lda 	#0
        sta.l 	MYTH_SRAM_TYPE
        sta.l 	MYTH_SRAM_TYPE
        sta.l   MYTH_SRAM_WE
         
    	jsr	_neo_select_menu
    	jsr	neo2_post_sd
    	rts


; u16 neo2_read_id()
neo2_read_id:
	php
	rep	#$30
	phx
	phy
	lda	#0
	sta	tcc__r0
	jsr	neo2_enable_id
	sep	#$20
	; Check signature
	ldx	#0
	lda.l	$700000,x
	cmp	#$34
	bne	+
	inx
	lda.l	$700000,x
	cmp	#$16
	bne	+
	inx
	lda.l	$700000,x
	cmp	#$96
	bne	+
	inx
	lda.l	$700000,x
	cmp	#$24
	bne	+
	lda	#1
	sta	tcc__r0
	; Check cart type
	lda.l	$708001
	bpl	++
	lda	#2	; Neo2
	sta	tcc__r0+1
	bra	+
++:
	lda.l	$708080
	bpl	+
	lda	#3	; Neo3
	sta	tcc__r0+1
+:
	sep 	#$10
	stx 	tcc__r0
	rep 	#$10
	jsr	neo2_disable_id
	rep	#$30
	ply
	plx
	plp
	rtl
	
	  
         
; void neo2_sram_read(char *dest, u16 sramBank, u16 sramOffset, u16 length)
neo2_sram_read:
	php
	rep		#$30
	phx
	phy
	phb

	lda		14,s		; sramBank
	sep		#$20
	and		#$03
	ora		#$70
	sta.l		$7d0000+neo2_sram_read_op+3
	

        LDA    	#$20      ; OFF A21
        STA.L	MYTH_GBAC_ZIO

        JSR    	SET_NEOCMC  ; ON_NEO CARD A24 & A25 + SA16 & SA17

        LDA    #$20      ; OFF A21
        STA    MYTH_GBAC_ZIO
        LDA     #$00
        STA.L   MYTH_GBAC_ZIO   ; SET A16~A23
        STA.L   MYTH_GBAC_HIO   ; SET A24,A25
        LDA     #$01
        STA.L   MYTH_EXTM_ON   ; A25,A24 ON
        LDA     #$04
        STA.L   MYTH_SRAM_TYPE  ; SET SRAM SAVE TYPE
        LDA     #$0F
        STA.L   MYTH_SRAM_MAP  ; SET $700000
        LDA     #$01
        STA.L   MYTH_SRAM_WE  ; SRAM ON !  	
 
 	lda		12,s			; dest bank
 	pha
	plb
	
	rep		#$20
	lda		16,s			; sramOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b		tcc__r4
	lda		10,s			; dest offset
	tay
neo2_sram_read_op:
	lda.l		$700000,x
	sta.w		$0000,y
	inx
	inx
	iny
	iny
	dec		tcc__r4
	bne		neo2_sram_read_op

	SEP #$20
	LDA #0
        STA.L    MYTH_SRAM_TYPE
        STA.L    MYTH_SRAM_TYPE
        STA.L    MYTH_SRAM_WE
         
    	jsr		_neo_select_menu
    	jsr		neo2_post_sd
    	rep		#$30
    	
 	plb
 	ply
 	plx
 	plp
	rtl
	

; void neo2_sram_write(char *src, u16 sramBank, u16 sramOffset, u16 length)
neo2_sram_write:
	php
	rep		#$30
	phx
	phy
	phb

	lda		14,s		; sramBank
	sep		#$20
	and		#$03
	ora		#$70
	sta.l		$7d0000+neo2_sram_write_op+3
	

        LDA    	#$20      ; OFF A21
        STA.L	MYTH_GBAC_ZIO

        JSR    	SET_NEOCMC  ; ON_NEO CARD A24 & A25 + SA16 & SA17

        LDA    #$20      ; OFF A21
        STA    MYTH_GBAC_ZIO
        LDA     #$00
        STA.L   MYTH_GBAC_ZIO   ; SET A16~A23
        STA.L   MYTH_GBAC_HIO   ; SET A24,A25
        LDA     #$01
        STA.L   MYTH_EXTM_ON   ; A25,A24 ON
        LDA     #$04
        STA.L   MYTH_SRAM_TYPE  ; SET SRAM SAVE TYPE
        LDA     #$0F
        STA.L   MYTH_SRAM_MAP  ; SET $700000
        LDA     #$01
        STA.L   MYTH_SRAM_WE  ; SRAM ON !  	
 
 	lda		12,s			; src bank
 	pha
	plb
	
	rep		#$20
	lda		16,s			; sramOffset
	tax
	lda		18,s			; length
	lsr		a
	sta.b		tcc__r4
	lda		10,s			; src offset
	tay
-:
	lda.w		$0000,y
neo2_sram_write_op:
	sta.l		$700000,x
	inx
	inx
	iny
	iny
	dec		tcc__r4
	bne		-

	SEP #$20
	LDA #0
        STA.L    MYTH_SRAM_TYPE
        STA.L    MYTH_SRAM_TYPE
        STA.L    MYTH_SRAM_WE
         
    	jsr		_neo_select_menu
    	jsr		neo2_post_sd
    	rep		#$30
    	
 	plb
 	ply
 	plx
 	plp
	rtl
	
	
	
        
; void neo2_myth_psram_copy(DWORD dest, DWORD src, DWORD length)
;
.EQU _neo2_myth_psram_copy_save_regs 5
.EQU _neo2_myth_psram_copy_dest 4+_neo2_myth_psram_copy_save_regs
.EQU _neo2_myth_psram_copy_src _neo2_myth_psram_copy_dest+4
.EQU _neo2_myth_psram_copy_length _neo2_myth_psram_copy_src+4
;
neo2_myth_psram_copy:
	php
	rep		#$20
	phx
	phy

 	sep		#$20
    LDA    #$20      	; OFF A21
    STA.L  MYTH_GBAC_ZIO
    JSR    SET_NEOCMA  	;
    JSR    SET_NEOCMB  	;
    JSR    SET_NEOCMC  	; ON_NEO CARD A24 & A25 + SA16 & SA17

    LDA     #$01
    STA.L   MYTH_EXTM_ON   ; A25,A24 ON

	LDA    #$04       	; COPY MODE !
    STA.L  MYTH_OPTION_IO

    LDA    #$01       	; PSRAM WE ON !
    STA.L  MYTH_WE_IO
                         
    LDA    #$F8
    STA.L  MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
    STA.L  MYTH_PRAM_ZIO  	; PSRAM    8M SIZE
         
    rep		#$20
    lda		_neo2_myth_psram_copy_src+2,s
    sec
    sbc		#$50		; PSRAM starts at $500000
	lsr		a
	lsr		a
	lsr		a
	lsr		a
	and		#7
	sta		tcc__r0		; src PRAM_BIO
	lda		_neo2_myth_psram_copy_src+2,s
	and		#$0F
	ora		#$50
	sta		tcc__r2h
	lda		_neo2_myth_psram_copy_src,s
	sta		tcc__r2
	
    lda		_neo2_myth_psram_copy_dest+2,s
    sec
    sbc		#$50		; PSRAM starts at $500000
	lsr		a
	lsr		a
	lsr		a
	lsr		a
	and		#7
	sta		tcc__r0h	; dest PRAM_BIO
	lda		_neo2_myth_psram_copy_dest+2,s
	and		#$0F
	ora		#$50
	sta		tcc__r10h
	lda		_neo2_myth_psram_copy_dest,s
	sta		tcc__r10
	
	lda		_neo2_myth_psram_copy_length+2,s
	;lsr		a
	sta		tcc__r1h
	lda		_neo2_myth_psram_copy_length,s
	;ror		a
	sta		tcc__r1

_neo2_myth_psram_copy_banks:
	sep		#$20
	lda		tcc__r0
	sta.l	MYTH_PRAM_BIO
	phb
	lda		tcc__r2h
	pha
	plb
	ldx		#$7FFE
	rep		#$20
	; Copy 32kB from PSRAM to RAM
-:
	lda.w	$0000,x
	sta.l	$7F4000,x
	dex
	dex
	bpl		-
	sep		#$20
	lda		tcc__r0h
	sta.l	MYTH_PRAM_BIO
	lda		tcc__r10h
	pha
	plb
	ldx		#$7FFE
	rep		#$20
	; Copy 32kB from RAM to PSRAM
-:
	lda.l	$7F4000,x
	sta.w	$0000,x
	dex
	dex
	bpl		-
	
	sep		#$20
	lda		tcc__r0
	sta.l	MYTH_PRAM_BIO
	;phb
	lda		tcc__r2h
	pha
	plb
	ldx		#$7FFE
	rep		#$20
	; Copy 32kB from PSRAM to RAM
-:
	lda.w	$8000,x
	sta.l	$7F4000,x
	dex
	dex
	bpl		-
	sep		#$20
	lda		tcc__r0h
	sta.l	MYTH_PRAM_BIO
	lda		tcc__r10h
	pha
	plb
	ldx		#$7FFE
	rep		#$20
	; Copy 32kB from RAM to PSRAM
-:
	lda.l	$7F4000,x
	sta.w	$8000,x
	dex
	dex
	bpl		-
	
	plb

	inc		tcc__r2h
	inc		tcc__r10h
	dec		tcc__r1h
	bne		_neo2_myth_psram_copy_banks
	
	sep		#$20
    LDA     #$00       ;
    STA.L   MYTH_WE_IO     ; PSRAM WRITE OFF

    LDA     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
    STA.L   MYTH_OPTION_IO

    LDA     #$20       	; OFF A21
    STA.L   MYTH_GBAC_ZIO
    JSR     SET_NEOCMD	; SET MENU

    LDA     #$00
    STA.L   MYTH_GBAC_LIO
    STA.L   MYTH_GBAC_HIO
    STA.L   MYTH_GBAC_ZIO
    
    rep		#$30
    ply
    plx
    plp
    rtl
    
    

 .MACRO MOV_PSRAM_SETUP
        LDA.L  romSize
        CMP    #\1
        BNE    +
        LDA    #\2
        STA    tcc__r0

        LDA    #<\3
        STA    tcc__r0+1
        LDA    #>\3
        STA    tcc__r0h

        LDA    #\4
        STA    tcc__r0h+1

        LDA    #\5
        STA    tcc__r1
        JMP    MOV_PSRAM
	+:
 .ENDM


 .MACRO MAP_SRAM_CHECK
 	 CMP     #\1
         BNE     +
         STA.L   MYTH_SRAM_TYPE  ; SET SRAM SAVE TYPE
         LDA     #\2
         STA.L   MYTH_SRAM_MAP   ; SET $206000
         JMP     \3
	 +:
 .ENDM

.8bit
.accu 8
SET_NEOCM5:
         LDA    #$E0      	; SET BANK   ;1 1 1 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $FFA400  	; FFD2XX     ;01

         LDA    #$00      	; SET BANK   ; 0 0 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $C02A00  	; 0015XX     ;02
         LDA.L  $C3A400  	; 01D2XX     ;03
         LDA.L  $C42A00  	; 0215XX     ;04

         LDA    #$E0      	; SET BANK   ;1 1 1 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $FC2A00  	; FE15XX     ;05
         RTS
;===============================================================================
SET_NEOCMA:
         JSR    SET_NEOCM5
         LDA    #$20      	; SET BANK   ;0 0 1 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $EE2406  	; 372203     ;06   ;
         RTS
;===============================================================================
SET_NEOCMB:
         JSR    SET_NEOCM5

         LDA.L  cardModel
         CMP    #$00
         BEQ    A_CARD
         CMP    #$01
         BEQ    B_CARD
         JMP    C_CARD
;-------------------------------------------------------------------------------
A_CARD:
         LDA    #$C0      	; SET    ;1 1 0 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $F55C88  	; DAAE44     ;06
         RTS
;-------------------------------------------------------------------------------
B_CARD:
         LDA    #$C0      	; SET    ;1 1 0 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $F51C88  	; DA8E44     ;06
         RTS
;-------------------------------------------------------------------------------
C_CARD:
         LDA    #$C0      	; SET    ;1 1 0 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $F41C88  	; DA0E44     ;06
         RTS
;===============================================================================
SET_NEOCMC:
         JSR    SET_NEOCM5

         LDA    #$E0      	; SET        ;1 1 1 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $DC0C60  	; EE0630     ;06
         RTS
;===============================================================================
SET_NEOCMD:

         JSR    SET_NEOCM5
         LDA    #$20      	; SET BANK   ;0 0 1 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $EE2006  	; 372003     ;06   ;  TO BIOS MENU

         JSR    SET_NEOCM5
         LDA    #$C0      	; SET        ;1 1 0 0
         STA.L  MYTH_GBAC_LIO
         LDA.L  $F50088  	; DA0044     ;06
         RTS
;===============================================================================


run_game_from_gba_card:
	jsl	clear_status_window
	jsl	update_screen

	sep	#$20

	lda	#$7e
	pha
	plb

	lda.l	romAddressPins
	sta	tcc__r2h

	 LDA    #$20      	; OFF A21
	 STA.L  MYTH_GBAC_ZIO
	 JSR    SET_NEOCMA  	;
	 JSR    SET_NEOCMB  	;
	 JSR    SET_NEOCMC  	; ON_NEO CARD A24 & A25 + SA16 & SA17

	 LDA.L   romAddressPins+1
	 STA.L   MYTH_GBAC_HIO	; SET AH25,AH25

	 LDA     #$01
	 STA.L   MYTH_EXTM_ON   ; A25,A24 ON


; MOVE   PSRAM
MOV_4M:

	;                    4M    4M    4M  4M~8M
	MOV_PSRAM_SETUP $04, $3C, $3035, $04, $00
	;                    8M    8M    8M  4M~8M
	MOV_PSRAM_SETUP $08, $38, $3039, $08, $00
	;                    16M   16M   8M   16M
	MOV_PSRAM_SETUP $09, $30, $3137, $08, $01
	;                    32M   24M   8M   24M
	MOV_PSRAM_SETUP $0A, $20, $3235, $08, $02
	;                    32M   32M   8M   32M
	MOV_PSRAM_SETUP $0B, $20, $3333, $08, $03
	;                    64M   40M   8M   40M
	MOV_PSRAM_SETUP $0C, $00, $3431, $08, $04
	;                    64M   48M   8M   48M
	MOV_PSRAM_SETUP $0D, $00, $3439, $08, $05
	;                    64M   64M   8M   64M
	MOV_PSRAM_SETUP $0E, $00, $3635, $08, $07

;===============================================================================
MOV_PSRAM:
	lda	tcc__r0+1
	sta.l	loadProgress+15
	lda	tcc__r0h
	sta.l	loadProgress+14

	 LDA    #$00
	 STA    tcc__r1+1
	 sta	tcc__r3

	 LDA    #GBAC_TO_PSRAM_COPY_MODE
	 STA.L  MYTH_OPTION_IO

	 LDA    #$01       	; PSRAM WE ON !
	 STA.L  MYTH_WE_IO

	 LDA    #$F8
	 STA.L  MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
	 STA.L  MYTH_PRAM_ZIO  	; PSRAM    8M SIZE

	 LDA.L  romAddressPins
	 STA.L  MYTH_GBAC_LIO

	 LDA    #$00
	 STA.L  MYTH_PRAM_BIO

MOV_PSRAM_LOOP:
	 LDA    #$3E
	 STA    tcc__r1h
	 LDA    #PSRAM_BANK-2
	 STA    tcc__r2

	 LDA    #$3F
	 STA    tcc__r1h+1

	 LDA    #PSRAM_BANK-1
	 STA    tcc__r2+1

-:
	 INC    tcc__r1h
	 INC    tcc__r2
	 INC    tcc__r2+1

	 INC    tcc__r1h
	 INC    tcc__r2
	 INC    tcc__r2+1

	 jsr	_show_loading_progress

	 LDA	tcc__r1h
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$07

         LDA    tcc__r2
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$18	; First bank to write to
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$1f	; ...
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$26
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$2d
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$34
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$3b
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$42
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$49
	 ina
	 sta.l	$7d0000+copy_1mbit_from_gbac_to_psram+$54

	 DEC    tcc__r0+1
	 LDA    tcc__r0+1        ; L-BYTE
	 LDA    tcc__r0h        ; H-BYTE

	 jsr	copy_1mbit_from_gbac_to_psram

	; lda.l	doRegionPatch
	; beq	+
	; lda	#$50
	; sta	tcc__r4
	 jsr	fix_region_checks
	; lda	#$51
	; sta	tcc__r4
	; jsr	fix_region_checks
	; +:

	; Replace the NMI vector with the cheat routine if needed
	 lda	tcc__r3
	 bne	+
	 lda.l	anyRamCheats
	 beq	+
	 lda.l	romRunMode
	 bne	patch_nmi_lorom
	 rep	#$20
	 lda.l	$50ffea
	 sta.l	$7d0000+branch_to_real_nmi+1
	 lda	#$3e00
	 sta.l	$50ffea		; Native mode vector
	 sep	#$20
	 bra	+
	 patch_nmi_lorom:
	 rep	#$20
	 lda.l	$507fea
	 sta.l	$7d0000+branch_to_real_nmi+1
	 lda	#$3e00
	 sta.l	$507fea		; Native mode vector
	 sep	#$20
	 +:

	 jsr	apply_cheat_codes
	 inc	tcc__r3
	 inc	tcc__r3

;	 jsr	show_copied_data

	 DEC    tcc__r0h+1
	 BEQ	+
	 JMP    -
	 +:

	 LDA    tcc__r1
	 CMP    tcc__r1+1
	 BNE    MOV_PSRAM_1
	 JMP    MOV_PSRAM_DONE
MOV_PSRAM_1:
;===============================================================================
	 INC    tcc__r1+1
	 LDA    tcc__r1+1
	 CMP    #$01
	 BNE    +

	 LDA    #$01        ;16M
	 STA.L  MYTH_PRAM_BIO

	 CLC
	 LDA    #$08
	 ADC    tcc__r2h
	 STA    tcc__r2h
	 STA.L  MYTH_GBAC_LIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:       CMP    #$02        ;24M
	 BNE    +
	 LDA    #$02
	 STA.L  MYTH_PRAM_BIO

	 CLC
	 LDA    #$08
	 ADC    tcc__r2h
	 STA    tcc__r2h
	 STA.L  MYTH_GBAC_LIO

	 LDA    #$8
	 STA    tcc__r0h+1
	 JMP    MOV_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:       CMP    #$03        ;32M
	 BNE    +
	 LDA    #$03
	 STA.L  MYTH_PRAM_BIO

	 CLC
	 LDA    #$08
	 ADC    tcc__r2h
	 STA    tcc__r2h
	 STA.L  MYTH_GBAC_LIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:       CMP    #$04        ;40M
	 BNE    +
	 LDA    #$04
	 STA.L  MYTH_PRAM_BIO

	 CLC
	 LDA    #$08
	 ADC    tcc__r2h
	 STA    tcc__r2h
	 STA.L  MYTH_GBAC_LIO


	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:      CMP    #$05        ;48M
	 BNE    +
	 LDA    #$05
	 STA.L  MYTH_PRAM_BIO

	 CLC
	 LDA    #$08
	 ADC    tcc__r2h
	 STA    tcc__r2h
	 STA.L  MYTH_GBAC_LIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:       CMP    #$06        ;56M
	 BNE    +
	 LDA    #$06
	 STA.L  MYTH_PRAM_BIO

	 CLC
	 LDA    #$08
	 ADC    tcc__r2h
	 STA    tcc__r2h
	 STA.L  MYTH_GBAC_LIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:       CMP    #$07        ;64M
	 BNE    MOV_PSRAM_DONE
	 LDA    #$07
	 STA.L  MYTH_PRAM_BIO

	 CLC
	 LDA    #$08
	 ADC    tcc__r2h
	 STA    tcc__r2h
	 STA.L  MYTH_GBAC_LIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_PSRAM_LOOP
MOV_PSRAM_DONE:
;===============================================================================
	 LDA     #$00       ;
	 STA.L   MYTH_WE_IO     ; PSRAM WRITE OFF
;-------------------------------------------------------------------------------
;neo gba card menu ,swap back to power on mode

	 LDA     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
	 STA.L   MYTH_OPTION_IO

	 LDA     #$20       	; OFF A21
	 STA.L   MYTH_GBAC_ZIO
	 JSR     SET_NEOCMD	; SET MENU

	 LDA     #$00
	 STA.L   MYTH_GBAC_LIO
	 STA.L   MYTH_GBAC_HIO
	 STA.L   MYTH_GBAC_ZIO
;-------------------------------------------------------------------------------
;SET  SNES PSRAM RUN
	 LDA     #$01       	; SET PSRAM RUN
	 STA.L   MYTH_OPTION_IO

	 LDA     #$00
	 STA.L   MYTH_PRAM_BIO

	 LDA     tcc__r0
	 STA.L   MYTH_PRAM_ZIO

	 LDA.L   sramBank
	 LDA     #$00
	 STA.L   MYTH_GBAS_BIO
;===============================================================================
;SET  GAME SAVE  SIZE & BANK
	 LDA.L   sramSize
	 CMP     #$00
	 BNE     MAP_SRAM
	 CMP     #$00
	 STA.L   MYTH_SRAM_TYPE ;  OFF SRAM TYPE
	 JMP     SET_EXT_DSP
;-------------------------------------------------------------------------------
MAP_SRAM:
	 LDA.L   sramMode

 	MAP_SRAM_CHECK $01, $02,MAP_SRAM_DONE
 	MAP_SRAM_CHECK $08, $03,MAP_SRAM_DONE
 	MAP_SRAM_CHECK $07, $07,MAP_SRAM_DONE
 	MAP_SRAM_CHECK $06, $07,MAP_SRAM_DONE
 	MAP_SRAM_CHECK $05, $0F,MAP_SRAM_DONE
 	MAP_SRAM_CHECK $04, $0F,MAP_SRAM_DONE

MAP_SRAM_DONE:
	 LDA     #$01
	 STA.L   MYTH_SRAM_WE    ; GBA SRAM WE ON !
;-------------------------------------------------------------------------------
;SET SAVE SRAM BANK

	 LDA.L   sramSize
	 CMP     #$01
	 BNE     +
	 LDA     #$FF    ;2K  SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 AND     #$FC
	 STA.L   MYTH_GBAS_BIO
	 JMP     SET_EXT_DSP

+:
	 CMP     #$02
	 BNE     +
	 LDA     #$FC    ;8K   SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 AND     #$FC
	 STA.L   MYTH_GBAS_BIO
	 STA.L   MYTH_GBAS_BIO
	 JMP     SET_EXT_DSP

+:
	 CMP     #$03
	 BNE     +
	 LDA     #$F0    ;32K  SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 AND     #$F0
	 STA.L   MYTH_GBAS_BIO
	 JMP     SET_EXT_DSP
;-------------------------------------------------------------------------------
+:
	 CMP     #$04
	 BNE     +
	 LDA     #$E0    ;64K SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 AND     #$F0
	 STA.L   MYTH_GBAS_BIO
	 JMP     SET_EXT_DSP
;-------------------------------------------------------------------------------
+:
	 CMP     #$05
	 BNE     +
	 LDA     #$C0    ;128K SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 AND     #$C0
	 STA.L   MYTH_GBAS_BIO
	 JMP     SET_EXT_DSP
+:
	 ;JMP    MENU
	 rtl
;-------------------------------------------------------------------------------
;SET EXIT DSP
SET_EXT_DSP:

	 LDA.L   extDsp
	 CMP     #$00
	 BNE     +
	 STA.L   MYTH_DSP_TYPE
	 LDA     #$00
	 STA.L   MYTH_DSP_MAP
	 JMP     MAP_DSP_DONE
;-------------------------------------------------------------------------------
+:
	 LDA.L   extDsp
	 CMP     #$01
	 BNE     +
	 STA.L   MYTH_DSP_TYPE
	 LDA     #$00
	 STA.L   MYTH_DSP_MAP
	 JMP     MAP_DSP_DONE
;-------------------------------------------------------------------------------
+:
	 CMP     #$03
	 BNE     +
	 STA.L   MYTH_DSP_TYPE   ;EXT DSP
	 LDA.L   romSize
	 CMP     #$04     ;4M ROM
	 BNE     +
	 LDA     #$03     ;$300000
	 STA.L   MYTH_DSP_MAP
	 JMP     MAP_DSP_DONE
;-------------------------------------------------------------------------------
+:
         LDA     #$03
         STA.L   MYTH_DSP_TYPE  ;EXT DSP
         LDA     #$06    ;$600000
         STA.L   MYTH_DSP_MAP
         JMP     MAP_DSP_DONE

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
MAP_DSP_DONE:
         LDA.L   extSram
         CMP     #$07    ;
         BNE     +      ;
         LDA     #$06    ;
         STA.L   MYTH_OPTION_IO  ;
         LDA     #$C0    ;
         STA.L   $C01F  ;
+:

         LDA.L   romRunMode
         STA.L   MYTH_RUN_IO
RUN_M01:
         JMP     run_3800     ; FOR EXIT RAM


;-------------------------------------------------------------------------------


    

; do a Neo Flash ASIC command
; entry: XY = Neo Flash ASIC command
_neo_asic_cmd:
	php
	sep 	#$20
	rep	#$10

    	jsr    SET_NEOCM5

	; E.g. command = 0x370003 (X=0x0037, Y=0x0003):
	;   Set MYTH_GBAC_LIO = X & 0xE0 (== 0x20)
	;   Do an indirect 8-bit read from (u16)(0x370003 << 1) | 0xC00000 (== 0xEE0006)
	
	txa
	and		#$E0
	sta.l	MYTH_GBAC_LIO
	rep		#$20						; 16-bit A
	sty		tcc__r1
	stx		tcc__r1h
	asl		tcc__r1						; shift left lower 16 bits
	sep		#$20						; 8-bit A
	rol		tcc__r1h					; shift left the upper 8 bits, with d0 being replaced by d15 from the lower 16 bits
	lda		tcc__r1h
	ora		#$C0
	sta		tcc__r1h
	lda		[tcc__r1]
         
	plp
	rts



; select Neo Flash Menu Flash ROM
; allows you to access the menu flash via flash space
_neo_select_menu:
	sep	#$20
	rep	#$10
	phx
	phy

	lda	#0
	sta.l	MYTH_OPTION_IO				; set mode 0
	lda	#$20
	sta.l	MYTH_GBAC_ZIO				; A21 off

	ldx	#$0037
	rep	#$20
	lda.l 	neo_mode					; enable/disable SD card interface
	ora	#$0003
	tay
	jsr	_neo_asic_cmd				; set cr = select menu flash

	ldx	#$00DA
	ldy	#$0044
	jsr	_neo_asic_cmd				; set iosr = disable game flash

	sep	#$20
	lda	#0
	sta.l	MYTH_GBAC_LIO				; clear low bank select reg
	sta.l	MYTH_GBAC_HIO				; clear high bank select reg
	;sta.l	MYTH_GBAC_ZIO

	rep	#$30
	ply
	plx
	rts



_neo_select_psram:
	sep		#$20
	rep		#$10
	phx
	phy

	lda		#0
	sta.l		MYTH_OPTION_IO			; set mode 0
	lda		#$20
	sta.l		MYTH_GBAC_ZIO			; A21 off

	ldx		#$00E2
	ldy		#$1500
	jsr		_neo_asic_cmd				
	
	ldx		#$0037
	rep		#$20
	lda.l 		neo_mode			; enable/disable SD card interface
	ora		#$2203
	tay
	jsr		_neo_asic_cmd			; set cr = select menu flash

	ldx		#$00DA
	ldy		#$AF44
	jsr		_neo_asic_cmd			; set iosr = disable game flash

	;ldx		#$00C4 ;00EE
	;ldy		#$0000 ;0630
	;jsr		_neo_asic_cmd				

	sep		#$20
	lda		#0
	sta.l		MYTH_GBAC_LIO			; clear low bank select reg
	sta.l		MYTH_GBAC_HIO			; clear high bank select reg	
	
	rep		#$30
	ply
	plx
	rts



    
    
; void neo2_enable_sd(void);
neo2_enable_sd:
	sei								; disable interrupts
	rep	#$30
	lda	#$0480
	sta.l	neo_mode
	jsr	_neo_select_menu
	
	sep     #$20                        ; 8-bit A
   	rep     #$20                        ; 16-bit A
   
	rts


; void neo2_disable_sd(void);
neo2_disable_sd:
	sei								; disable interrupts
	rep	#$30
	lda	#0
	sta.l	neo_mode
	jsr	_neo_select_menu
	rts


; void neo2_pre_sd(void);
neo2_pre_sd:
	sei						; disable interrupts
	sep	#$20
	lda	#$87 
	sta.l	MYTH_GBAC_LIO

    	lda    	#$F8
    	sta.l  	MYTH_PRAM_ZIO	; PSRAM 8M SIZE
	LDA    	#GBAC_TO_PSRAM_COPY_MODE
	STA.L  	MYTH_OPTION_IO
	LDA    	#$F8
	STA.L  	MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE

	lda 	#1
	sta.l 	MYTH_WE_IO

	rep	#$20
	rts


; void neo2_post_sd(void);
neo2_post_sd:
	sep	#$20
	lda	#0
	sta.l	MYTH_GBAC_LIO

	LDA    	#0
	STA.L  	MYTH_OPTION_IO
	LDA    	#$0
	STA.L  	MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE

	lda 	#0
	sta.l 	MYTH_WE_IO
	
	rep	#$20
	rts



; void neo2_recv_sd(unsigned char *buf)
;
.EQU _neo2_recv_sd_save_regs 6
.EQU _neo2_recv_sd_buf 3+_neo2_recv_sd_save_regs
;
neo2_recv_sd:
	php
	rep		#$30
	phx
	phy
	phb

	lda		_neo2_recv_sd_buf,s			; buf
	tax
	sep		#$20
;	lda		#$80 ;87
;	sta.l	MYTH_GBAC_LIO
	lda		_neo2_recv_sd_buf+2,s		; buf bank
	pha
	plb									; DBR points to buf's bank
	ldy		#256						; counter
	_nrsd_loop:
		.rept 2
		lda.l	MYTH_NEO2_RD_DAT4			; read first nybble
		asl		a
		asl		a
		asl		a
		asl		a
		sta		tcc__r0
		lda.l	MYTH_NEO2_RD_DAT4			; read second nybble
		and		#$0F
		ora		tcc__r0						; sector byte
		sta.w	$0000,x						; write to buf
		inx
		.endr
		dey
		bne		_nrsd_loop					; repeat 256 times

	; Read 8 CRC bytes (16 nybbles)
	.rept 16
	lda.l	MYTH_NEO2_RD_DAT4
	.endr

	lda.l	MYTH_NEO2_RD_DAT4			; end bit

	plb
	ply
	plx
	plp
	rts



; void neo2_recv_sd_psram(WORD prbank, WORD proffs)
;
.EQU _neo2_recv_sd_psram_save_regs 6
.EQU _neo2_recv_sd_psram_prbank 3+_neo2_recv_sd_psram_save_regs
.EQU _neo2_recv_sd_psram_proffs _neo2_recv_sd_psram_prbank+2
;
neo2_recv_sd_psram:
	php
	rep		#$30
	phx
	phy
	phb

	lda		_neo2_recv_sd_psram_proffs,s
	tax
	sep		#$20
	lda		_neo2_recv_sd_psram_prbank,s	
	sta.l	$7d0000+_nrsdp_write+3

	lda		#$40
	pha
	plb									
	ldy		#256						; counter
	_nrsdp_loop:

		sep		#$20
		lda.w	$6061					; Read high nybble of low byte (S)
		asl		a	
		asl		a	
		asl		a	
		asl		a
		sta		tcc__r0	
		lda.w	$6061					; Read low nybble of low byte (s)
		and		#$0F
		ora		tcc__r0
		sta		tcc__r0					; tcc__r0 = 0x??Ss
		lda.w	$6061					; Read high nybble of high byte (T)
		asl		a	
		asl		a	
		asl		a	
		asl		a
		sta		tcc__r0+1				; tcc__r0 = 0xT0Ss
		lda.w	$6061
		rep		#$20
		and		#$0F					; A = 0x000t
		xba								; A = 0x0t00
		ora		tcc__r0					; A = 0xTtSs
_nrsdp_write:
		sta.l $500000,x					; Write 16 bits to PSRAM
		inx
		inx
		dey
				
		bne		_nrsdp_loop				; repeat 256 times

	sep 	#$20
	plb

	; Read 8 CRC bytes (16 nybbles)
	.rept 16
	lda.l	MYTH_NEO2_RD_DAT4
	.endr

	lda.l	MYTH_NEO2_RD_DAT4			; end bit

	;jsr.w show_copied_data
	
	ply
	plx
	plp
	rts
	


nop

; void neo2_recv_sd_psram_multi(WORD prbank, WORD proffs, WORD count)
;
.EQU _neo2_recv_sd_psram_multi_save_regs 6
.EQU _neo2_recv_sd_psram_multi_prbank 3+_neo2_recv_sd_psram_multi_save_regs
.EQU _neo2_recv_sd_psram_multi_proffs _neo2_recv_sd_psram_multi_prbank+2
.EQU _neo2_recv_sd_psram_multi_count _neo2_recv_sd_psram_multi_proffs+2
;
neo2_recv_sd_psram_multi:
	php
	rep		#$30
	phx
	phy
	phb

	lda		_neo2_recv_sd_psram_multi_proffs,s
	tax
	lda		_neo2_recv_sd_psram_multi_count,s
	tay
	sep		#$20
	;lda		_neo2_recv_sd_psram_multi_prbank,s	
	;sta.l		$7d0000+_nrsdpm_write+3
lda.l	$7d0000+_disk_readprm_jump_to_psram+3 
pha
plb
lda	#$E8			; $E8 = INX
xba
lda	_neo2_recv_sd_psram_multi_prbank,s
rep 	#$20
sta.w _nrsdpm_write+3
sep #$20

	lda		#$C0
	pha
	plb
	
_nrsdpm_sectors:
	phy
	sep 		#$20
	ldy		#$1024
-:									; Wait for start bit
	lda.w		$6061
	and		#1
	beq		+
	dey
	bne		-
	; Timeout
	ply
	stz.b		tcc__r0					; FALSE
	jmp.w		_nrsdpm_return
+:

	ldy		#256					; words per sector
_nrsdpm_loop_inner:
	sep		#$20
	lda.w		$6061					; Read high nybble of low byte (D)
	asl		a	
	asl		a	
	asl		a	
	asl		a						; A = %DDDD0000					
	sta		tcc__r0	
	lda.w		$6061					; Read low nybble of low byte (s)
	and		#$0F
	ora		tcc__r0
	xba
	
	lda.w		$6061					; Read high nybble of high byte 
	asl		a	
	asl		a	
	asl		a	
	asl		a
	sta		tcc__r0	
	lda.w		$6061					; Read low nybble of low byte (s)
	and		#$0F
	ora		tcc__r0
	xba
	rep		#$20

; *** THIS LABEL MUST BE LOCATED AT AN ODD ADDRESS ***
_nrsdpm_write:
	sta.l $500000,x					; Write 16 bits to PSRAM
	inx
	inx
	dey
	bne		_nrsdpm_loop_inner		; repeat 256 times

	sep		#$20
	; Read 8 CRC bytes (16 nybbles)
	.rept 16
	lda.l	MYTH_NEO2_RD_DAT4
	.endr

	lda.l	MYTH_NEO2_RD_DAT4		; end bit

	cpx		#0						; has proffs wrapped around (i.e. should we move to the next bank) ?
	bne		+
phb
lda.l	$7d0000+_disk_readprm_jump_to_psram+3 
pha
plb
rep #$20
	lda.w	_nrsdpm_write+3
	ina
	sta.w	_nrsdpm_write+3
sep #$20
plb
+:

	ply								; count
	dey
	beq		+
	jmp.w	_nrsdpm_sectors
+:
	lda		#1
	sta		tcc__r0					; TRUE
	
_nrsdpm_return:
	plb
	
	;jsr.w show_copied_data
	
	ply
	plx
	plp
	rts

;nop	
	

.DEFINE RECV_SD_OFS $DE0000

; void neo2_recv_sd_psram_multi_hwaccel(WORD prbank, WORD proffs, WORD count)
;
.EQU _neo2_recv_sd_psram_multi_hwaccel_save_regs 6
.EQU _neo2_recv_sd_psram_multi_hwaccel_prbank 3+_neo2_recv_sd_psram_multi_hwaccel_save_regs
.EQU _neo2_recv_sd_psram_multi_hwaccel_proffs _neo2_recv_sd_psram_multi_hwaccel_prbank+2
.EQU _neo2_recv_sd_psram_multi_hwaccel_count _neo2_recv_sd_psram_multi_hwaccel_proffs+2
;
neo2_recv_sd_psram_multi_hwaccel:
	php
	rep		#$30
	phx
	phy
	phb

	lda		_neo2_recv_sd_psram_multi_hwaccel_proffs,s
	tax
	lda		_neo2_recv_sd_psram_multi_hwaccel_count,s
	tay
	sep		#$20
_nrsdpmhw_selfmod_bank1:	
	lda.l	$7d0000+_disk_readprm_jump_to_psram+3 
	pha
	plb
	lda		#$AD					; $AD = LDA Abs
	xba
	lda		_neo2_recv_sd_psram_multi_hwaccel_prbank,s
	rep 	#$20
	sta.w	_nrsdpmhw_writeB00+3
	sta.w	_nrsdpmhw_writeB01+3
	sta.w	_nrsdpmhw_writeB02+3
	sta.w	_nrsdpmhw_writeB03+3
	sta.w	_nrsdpmhw_writeB04+3
	sta.w	_nrsdpmhw_writeB05+3
	sta.w	_nrsdpmhw_writeB06+3
	sta.w	_nrsdpmhw_writeB07+3
	sta.w	_nrsdpmhw_writeB08+3
	sta.w	_nrsdpmhw_writeB09+3
	sta.w	_nrsdpmhw_writeB0a+3
	sta.w	_nrsdpmhw_writeB0b+3
	sta.w	_nrsdpmhw_writeB0c+3
	sta.w	_nrsdpmhw_writeB0d+3
	sta.w	_nrsdpmhw_writeB0e+3

	sta.w	_nrsdpmhw_writeB0f+3

	sta.w	_nrsdpmhw_writeB10+3
	sta.w	_nrsdpmhw_writeB11+3
	sta.w	_nrsdpmhw_writeB12+3
	sta.w	_nrsdpmhw_writeB13+3
	sta.w	_nrsdpmhw_writeB14+3
	sta.w	_nrsdpmhw_writeB15+3
	sta.w	_nrsdpmhw_writeB16+3
	sta.w	_nrsdpmhw_writeB17+3
	sta.w	_nrsdpmhw_writeB18+3
	sta.w	_nrsdpmhw_writeB19+3
	sta.w	_nrsdpmhw_writeB1a+3
	sta.w	_nrsdpmhw_writeB1b+3
	sta.w	_nrsdpmhw_writeB1c+3
	sta.w	_nrsdpmhw_writeB1d+3
	sta.w	_nrsdpmhw_writeB1e+3
		
	eor	#$6F00  				; Set high byte = $C2 = REP
	sta.w	_nrsdpmhw_writeB1f+3
	sep	#$20
	
	lda	#$C0
	pha
	plb
	
_nrsdpmhw_sectors:
	phy
	sep 	#$20
	ldy	#$1024
-:									; Wait for start bit
	lda.w	$6061
	and		#1
	beq		+
	dey
	bne		-
	; Timeout
	ply
	stz.b	tcc__r0					; FALSE
	jmp.w	_nrsdpmhw_return
+:

	sep	#$20
	lda	#SDBUF_HI_LO
	sta.l	MYTH_SDBUF_IO			; Enter 4+4 buffered mode

	clc

	ldy		#16						; qwords per sector
_nrsdpmhw_loop_inner:
	lda.w 	$6063
	lda.w 	$6063
; NOTE: THIS LABEL MUST BE LOCATED ON AN ODD ADDRESS
_nrsdpmhw_writeB00:
	sta.l 	$500000,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB01:
	sta.l 	$500001,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB02:
	sta.l 	$500002,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB03:
	sta.l 	$500003,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB04:
	sta.l 	$500004,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB05:
	sta.l 	$500005,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB06:
	sta.l 	$500006,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB07:
	sta.l 	$500007,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB08:
	sta.l 	$500008,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB09:
	sta.l 	$500009,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB0a:
	sta.l 	$50000a,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB0b:
	sta.l 	$50000b,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB0c:
	sta.l 	$50000c,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB0d:
	sta.l 	$50000d,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB0e:
	sta.l 	$50000e,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB0f:
	sta.l 	$50000f,x				; Write 8 bits to PSRAM

	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB10:
	sta.l 	$500010,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB11:
	sta.l 	$500011,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB12:
	sta.l 	$500012,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB13:
	sta.l 	$500013,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB14:
	sta.l 	$500014,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB15:
	sta.l 	$500015,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB16:
	sta.l 	$500016,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB17:
	sta.l 	$500017,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB18:
	sta.l 	$500018,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB19:
	sta.l 	$500019,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB1a:
	sta.l 	$50001a,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB1b:
	sta.l 	$50001b,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB1c:
	sta.l 	$50001c,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB1d:
	sta.l 	$50001d,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB1e:
	sta.l 	$50001e,x				; Write 8 bits to PSRAM
	lda.w 	$6063
	lda.w 	$6063
_nrsdpmhw_writeB1f:
	sta.l 	$50001f,x				; Write 8 bits to PSRAM
	
	rep 	#$20
	txa
	adc 	#32
	tax
	sep 	#$20

	dey
	beq +
	jmp _nrsdpmhw_loop_inner
	+:

	lda	#SDBUF_OFF
	sta.l	MYTH_SDBUF_IO			; Exit 4+4 mode
	
	; Read 8 CRC bytes (16 nybbles)
	.rept 16
	lda.w	$6061 ;MYTH_NEO2_RD_DAT4
	.endr

	lda.w	$6061 					; end bit

	cpx		#0						; has proffs wrapped around (i.e. should we move to the next bank) ?
	bne		+
	sep		#$20
	phb
_nrsdpmhw_selfmod_bank2:
	lda.l	$7d0000+_disk_readprm_jump_to_psram+3 ;#$7E
	;lda #$DF
	pha
	plb
	rep 	#$20
	lda.w	_nrsdpmhw_writeB00+3
	ina
	sta.w	_nrsdpmhw_writeB00+3
	sta.w	_nrsdpmhw_writeB01+3
	sta.w	_nrsdpmhw_writeB02+3
	sta.w	_nrsdpmhw_writeB03+3
	sta.w	_nrsdpmhw_writeB04+3
	sta.w	_nrsdpmhw_writeB05+3
	sta.w	_nrsdpmhw_writeB06+3
	sta.w	_nrsdpmhw_writeB07+3
	sta.w	_nrsdpmhw_writeB08+3
	sta.w	_nrsdpmhw_writeB09+3
	sta.w	_nrsdpmhw_writeB0a+3
	sta.w	_nrsdpmhw_writeB0b+3
	sta.w	_nrsdpmhw_writeB0c+3
	sta.w	_nrsdpmhw_writeB0d+3
	sta.w	_nrsdpmhw_writeB0e+3

	sta.w	_nrsdpmhw_writeB0f+3

	sta.w	_nrsdpmhw_writeB10+3
	sta.w	_nrsdpmhw_writeB11+3
	sta.w	_nrsdpmhw_writeB12+3
	sta.w	_nrsdpmhw_writeB13+3
	sta.w	_nrsdpmhw_writeB14+3
	sta.w	_nrsdpmhw_writeB15+3
	sta.w	_nrsdpmhw_writeB16+3
	sta.w	_nrsdpmhw_writeB17+3
	sta.w	_nrsdpmhw_writeB18+3
	sta.w	_nrsdpmhw_writeB19+3
	sta.w	_nrsdpmhw_writeB1a+3
	sta.w	_nrsdpmhw_writeB1b+3
	sta.w	_nrsdpmhw_writeB1c+3
	sta.w	_nrsdpmhw_writeB1d+3
	sta.w	_nrsdpmhw_writeB1e+3
		
	eor	#$6F00  				; Set high byte = $C2 = REP
	sta.w	_nrsdpmhw_writeB1f+3
	sep 	#$20
	plb
+:

	ply						; count
	dey
	beq		+
	jmp.w	_nrsdpmhw_sectors
+:
	rep		#$20
	lda		#1
	sta		tcc__r0				; TRUE
	
_nrsdpmhw_return:
	plb

	;jsr.w show_copied_data

	ply
	plx
	plp
	rts
	
	
	

neo2_recv_sd_multi:
	rts
	


jsr_r10:
    rep 	#$20
    lda.b 	tcc__r10
    dec 	a
    pha
    rts


 .MACRO MOV_SD_PSRAM_SETUP
        LDA.L  romSize
        CMP    #\1
        BNE    +
        LDA    #\2
        STA    tcc__r0

        LDA    #<\3
        STA    tcc__r0+1
        LDA    #>\3
        STA    tcc__r0h

        LDA    #\4
        STA    tcc__r0h+1

        LDA    #\5
        STA    tcc__r1
        JMP    MOV_SD_PSRAM
	+:
 .ENDM
 

run_game_from_sd_card:
	jsl		clear_status_window
	;jsl		update_screen

	sep		#$20

	lda		#$7e
	pha
	plb

	lda.l	romAddressPins
	sta		tcc__r2h

;	lda.l	useGbacPsram
;	bne		+
	LDA    	#$20      	; OFF A21
	STA.L  	MYTH_GBAC_ZIO
	JSR    	SET_NEOCMA  	;
	JSR    	SET_NEOCMB  	;
	JSR    	SET_NEOCMC  	; ON_NEO CARD A24 & A25 + SA16 & SA17

	LDA.L   romAddressPins+1
lda #0
	STA.L   MYTH_GBAC_HIO	; SET AH25,AH25

	LDA     #$01
	STA.L   MYTH_EXTM_ON   ; A25,A24 ON
	bra		++
+:
	jsr.w	_neo_select_psram
	sep		#$20
++:

	;                    4M    4M    4M  4M~8M
	MOV_SD_PSRAM_SETUP $04, $3C, $3035, $04, $00
	;                    8M    8M    8M  4M~8M
	MOV_SD_PSRAM_SETUP $08, $38, $3039, $08, $00
	;                    16M   16M   8M   16M
	MOV_SD_PSRAM_SETUP $09, $30, $3137, $08, $01
	;                    32M   24M   8M   24M
	MOV_SD_PSRAM_SETUP $0A, $20, $3235, $08, $02
	;                    32M   32M   8M   32M
	MOV_SD_PSRAM_SETUP $0B, $20, $3333, $08, $03
	;                    64M   40M   8M   40M
	MOV_SD_PSRAM_SETUP $0C, $00, $3431, $08, $04
	;                    64M   48M   8M   48M
	MOV_SD_PSRAM_SETUP $0D, $00, $3439, $08, $05
	;                    64M   64M   8M   64M
	MOV_SD_PSRAM_SETUP $0E, $00, $3635, $08, $07

;===============================================================================
MOV_SD_PSRAM:
	 lda	tcc__r0+1
	 sta.l	loadProgress+15
	 lda	tcc__r0h
	 sta.l	loadProgress+14

	 LDA    #$00
	 STA    tcc__r1+1
	 sta	tcc__r3

	 LDA    #GBAC_TO_PSRAM_COPY_MODE
	 STA.L  MYTH_OPTION_IO

	 LDA    #$01       	; PSRAM WE ON !
	 STA.L  MYTH_WE_IO

	 LDA    #$F8
	 STA.L  MYTH_GBAC_ZIO  	; GBA CARD 8M SIZE
	 STA.L  MYTH_PRAM_ZIO  	; PSRAM    8M SIZE

	 LDA    #$00
	 STA.L  MYTH_PRAM_BIO

; The game has already been copied to PSRAM by run_game_from_sd_card_c.
; This loop just applies region fixes and game genie codes.
MOV_SD_PSRAM_LOOP:
	 LDA    #$3E
	 STA    tcc__r1h
	 LDA    #PSRAM_BANK-2
	 STA    tcc__r2

	 LDA    #$3F
	 STA    tcc__r1h+1

	 LDA    #PSRAM_BANK-1
	 STA    tcc__r2+1

-:
	 INC    tcc__r1h
	 INC    tcc__r2
	 INC    tcc__r2+1

	 INC    tcc__r1h
	 INC    tcc__r2
	 INC    tcc__r2+1

     LDA    tcc__r2

	 DEC    tcc__r0+1
	 LDA    tcc__r0+1        ; L-BYTE
	 LDA    tcc__r0h        ; H-BYTE

	 jsr	fix_region_checks

	; Replace the NMI vector with the cheat routine if needed
	 lda	tcc__r3
	 bne	+
	 lda.l	anyRamCheats
	 beq	+
	 lda.l	romRunMode
	 bne	_patch_nmi_lorom
	 rep	#$20
	 lda.l	$50ffea
	 sta.l	$7d0000+branch_to_real_nmi+1
	 lda	#$3e00
	 sta.l	$50ffea		; Native mode vector
	 sep	#$20
	 bra	+
	 _patch_nmi_lorom:
	 rep	#$20
	 lda.l	$507fea
	 sta.l	$7d0000+branch_to_real_nmi+1
	 lda	#$3e00
	 sta.l	$507fea		; Native mode vector
	 sep	#$20
	 +:

	 jsr	apply_cheat_codes
	 inc	tcc__r3
	 inc	tcc__r3

	 DEC    tcc__r0h+1
	 BEQ	+
	 JMP    -
	 +:

	 LDA    tcc__r1
	 CMP    tcc__r1+1
	 BNE    MOV_SD_PSRAM_1
	 JMP    MOV_SD_PSRAM_DONE
MOV_SD_PSRAM_1:
;===============================================================================
	 INC    tcc__r1+1
	 LDA    tcc__r1+1
	 CMP    #$01
	 BNE    +

	 LDA    #$01        ;16M
	 STA.L  MYTH_PRAM_BIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_SD_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:   CMP    #$02        ;24M
	 BNE    +
	 LDA    #$02
	 STA.L  MYTH_PRAM_BIO

	 LDA    #$8
	 STA    tcc__r0h+1
	 JMP    MOV_SD_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:   CMP    #$03        ;32M
	 BNE    +
	 LDA    #$03
	 STA.L  MYTH_PRAM_BIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_SD_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:   CMP    #$04        ;40M
	 BNE    +
	 LDA    #$04
	 STA.L  MYTH_PRAM_BIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_SD_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:   CMP    #$05        ;48M
	 BNE    +
	 LDA    #$05
	 STA.L  MYTH_PRAM_BIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_SD_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:   CMP    #$06        ;56M
	 BNE    +
	 LDA    #$06
	 STA.L  MYTH_PRAM_BIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_SD_PSRAM_LOOP
;-------------------------------------------------------------------------------
+:   CMP    #$07        ;64M
	 BNE    MOV_SD_PSRAM_DONE
	 LDA    #$07
	 STA.L  MYTH_PRAM_BIO

	 LDA    #$8
	 STA    tcc__r0h+1      ;
	 JMP    MOV_SD_PSRAM_LOOP
MOV_SD_PSRAM_DONE:
;===============================================================================
	 LDA     #$00       ;
	 STA.L   MYTH_WE_IO     ; PSRAM WRITE OFF
;-------------------------------------------------------------------------------
;neo gba card menu ,swap back to power on mode

;	lda.l	useGbacPsram
;	bne		+
	 LDA     #MAP_MENU_FLASH_TO_ROM	; SET GBA CARD RUN
	 STA.L   MYTH_OPTION_IO

	 LDA     #$20       	; OFF A21
	 STA.L   MYTH_GBAC_ZIO
	 JSR     SET_NEOCMD	; SET MENU
+:
	 LDA     #$00
	 STA.L   MYTH_GBAC_LIO
	 STA.L   MYTH_GBAC_HIO
	 STA.L   MYTH_GBAC_ZIO
;-------------------------------------------------------------------------------
;SET  SNES PSRAM RUN
	 LDA     #$01       	; SET PSRAM RUN
	 STA.L   MYTH_OPTION_IO

	 LDA     #$00
	 STA.L   MYTH_PRAM_BIO

	 LDA     tcc__r0
	 STA.L   MYTH_PRAM_ZIO

	 LDA.L   sramBank
	 LDA     #$00
	 STA.L   MYTH_GBAS_BIO
;===============================================================================
;SET  GAME SAVE  SIZE & BANK
	 LDA.L   sramSize
	 CMP     #$00
	 BNE     SD_MAP_SRAM
;	 CMP     #$00
	 STA.L   MYTH_SRAM_TYPE ;  OFF SRAM TYPE
	 JMP     SD_SET_EXT_DSP
;-------------------------------------------------------------------------------
SD_MAP_SRAM:
 	LDA.L   sramMode

 	MAP_SRAM_CHECK $01, $02, SD_MAP_SRAM_DONE
 	MAP_SRAM_CHECK $08, $03, SD_MAP_SRAM_DONE
 	MAP_SRAM_CHECK $07, $07, SD_MAP_SRAM_DONE
 	MAP_SRAM_CHECK $06, $07, SD_MAP_SRAM_DONE
 	MAP_SRAM_CHECK $05, $0F, SD_MAP_SRAM_DONE
 	MAP_SRAM_CHECK $04, $0F, SD_MAP_SRAM_DONE

SD_MAP_SRAM_DONE:
	 LDA     #$01
	 STA.L   MYTH_SRAM_WE    ; GBA SRAM WE ON !
;-------------------------------------------------------------------------------
;SET SAVE SRAM BANK

	 LDA.L   sramSize
	 CMP     #$01
	 BNE     +
	 LDA     #$FF    ;2K  SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 AND     #$FC
	 STA.L   MYTH_GBAS_BIO
	 JMP     SD_SET_EXT_DSP

+:
	 CMP     #$02
	 BNE     +
	 LDA     #$FC    ;8K   SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 AND     #$FC
	 STA.L   MYTH_GBAS_BIO
	 STA.L   MYTH_GBAS_BIO
	 JMP     SD_SET_EXT_DSP

+:
	 CMP     #$03
	 BNE     +
	 LDA     #$F0    ;32K  SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 AND     #$F0
	 STA.L   MYTH_GBAS_BIO
	 JMP     SD_SET_EXT_DSP
;-------------------------------------------------------------------------------
+:
	 CMP     #$04
	 BNE     +
	 LDA     #$E0    ;64K SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 AND     #$F0
	 STA.L   MYTH_GBAS_BIO
	 JMP     SD_SET_EXT_DSP
;-------------------------------------------------------------------------------
+:
	 CMP     #$05
	 BNE     +
	 LDA     #$C0    ;128K SIZE
	 STA.L   MYTH_GBAS_ZIO

	 LDA.L   sramBank
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 ASL     A
	 AND     #$C0
	 STA.L   MYTH_GBAS_BIO
	 JMP     SD_SET_EXT_DSP
+:
	 rtl


;-------------------------------------------------------------------------------
SD_SET_EXT_DSP:

	 LDA.L   extDsp
	 CMP     #$00
	 BNE     +
	 STA.L   MYTH_DSP_TYPE
	 LDA     #$00
	 STA.L   MYTH_DSP_MAP
	 JMP     _MAP_DSP_DONE
;-------------------------------------------------------------------------------
+:
	 LDA.L   extDsp
	 CMP     #$01
	 BNE     +
	 STA.L   MYTH_DSP_TYPE
	 LDA     #$00
	 STA.L   MYTH_DSP_MAP
	 JMP     _MAP_DSP_DONE
;-------------------------------------------------------------------------------
+:
	 CMP     #$03
	 BNE     +
	 STA.L   MYTH_DSP_TYPE   ;EXT DSP
	 LDA.L   romSize
	 CMP     #$04     ;4M ROM
	 BNE     +
	 LDA     #$03     ;$300000
	 STA.L   MYTH_DSP_MAP
	 JMP     _MAP_DSP_DONE
;-------------------------------------------------------------------------------
+:
     LDA     #$03
     STA.L   MYTH_DSP_TYPE  ;EXT DSP
     LDA     #$06    ;$600000
     STA.L   MYTH_DSP_MAP
     JMP     _MAP_DSP_DONE

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
_MAP_DSP_DONE:
         LDA.L   extSram
         CMP     #$07    ;
         BNE     +      ;
         LDA     #$06    ;
         STA.L   MYTH_OPTION_IO  ;
         LDA     #$C0    ;
         STA.L   $C01F  ;
+:

         LDA.L   romRunMode
         STA.L   MYTH_RUN_IO
_RUN_M01:
         JMP     run_3800     ; FOR EXIT RAM
         
        
	
.include "diskio_asm.inc"

ram_code_end:


.ends



