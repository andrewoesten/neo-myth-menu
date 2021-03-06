; Assembly optimized pff routines
; /Mic, 2010-2013

.include "hdr.asm"
.include "snes_io.inc"

.equ FATFS_fs_type 0
.equ FATFS_csize 1
.equ FATFS_flag 2
.equ FATFS_csect 3
.equ FATFS_n_rootdir 4
.equ FATFS_buf 8
.equ FATFS_max_clust 12
.equ FATFS_fatbase 16
.equ FATFS_dirbase 20
.equ FATFS_database 24
.equ FATFS_fptr 28
.equ FATFS_fsize 32
.equ FATFS_org_clust 36
.equ FATFS_curr_clust 40
.equ FATFS_dsect 44

.equ MYTH_PRAM_BIO  $C006


;	BYTE	fs_type;	0
;	BYTE	csize;		1
;	BYTE	flag;		2
;	BYTE	csect;		3
;	WORD	n_rootdir;	4
;	BYTE*	buf;		8
;	CLUST	max_clust;	12
;	DWORD	fatbase;	16
;	DWORD	dirbase;	20
;	DWORD	database;	24
;	DWORD	fptr;		28
;	DWORD	fsize;		32
;	CLUST	org_clust;	36
;	CLUST	curr_clust;	40
;	DWORD	dsect;		44
;} FATFS;



.section ".text_pff_clust2sect_opt" superfree

;DWORD clust2sect (	/* !=0: Sector number, 0: Failed - invalid cluster# */
;	CLUST clst		/* Cluster# to be converted */
;)
;
.EQU _clust2sect_save_regs 5
.EQU _clust2sect_clst 4+_clust2sect_save_regs
;
clust2sect:
	php
	rep		#$30
	phx
	phy
	
	; Let tcc__r2 point to the filesystem struct
	lda.w	FatFs
	sta		tcc__r2
	lda.w	FatFs + 2
	sta		tcc__r2h
	
	; clst -= 2
	lda		_clust2sect_clst,s
	sec
	sbc		#2
	sta		tcc__r0
	lda		_clust2sect_clst+2,s
	sbc		#0
	sta		tcc__r0h
	
	ldy		#FATFS_max_clust
	lda		[tcc__r2],y
	sec
	sbc		#2
	sta		tcc__r1
	iny
	iny
	lda		[tcc__r2],y
	sbc		#0
	sta		tcc__r1h
	
	lda		tcc__r0
	sec
	sbc		tcc__r1
	lda		tcc__r0h
	sbc		tcc__r1h
	bmi		+
	stz		tcc__r0			; Invalid cluster
	stz		tcc__r1
	bra		_c2s_return
+:

	ldy		#FATFS_csize
	lda		[tcc__r2],y
	and		#$FF
	ldx		#8
-:
	lsr		a
	bcs		+
	asl		tcc__r0
	rol		tcc__r0h
	dex
	bne		-
+:
	ldy		#FATFS_database
	lda		tcc__r0
	clc
	adc		[tcc__r2],y
	sta		tcc__r0
	lda		tcc__r0h
	iny
	iny
	adc		[tcc__r2],y
	sta		tcc__r1
_c2s_return:	
	ply
	plx
	plp
	rtl

.ends



.section ".text_pff_read_opt" superfree

; FRESULT pf_read_1mbit_to_psram_asm (
; 	WORD prbank,
;	WORD proffs,
;   WORD mythprbank,
;	WORD recalcsector
;)
;
.EQU _pf_read_1mbit_to_psram_asm_save_regs 5					
.EQU _pf_read_1mbit_to_psram_asm_prbank 4+_pf_read_1mbit_to_psram_asm_save_regs
.EQU _pf_read_1mbit_to_psram_asm_proffs _pf_read_1mbit_to_psram_asm_prbank+2
.EQU _pf_read_1mbit_to_psram_asm_mythprbank _pf_read_1mbit_to_psram_asm_proffs+2
.EQU _pf_read_1mbit_to_psram_asm_recalcsector _pf_read_1mbit_to_psram_asm_mythprbank+2
;
pf_read_1mbit_to_psram_asm:
	php
	rep		#$30
	phx
	phy
	
	; Let tcc__r2 point to the filesystem struct
	lda.w	FatFs
	sta		tcc__r2
	lda.w	FatFs + 2
	sta		tcc__r2h
	
	; fs == NULL ?
	ora		tcc__r2
	bne		+
	lda		#8					; FR_NOT_ENABLED
	sta		tcc__r0
	jmp		_pr1pa_return
+:

	; Check if the FA_READ flag is set
	sep		#$20
	ldy		#FATFS_flag
	lda		[tcc__r2],y
	and		#1
	rep		#$20
	bne		+
	lda		#7					; FR_INVALID_OBJECT
	sta		tcc__r0
	jmp		_pr1pa_return
+:

	; tcc__r0 = fs->fsize - fs->fptr (remaining bytes in file)
	sec
	ldy		#FATFS_fsize
	lda		[tcc__r2],y
	ldy		#FATFS_fptr
	sbc		[tcc__r2],y
	sta		tcc__r0
	ldy		#FATFS_fsize+2
	lda		[tcc__r2],y
	ldy		#FATFS_fptr+2
	sbc		[tcc__r2],y
	sta		tcc__r0h

	; Do we have at least 1 Mbit ($20000 bytes) left?
	cmp		#2
	bcs		+
	lda		#7					; FR_INVALID_OBJECT
	sta		tcc__r0
	jmp		_pr1pa_return
+:

	sep		#$20
	lda.l   cpID
	cmp     #4
	bcc     +
    ; Enable FastROM timing for PSRAM on firmware versions >= 4
	lda.l	sdLoaderMemSel
	sta.l	REG_MEMSEL
+:
	rep		#$20

	; basesect = clust2sect(fs->curr_clust)
	ldy		#FATFS_curr_clust+2
	lda		[tcc__r2],y
	pha
	dey
	dey
	lda		[tcc__r2],y
	pha
	jsl		clust2sect
	pla
	pla
	lda		tcc__r0
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect
	lda		tcc__r1
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect+2

	lda.w	FatFs
	sta		tcc__r2
	lda.w	FatFs+2
	sta		tcc__r2h

    lda     #$FFFF
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst+2
    lda     #0
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors

    ; Read 256 sectors == 128 kByte
	lda		#256
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_numSects
	
	jml 	$800000+_pr1pa_while_numSects

_pr1pa_while_numSects:

	lda		_pf_read_1mbit_to_psram_asm_recalcsector,s
	bne		+
	jmp.w	_pr1pa_no_recalc
+:
	ldy		#FATFS_csize
	sep		#$20
	lda		[tcc__r2],y
	dea
	sta		tcc__r0
	stz		tcc__r0+1
	rep		#$20
	ldy		#FATFS_fptr+2
	lda		[tcc__r2],y
	sta		tcc__r1h
	dey
	dey
	lda		[tcc__r2],y
	sta		tcc__r1					; tcc__r1 = fs->fptr
	.rept 9
	lsr		a
	.endr
	and		tcc__r0					; A = (fs->fptr >> 9) & (fs->csize - 1)
	beq		+
	jmp.w	_pr1pa_not_at_clust_start
+:
	;fs->fptr == 0 ?
	lda		tcc__r1
	ora		tcc__r1h
	bne		+
	ldy		#FATFS_org_clust
	lda		[tcc__r2],y
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst
	iny
	iny
	lda		[tcc__r2],y
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst+2
	bra		++
+:
	; clst = get_fat(fs->curr_clust)
	ldy		#FATFS_curr_clust+2
	lda		[tcc__r2],y
	pha
	dey
	dey
	lda		[tcc__r2],y
	pha
	jsl		get_fat
	pla
	pla
	lda		tcc__r0
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst
	lda		tcc__r1
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst+2
	lda.w	FatFs
	sta		tcc__r2
	lda.w	FatFs+2
	sta		tcc__r2h
++:
	
	; clst <= 1 ?
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst+2
	bmi		+
	ora.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst
	cmp		#2
	bcs		++
+:
	sep		#$20
	ldy		#FATFS_flag
	lda		#0
	sta		[tcc__r2],y
	rep		#$20
	lda		#1						; FR_DISK_ERR
	sta		tcc__r0
	jmp		_pr1pa_return
++:
	; fs->curr_clust = clst
	ldy		#FATFS_curr_clust
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst
	sta		[tcc__r2],y
	iny
	iny
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst+2
	sta		[tcc__r2],y
	; fs->csect = 0
	lda		#0
	sep		#$20
	ldy		#FATFS_csect
	sta		[tcc__r2],y
	rep		#$20

	; basesect = clust2sect(fs->curr_clust)
	ldy		#FATFS_curr_clust+2
	lda		[tcc__r2],y
	pha
	dey
	dey
	lda		[tcc__r2],y
	pha
	jsl		clust2sect
	pla
	pla
	lda		tcc__r0
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect
	lda		tcc__r1
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect+2

	lda.w	FatFs
	sta		tcc__r2
	lda.w	FatFs+2
	sta		tcc__r2h

_pr1pa_not_at_clust_start:

	; basesect == 0 ?
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect
	ora.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect+2
	bne		+	
	sep		#$20
	ldy		#FATFS_flag
	lda		#0
	sta		[tcc__r2],y
	rep		#$20
	lda		#1						; FR_DISK_ERR
	sta		tcc__r0
	jmp		_pr1pa_return
+:

	; fs->dsect = basesect + fs->csect
	ldy		#FATFS_csect
	lda		[tcc__r2],y
	and		#$FF
	ldy		#FATFS_dsect
	clc
	adc.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect
	sta		[tcc__r2],y
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect+2
	adc		#0
	iny
	iny
	sta		[tcc__r2],y
	
	; fs->csect++
	ldy		#FATFS_csect
	sep		#$20
	lda		[tcc__r2],y
	ina
	sta		[tcc__r2],y
	rep		#$20
	
_pr1pa_no_recalc:
    ; if (prevClst == 0xFFFFFFFF) firstSector = fs->dsect
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst
    cmp     #$FFFF
    bne     +
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst+2
    cmp     #$FFFF
    bne     +
    ldy     #FATFS_dsect
    lda     [tcc__r2],y
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector
    iny
    iny
    lda     [tcc__r2],y
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector+2
+:

    lda		#0
	sep		#$20
	ldy		#FATFS_csize
	lda		[tcc__r2],y
	ldy		#FATFS_csect
	sec
	sbc		[tcc__r2],y
	rep		#$20
	clc
	adc		_pf_read_1mbit_to_psram_asm_recalcsector,s
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust

	lda		#1
	sta		_pf_read_1mbit_to_psram_asm_recalcsector,s

	lda		#$00DF
	sta		tcc__r1h
	lda		#$8000
	sta		tcc__r1
	
	lda		_pf_read_1mbit_to_psram_asm_prbank,s
	cmp		#$DE
	bcc		+
	;lda		_pf_read_1mbit_to_psram_asm_proffs,s
	;cmp		#$8000
	;bcc		+
	;jmp.w	_pr1pa_read_single_sector
	sep		#$20
	; Make the diskio / transfer loop code execute from WRAM instead of from PSRAM
	; for the last Mbit of the current MByte, since we'll be overwriting that
	; memory with file data now.
	lda		#$7E
	sta.l	$7d0000+_disk_readprm_jump_to_psram+3
	rep		#$20
	lda		#$00E0
	sta		tcc__r1h
	stz		tcc__r1
+:

;	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
;	cmp		#3
;	bcs		+
;	jmp.w	_pr1pa_read_single_sector
;+:

	; if (remSectInClust > numSects) remSectInClust = numSects
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_numSects
	ina
	sta		tcc__r0
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
	cmp		tcc__r0
	bcc		+
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_numSects
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
+:

    ; prevClst+1 == fs->curr_clust ?
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst
    clc
    adc     #1
    sta     tcc__r0
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst+2
    adc     #0
    sta     tcc__r0h
    ldy     #FATFS_curr_clust
    lda     [tcc__r2],y
    cmp     tcc__r0
    bne     +
    ldy     #FATFS_curr_clust+2
    lda     [tcc__r2],y
    cmp     tcc__r0h
    bne     +
    
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
    clc
    adc.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
    cmp     #$100
    bcs     +
    jmp.w   _pr1pa_skip_read
+:    
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst
    cmp     #$FFFF
    bne     +
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst+2
    cmp     #$FFFF
    bne     +
    jmp.w   _pr1pa_skip_read
+:    
    
	; disk_read_psram_multi(prbank, proffs, firstSector, contiguousSectors);
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
	pha
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector+2
	pha
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector
    pha
	lda		_pf_read_1mbit_to_psram_asm_proffs+6,s
	pha
	lda		_pf_read_1mbit_to_psram_asm_prbank+8,s
	pha
	jsl 	$7d0000+disk_read_psram_multi_asm  
	pla
	pla
	pla
	pla
	pla
	lda.w	FatFs
	sta		tcc__r2
	lda.w	FatFs+2
	sta		tcc__r2h
	
	lda		tcc__r0
	beq		+
	cmp		#2						; RES_WRPRT
	bne		++
	lda		#6						; FR_STREAM_ERR
	bra		+++
++:
	lda		#1						; FR_DISK_ERR
+++:
	sta		tcc__r0
	sep		#$20
	ldy		#FATFS_flag
	lda		#0
	sta		[tcc__r2],y
	rep		#$20
	jmp		_pr1pa_return
+:

    ; firstSector = fs->dsect
    ldy     #FATFS_dsect
    lda     [tcc__r2],y
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector
    iny
    iny
    lda     [tcc__r2],y
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector+2

    ; prbank:proffs += contiguousSectors << 9
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
    sta     tcc__r0
    stz     tcc__r0h
    .rept 9
    asl     tcc__r0
    rol     tcc__r0h
    .endr
    lda     _pf_read_1mbit_to_psram_asm_proffs,s
    clc
    adc     tcc__r0
    sta     tcc__r0
    sta     _pf_read_1mbit_to_psram_asm_proffs,s
    lda     _pf_read_1mbit_to_psram_asm_prbank,s
    adc     tcc__r0h
    sta     tcc__r0h
    sta     _pf_read_1mbit_to_psram_asm_prbank,s
    
    lda     #0
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
_pr1pa_skip_read:

    ; prevClst = fs->curr_clust
    ldy     #FATFS_curr_clust
    lda     [tcc__r2],y
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst
    ldy     #FATFS_curr_clust+2
    lda     [tcc__r2],y
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst+2
    
    ; contiguousSectors += remSectInClust
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
    clc
    adc.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
    sta.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
    
	; numSects -= remSectInClust
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_numSects
	sec
	sbc.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
	sta.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_numSects

	; fs->csect += remSectInClust - 1
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
	dea
	sta		tcc__r0
	ldy		#FATFS_csect
	sep		#$20
	lda		[tcc__r2],y
	clc
	adc		tcc__r0
	sta		[tcc__r2],y
	rep		#$20

    ; fs->fptr += remSectInClust << 9
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust
	sta		tcc__r0
	stz		tcc__r0h
	.rept 9
	asl		tcc__r0
	rol		tcc__r0h
	.endr
	clc
	ldy		#FATFS_fptr
	lda		[tcc__r2],y
	adc		tcc__r0
	sta		[tcc__r2],y
	iny
	iny
	lda		[tcc__r2],y
	adc		tcc__r0h
	sta		[tcc__r2],y
	
	;;jmp		_pr1pa_while_numSects_next

_pr1pa_while_numSects_next:
	lda.w	__tccs__FUNC_pf_read_1mbit_to_psram_asm_numSects
	beq		+
	jmp.w	_pr1pa_while_numSects
+:

    sep     #$20
    lda     #$7E
    sta.l   $7d0000+_disk_readprm_jump_to_psram+3
    rep     #$20
    ; Perform any pending read that needs to be done
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
    beq     +

    ; disk_read_psram_multi(prbank, proffs, firstSector, contiguousSectors);
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors
    pha
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector+2
    pha
    lda.w   __tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector
    pha
    lda     _pf_read_1mbit_to_psram_asm_proffs+6,s
    pha
    lda     _pf_read_1mbit_to_psram_asm_prbank+8,s
    pha
    jsl     $7d0000+disk_read_psram_multi_asm  
    pla
    pla
    pla
    pla
    pla
    lda.w   FatFs
    sta     tcc__r2
    lda.w   FatFs+2
    sta     tcc__r2h
    
    lda     tcc__r0
    beq     +
    cmp     #2                      ; RES_WRPRT
    bne     ++
    lda     #6                      ; FR_STREAM_ERR
    bra     +++
++:
    lda     #1                      ; FR_DISK_ERR
+++:
    sta     tcc__r0
    sep     #$20
    ldy     #FATFS_flag
    lda     #0
    sta     [tcc__r2],y
    rep     #$20
    jmp     _pr1pa_return
+:

	stz		tcc__r0			; FR_OK
_pr1pa_return:

	sep		#$20
	lda		#$DF
	sta.l	$7d0000+_disk_readprm_jump_to_psram+3
	
	lda		#$00
	sta.l	REG_MEMSEL
	rep		#$20
	
	ply
	plx
	plp
	rtl
	
.ends

.ramsection ".bss" bank $7e slot 2
__tccs__FUNC_pf_read_1mbit_to_psram_asm_dr dsb 2
__tccs__FUNC_pf_read_1mbit_to_psram_asm_clst dsb 4
__tccs__FUNC_pf_read_1mbit_to_psram_asm_basesect dsb 4
__tccs__FUNC_pf_read_1mbit_to_psram_asm_sect dsb 4
__tccs__FUNC_pf_read_1mbit_to_psram_asm_remain dsb 4
__tccs__FUNC_pf_read_1mbit_to_psram_asm_numSects dsb 2
__tccs__FUNC_pf_read_1mbit_to_psram_asm_remSectInClust dsb 2
__tccs__FUNC_pf_read_1mbit_to_psram_asm_contiguousSectors dsb 2
__tccs__FUNC_pf_read_1mbit_to_psram_asm_prevClst dsb 4
__tccs__FUNC_pf_read_1mbit_to_psram_asm_firstSector dsb 4
.ends
