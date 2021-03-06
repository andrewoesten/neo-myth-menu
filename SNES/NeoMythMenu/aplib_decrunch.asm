; apLib decruncher for SNES
; /Mic, 2010
;
; SNESC version
;
; Note: The compressed data must not cross a (64kB) bank boundary.

.include "hdr.asm"

.bank 3 slot 0
.section ".text_aplib" ;superfree

.DEFINE APLIB_ZP_BASE 	$80

; DirectPage variables
.DEFINE APLIB_LWM	APLIB_ZP_BASE
.DEFINE APLIB_SRC_PTR	APLIB_LWM+2
.DEFINE APLIB_BITS	APLIB_SRC_PTR+3
.DEFINE APLIB_BITCOUNT	APLIB_BITS+1
.DEFINE APLIB_OFFS	APLIB_BITCOUNT+1
.DEFINE APLIB_GAMMA APLIB_OFFS+2
.DEFINE APLIB_OFFS2 APLIB_GAMMA+2
.DEFINE APLIB_RAMCODE APLIB_OFFS2+3
.DEFINE APLIB_OLDDEST APLIB_RAMCODE+16
.DEFINE APLIB_PLANAR APLIB_OLDDEST+2
.DEFINE APLIB_COUNT APLIB_OFFS
.DEFINE APLIB_COUNT2 APLIB_OFFS2
.DEFINE APLIB_NUMBYTES APLIB_GAMMA


; In:
; A = source bank
; Y = source offset
; X = dest offset
; DBR = dest bank
aplib_decrunch:
	php				
	rep	#$30			

	phx
	phy
	phb

	sep		#$20
	ldx		#0
-:
	lda.l	aplib_ramcode_start,x
	sta		APLIB_RAMCODE,x
	inx
	cpx		#(aplib_ramcode_end-aplib_ramcode_start)
	bne		-
	rep		#$20
	
	lda		10,s			; source address (low 16 bits)
	tay
	lda		14,s			; dest address (low 16 bits)
	tax
	
	sep		#$20
	lda		12,s			; source bank
	
	sta		APLIB_SRC_PTR+2
	stz		APLIB_SRC_PTR+1
	stz		APLIB_SRC_PTR
	stz		APLIB_OFFS+1
	stz		APLIB_LWM+1

	lda		16,s			; dest bank
	pha
	plb
	
	lda		#1
	sta		APLIB_BITCOUNT
	
copy_byte:
	lda		[APLIB_SRC_PTR],y
	sta.w	$0000,x
	inx
	iny
next_sequence_init:
	stz		APLIB_LWM
next_sequence:
	jsr		get_bit
	bcc		copy_byte		; if bit sequence is %0..., then copy next byte
	jsr		get_bit
	bcc 	code_pair		; if bit sequence is %10..., then is a code pair
	jsr		get_bit
	stz		APLIB_OFFS
	stz		APLIB_OFFS+1
	bcs		+
	jmp		short_match		; if bit sequence is %110..., then is a short match
+:
	; The sequence is %111..., the next 4 bits are the offset (0-15)
	jsr		get_bit
	rol		APLIB_OFFS
	jsr		get_bit
	rol		APLIB_OFFS
	jsr		get_bit
	rol		APLIB_OFFS
	jsr		get_bit
	rol		APLIB_OFFS
	lda		APLIB_OFFS
	beq		write_byte		; if offset == 0, then write 0x00
	
	; If offset != 0, then write the byte at destination - offset
	phx
	rep		#$20
	txa
	sec
	sbc		APLIB_OFFS		; A = dest - offs
	tax
	sep		#$20
	lda.w	$0000,x
	plx
write_byte:
	sta.w	$0000,x
	inx
	jmp		next_sequence_init

	; Code pair %10...
code_pair:
	jsr		decode_gamma
	rep		#$20
	dec		APLIB_GAMMA
	dec		APLIB_GAMMA
	bne		normal_code_pair
	lda		APLIB_LWM
	bne		normal_code_pair
	jsr		decode_gamma
	rep		#$20
	lda		APLIB_OFFS2
	sta		APLIB_OFFS
	jmp		copy_code_pair
normal_code_pair:
	lda		APLIB_GAMMA 
	clc
	adc		APLIB_LWM
	dea
	sep		#$20
	sta		APLIB_OFFS+1
	lda		[APLIB_SRC_PTR],y
	iny
	sta		APLIB_OFFS
	jsr		decode_gamma
	rep		#$20
	lda		APLIB_OFFS
	cmp		#32000
	bcc		compare_1280
	inc		APLIB_GAMMA
compare_1280:
	cmp		#1280
	bcc		compare_128
	inc		APLIB_GAMMA
	jmp		continue_short_match
compare_128:
	cmp		#128
	bcs		continue_short_match
	inc		APLIB_GAMMA
	inc		APLIB_GAMMA
	jmp		continue_short_match
	
	sep		#$20
	
; get_bit: Get bits from the crunched data and insert the most significant bit in the carry flag.
get_bit:
	dec		APLIB_BITCOUNT
	bne		still_bits_left
	lda		#8
	sta		APLIB_BITCOUNT
	lda		[APLIB_SRC_PTR],y
	sta		APLIB_BITS
	iny
still_bits_left:
	asl		APLIB_BITS
	rts

; decode_gamma: Decode values from the crunched data using gamma code
decode_gamma:
	sep		#$20
	lda		#1
	sta		APLIB_GAMMA
	stz		APLIB_GAMMA+1
get_more_gamma:
	jsr		get_bit
	rol		APLIB_GAMMA
	rol		APLIB_GAMMA+1
	jsr		get_bit
	bcs		get_more_gamma
	rts

; Short match %110...
short_match:  
	rep		#$20
	lda		#1
	sta		APLIB_GAMMA
	sep		#$20
	lda		[APLIB_SRC_PTR],y	; Get offset (offset is 7 bits + 1 bit to mark if copy 2 or 3 bytes) 
	iny
	lsr		a
	beq		end_decrunch
	rol		APLIB_GAMMA
	sta		APLIB_OFFS
	stz		APLIB_OFFS+1
	rep		#$20
continue_short_match:
	lda		APLIB_OFFS
	sta		APLIB_OFFS2
copy_code_pair:
	phy
	txa
	sec
	sbc		APLIB_OFFS			; dest - offs
	txy
	tax
	
	sep 		#$20 
	phb 	
	pla	
	sta 		APLIB_RAMCODE+1	; overwrite source and dest banks for the MVN instruction in RAM
	sta 		APLIB_RAMCODE+2	; ...
	rep 		#$20	
	lda 		APLIB_GAMMA 		
	dea			   				; MVN copies A+1 bytes
	jml 		APLIB_RAMCODE 
	after_copy:
	tyx	
	
	ply
	lda		#1
	sta		APLIB_LWM
	sep		#$20
	jmp		next_sequence
	
end_decrunch:
	plb
	ply
	plx
	plp
	rtl

aplib_ramcode_start:
	mvn 0,0
	jml after_copy
aplib_ramcode_end:

.ends

