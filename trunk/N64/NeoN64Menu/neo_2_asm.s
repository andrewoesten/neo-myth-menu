
/*Interface : neo_2_asm.h*/

.section .text
.align 2 /*.align 3*/

.equ NEO_PSRAM_BRUTEFORCE_RETRIES,96

.set push
.set noreorder
.set noat

.global neo2_recv_sd_multi /*ChillyWilly's MASTERPIECE*/
.ent    neo2_recv_sd_multi
		neo2_recv_sd_multi:
        lui $15,0xB30E            /* $15 = 0xB30E0000*/
        ori $14,$4,0              /* $14 = buf*/
        ori $12,$5,0                /* $12 = count*/
		
        oloop:
        lui $11,0x0001              /* $11 = timeout = 64 * 1024*/

        tloop:
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        andi $2,$2,0x0100         /* eqv of (data>>8)&0x01*/
        beq $2,$0,getsect         /* start bit detected*/
        nop
        addiu $11,$11,-1
        bne $11,$0,tloop          /* not timed out*/
        nop
        beq $11,$0,___exit           /* timeout*/
        ori $2,$0,0                 /* res = FALSE*/

        getsect:
        ori $13,$0,128              /* $13 = long count*/

        gsloop:
        lw $2,0x6060($15)         /* rdMmcDatBit4 => -a-- -a--*/
        lui $10,0xF000            /* $10 = mask = 0xF0000000*/
        sll $2,$2,4               /* a--- a---*/

        lw $3,0x6060($15)         /* rdMmcDatBit4 => -b-- -b--*/
        and $2,$2,$10             /* a000 0000*/
        lui $10,0x0F00            /* $10 = mask = 0x0F000000*/
        and $3,$3,$10             /* 0b00 0000*/

        lw $4,0x6060($15)         /* rdMmcDatBit4 => -c-- -c--*/
        lui $10,0x00F0            /* $10 = mask = 0x00F00000*/
        or $11,$3,$2              /* $11 = ab00 0000*/
        srl $4,$4,4               /* --c- --c-*/

        lw $5,0x6060($15)         /* rdMmcDatBit4 => -d-- -d--*/
        and $4,$4,$10             /* 00c0 0000*/
        lui $10,0x000F            /* $10 = mask = 0x000F0000*/
        srl $5,$5,8               /* ---d ---d*/
        or $11,$11,$4             /* $11 = abc0 0000*/

        lw $6,0x6060($15)         /* rdMmcDatBit4 => -e-- -e--*/
        and $5,$5,$10             /* 000d 0000*/
        ori $10,$0,0xF000         /* $10 = mask = 0x0000F000*/
        sll $6,$6,4               /* e--- e---*/
        or $11,$11,$5             /* $11 = abcd 0000*/

        lw $7,0x6060($15)         /* rdMmcDatBit4 => -f-- -f--*/
        and $6,$6,$10             /* 0000 e000*/
        ori $10,$0,0x0F00         /* $10 = mask = 0x00000F00*/
        or $11,$11,$6             /* $11 = abcd e000*/
        and $7,$7,$10             /* 0000 0f00*/

        lw $8,0x6060($15)         /* rdMmcDatBit4 => -g-- -g--*/
        ori $10,$0,0x00F0         /* $10 = mask = 0x000000F0*/
        or $11,$11,$7             /* $11 = abcd ef00*/
        srl $8,$8,4               /* --g- --g-*/

        lw $9,0x6060($15)         /* rdMmcDatBit4 => -h-- -h--*/
        and $8,$8,$10             /* 0000 00g0*/
        ori $10,$0,0x000F         /* $10 = mask = 0x000000F*/
        or $11,$11,$8             /* $11 = abcd efg0*/

        srl $9,$9,8               /* ---h ---h*/
        and $9,$9,$10             /* 0000 000h*/
        or $11,$11,$9             /* $11 = abcd efgh*/

        sw $11,0($14)             /* save sector data*/
        addiu $13,$13,-1
        bne $13,$0,gsloop
        addiu $14,$14,4           /* inc buffer pointer */

        lw $2,0x6060($15)         /* rdMmcDatBit4 - just toss checksum bytes */
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/
        lw $2,0x6060($15)         /* rdMmcDatBit4*/

        lw $2,0x6060($15)         /* rdMmcDatBit4 - clock out end bit*/

        addiu $12,$12,-1          /* count--*/
        bne $12,$0,oloop          /* next sector*/
        nop

        ori $2,$0,1                 /* res = TRUE*/

		___exit:

		jr $ra
		nop

.end neo2_recv_sd_multi

.global neo_xferto_psram
.ent    neo_xferto_psram
		neo_xferto_psram:

	la $10,0xB0000000
	ori $8,$4,0
	addu $8,$8,$6
	addu $10,$10,$5

	0:
	
		lw $12,0($4)
		lw $13,4($4)

		lw $11,0($10)
		sw $12,0($10)
		lw $11,4($10)
		sw $13,4($10)

		addiu $10,$10,16
		addiu $4,$4,16

		bne $4,$8,0b
		nop	

	jr $ra
	nop

.end	neo_xferto_psram

/*
		ori $13,$0,NEO_PSRAM_BRUTEFORCE_RETRIES

		1:
			lw $11,($4)
			sw $11,($10)
			lw $12,($10)
			j 8f
			nop

			2:
					sw $11,($10)
					lw $12,($10)

				3:
					addi $13,$13,-1

					bltz $13,4f
					nop

					bne $11,$12,2b
					nop

					j 5f
					nop

						8:
							bne $11,$12,2b
							nop

					j 5f
					nop

				4:
					sw $11,($10)

					.rept 440
						nop
					.endr
				
			5:
				addiu $10,$10,4

		6:
			bne $4,$8,0b
			addiu $4,$4,4
	7:
*/

.set pop
.set reorder
.set at

