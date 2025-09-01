;************************************************************************
;*	Microchip Technology Inc. 2002					*
;*	Assembler version: 2.0000					*
;*	Filename: 							*
;*		p18lcd.asm (main routine)   				*
;*	Dependents:							*
;*		p18demo.asm						*
;*		p18math.asm						*
;*		16f877.lkr						*
;*	March 14,2002							*
;* 	PICDEM 2 PLUS DEMO code. The  following functions are included 	*
;*	with this code:							*
;*		1. Voltmeter						*
;*			The center tap of R16 is connected to RA0, the	*
;*			A/D converter converts this analog voltage and	*
;*			the result is displayed on the LCD in a range	*
;*			from 0.00V - 5.00V.				*
;*		2. Buzzer						*
;*			The Piezo buzzer is connected to RC2 and is	*
;*			driven by the CCP1 module. The period and duty	*
;*			cycle are adjustable on the fly through the LCD	*
;*			and push-buttons.				*
;*		3. Temperature						*
;*			A TC74 Serial Digital Thermal Sensor is used to	*
;*			measure ambient temperature. The PIC and TC74	*
;* 			communicate using the MSSP module. The TC74 is	*
;*			connected to the SDA & SCL I/O pins of the PIC	*
;*			and functions as a slave.			*
;*		4. Clock						*
;*			This function is a real-time clock. When the	*
;*			mode is entered, time begins at 00:00:00. The 	*
;*			user can set the time if desired.		*
;************************************************************************

list p=18f452
#include <xc.inc>


#define	LCD_D4		RD0	; LCD data bits
#define	LCD_D5		RD1
#define	LCD_D6		RD2
#define	LCD_D7		RD3

#define	LCD_D4_DIR	TRISD0	; LCD data bits
#define	LCD_D5_DIR	TRISD1
#define	LCD_D6_DIR	TRISD2
#define	LCD_D7_DIR	TRISD3

#define	LCD_E		RA1	; LCD E clock
#define	LCD_RW		RA2	; LCD read/write line
#define	LCD_RS		RA3	; LCD register select line

#define	LCD_E_DIR	TRISA1	
#define	LCD_RW_DIR	TRISA2	
#define	LCD_RS_DIR	TRISA3	

#define	LCD_INS		0	
#define	LCD_DATA	1

;D_LCD_DATA
PSECT udata_acs
COUNTER:    DS 1
delay:	    DS 1
temp_wr:    DS 1
temp_rd:    DS 1

GLOBAL	temp_wr

PSECT PROG1,reloc=2,class=CODE


;***************************************************************************
	
LCDLine_1:
	movlw	0x80
	movwf	temp_wr,a
	rcall	i_write
	return
	GLOBAL	LCDLine_1

LCDLine_2:
	movlw	0xC0
	movwf	temp_wr,a
	rcall	i_write
	return
	GLOBAL	LCDLine_2

	;write data
d_write:
	movff	temp_wr,TXREG
	btfss	TRMT
	goto	$-2
	rcall	LCDBusy
	bsf	CARRY	
	rcall	LCDWrite
	return
	GLOBAL	d_write

	;write instruction
i_write:
	rcall	LCDBusy
	bcf	CARRY
	rcall	LCDWrite
	return
 	GLOBAL	i_write


rlcd MACRO MYREGISTER
 IF MYREGISTER = 1
	bsf	CARRY
	rcall	LCDRead
 ELSE
	bcf	CARRY
	rcall	LCDRead
 ENDIF
ENDM
;****************************************************************************




; *******************************************************************
LCDInit:
	clrf	PORTA,a
	
	bcf	LCD_E_DIR		;configure control lines
	bcf	LCD_RW_DIR
	bcf	LCD_RS_DIR
	
	movlw	00001110B
	movwf	ADCON1,a	

	movlw	0xff			; Wait ~15ms @ 20 MHz
	movwf	COUNTER,a
lil1:
	movlw	0xFF
	movwf	delay,a
	rcall	DelayXCycles
	decfsz	COUNTER,F,a
	bra	lil1
	
	movlw	00110000B		;#1 Send control sequence 
	movwf	temp_wr,a
	bcf	CARRY
	rcall	LCDWriteNibble

	movlw	0xff			;Wait ~4ms @ 20 MHz
	movwf	COUNTER,a
lil2:
	movlw	0xFF
	movwf	delay,a
	rcall	DelayXCycles
	decfsz	COUNTER,F,a
	bra	lil2

	movlw	00110000B		;#2 Send control sequence
	movwf	temp_wr,a
	bcf	CARRY
	rcall	LCDWriteNibble

	movlw	0xFF			;Wait ~100us @ 20 MHz
	movwf	delay,a
	rcall	DelayXCycles
						
	movlw	00110000B		;#3 Send control sequence
	movwf	temp_wr,a
	bcf	CARRY
	rcall	LCDWriteNibble

		;test delay
	movlw	0xFF			;Wait ~100us @ 20 MHz
	movwf	delay,a
	rcall	DelayXCycles


	movlw	00100000B		;#4 set 4-bit
	movwf	temp_wr,a
	bcf	CARRY
	rcall	LCDWriteNibble

	rcall	LCDBusy			;Busy?
				
	movlw	00101000B		;#5   Function set
	movwf	temp_wr,a
	rcall	i_write

	movlw	00001101B		;#6  Display = ON
	movwf	temp_wr,a
	rcall	i_write
			
	movlw	00000001B		;#7   Display Clear
	movwf	temp_wr,a
	rcall	i_write

	movlw	00000110B		;#8   Entry Mode
	movwf	temp_wr,a
	rcall	i_write	

	movlw	10000000B		;DDRAM addresss 0000
	movwf	temp_wr,a
	rcall	i_write


	return

	GLOBAL	LCDInit	
; *******************************************************************








;****************************************************************************
;     _    ______________________________
; RS  _>--<______________________________
;     _____
; RW       \_____________________________
;                  __________________
; E   ____________/                  \___
;     _____________                ______
; DB  _____________>--------------<______
;
LCDWriteNibble:
	btfss	CARRY		; Set the register select
	bcf	LCD_RS
	btfsc	CARRY	
	bsf	LCD_RS

	bcf	LCD_RW			; Set write mode

	bcf	LCD_D4_DIR		; Set data bits to outputs
	bcf	LCD_D5_DIR
	bcf	LCD_D6_DIR
	bcf	LCD_D7_DIR

	NOP				; Small delay,a
	NOP

	bsf	LCD_E			; Setup to clock data
	
	btfss	temp_wr, 7,a			; Set high nibble
	bcf	LCD_D7	
	btfsc	temp_wr, 7,a
	bsf	LCD_D7
	btfss	temp_wr, 6,a
	bcf	LCD_D6	
	btfsc	temp_wr, 6,a
	bsf	LCD_D6
	btfss	temp_wr, 5,a
	bcf	LCD_D5	
	btfsc	temp_wr, 5,a
	bsf	LCD_D5
	btfss	temp_wr, 4,a
	bcf	LCD_D4
	btfsc	temp_wr, 4,a
	bsf	LCD_D4	

	NOP
	NOP

	bcf	LCD_E			; Send the data

	return
; *******************************************************************





; *******************************************************************
LCDWrite:
;	rcall	LCDBusy
	rcall	LCDWriteNibble
	swapf	temp_wr,F,a
	rcall	LCDWriteNibble
	swapf	temp_wr,F,a

	return

	GLOBAL	LCDWrite
; *******************************************************************





; *******************************************************************
;     _____    _____________________________________________________
; RS  _____>--<_____________________________________________________
;               ____________________________________________________
; RW  _________/
;                  ____________________      ____________________
; E   ____________/                    \____/                    \__
;     _________________                __________                ___
; DB  _________________>--------------<__________>--------------<___
;
LCDRead:
	bsf	LCD_D4_DIR		; Set data bits to inputs
	bsf	LCD_D5_DIR
	bsf	LCD_D6_DIR
	bsf	LCD_D7_DIR		

	btfss	CARRY		; Set the register select
	bcf	LCD_RS
	btfsc	CARRY	
	bsf	LCD_RS

	bsf	LCD_RW			;Read = 1

	NOP
	NOP			

	bsf	LCD_E			; Setup to clock data

	NOP
	NOP
	NOP
	NOP

	btfss	LCD_D7			; Get high nibble
	bcf	temp_rd, 7,a
	btfsc	LCD_D7
	bsf	temp_rd, 7,a
	btfss	LCD_D6			
	bcf	temp_rd, 6,a
	btfsc	LCD_D6
	bsf	temp_rd, 6,a
	btfss	LCD_D5			
	bcf	temp_rd, 5,a
	btfsc	LCD_D5
	bsf	temp_rd, 5,a
	btfss	LCD_D4			
	bcf	temp_rd, 4,a
	btfsc	LCD_D4
	bsf	temp_rd, 4,a

	bcf	LCD_E			; Finished reading the data

	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP

	bsf	LCD_E			; Setup to clock data

	NOP
	NOP

	btfss	LCD_D7			; Get low nibble
	bcf	temp_rd, 3,a
	btfsc	LCD_D7
	bsf	temp_rd, 3,a
	btfss	LCD_D6			
	bcf	temp_rd, 2,a
	btfsc	LCD_D6
	bsf	temp_rd, 2,a
	btfss	LCD_D5			
	bcf	temp_rd, 1,a
	btfsc	LCD_D5
	bsf	temp_rd, 1,a
	btfss	LCD_D4			
	bcf	temp_rd, 0,a
	btfsc	LCD_D4
	bsf	temp_rd, 0,a

	bcf	LCD_E			; Finished reading the data

FinRd:
	return
; *******************************************************************






; *******************************************************************
LCDBusy:
	call	LongDelayLast
	return
					; Check BF
	rlcd	LCD_INS
	btfsc	temp_rd, 7,a
	bra	LCDBusy
	return

	GLOBAL	LCDBusy
; *******************************************************************






; *******************************************************************
DelayXCycles:
	decfsz	delay,F,a
	bra	DelayXCycles
	return
; *******************************************************************
	
Delay1ms:			;Approxiamtely at 4Mhz
	clrf	delay,a
Delay_1:
	nop
	decfsz	delay,a
	goto	Delay_1
	return
	GLOBAL Delay1ms




Delay30ms:	;more than 30 at 4 Mhz	
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms

	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms

	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	return
	GLOBAL Delay30ms
	
LongDelay:
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	return


LongDelayLast:
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	return

	END
