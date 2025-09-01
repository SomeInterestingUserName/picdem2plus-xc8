; Migrated to MPLAB XC8 assembly (pic-as 3.0) by Jiawei Chen
	
; Below is the header from the original source code:
	
;************************************************************************
;*	Microchip Technology Inc. 2002					*
;*	Assembler version: 2.0000					*
;*	Filename: 							*
;*		p18demo.asm (main routine)   				*
;*	Dependents:							*
;*		p18lcd.asm						*
;*		p18math.asm						*
;*		16f877.lkr						*
;*	March 14,2002							*
;* 	PICDEM 2 PLUS DEMO code. The following functions are included 	*
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
;*			and functions as a slave. Every 2 seconds, the	*
;*			temperature is logged into the external EEPROM  *
;*			in a specific memory location.			*
;*		4. Clock						*
;*			This function is a real-time clock. When the	*
;*			mode is entered, time begins at 00:00:00. The 	*
;*			user can set the time if desired.		*
;*									*
;*		The data that is sent to the LCD is also sent to the	*
;*		USART through the RS-232 port to be displayed on a PC	*
;*		HyperTerminal.						*
;************************************************************************

list p=18f452
#include <xc.inc>

CONFIG	"OSC"	=   "ECIO"  
CONFIG	"OSCS"	=   "OFF"
CONFIG	"PWRT"	=   "ON"
CONFIG	"BOR"	=   "OFF"
CONFIG	"WDT"	=   "OFF"
CONFIG	"CCP2MUX"   =	"OFF"
CONFIG	"LVP"	=   "OFF"
CONFIG	"CP0"	=   "OFF"
CONFIG	"CPB"	=   "OFF"
CONFIG	"WRT0"	=   "OFF"
CONFIG	"WRTC"	=   "OFF"
CONFIG	"EBTR0"	=   "OFF"
CONFIG	"EBTRB"	=   "OFF"

#define	scroll_dir	TRISA4
#define	scroll		RA4	;Push-button RA4 on PCB
#define	select_dir	TRISB0		
#define	select		RB0	;Push-button RB0 on PCB

EXTRN	LCDInit, temp_wr, d_write, i_write, LCDLine_1, LCDLine_2
EXTRN	UMUL0808L, UDIV1608L, AARGB0, AARGB1, BARGB0


ssprw	macro				;check for idle SSP module routine
	movlw	0x00
	andwf	SSPCON2,W,a
	sublw	0x00
	btfss	ZERO
	bra	$-8

	btfsc	R_W
	bra	$-2
endm

;variables	UDATA
PSECT udata_acs
ptr_pos:	DS 1
ptr_count:	DS 1
temp_1:		DS 1
temp_2:		DS 1
temp_3:		DS 1
cmd_byte:	DS 1
temperature:	DS 1
LSD:		DS 1
MsD:		DS 1
MSD:		DS 1
seconds:	DS 1
minutes:	DS 1
hours:		DS 1

NumH:		DS 1
NumL:		DS 1
TenK:		DS 1
Thou:		DS 1
Hund:		DS 1
Tens:		DS 1
Ones:		DS 1

PSECT STARTUP,class=CODE,reloc=2
begin:
	NOP
	goto	start
	NOP
	NOP
	NOP
;PSECT PROG1,class=CODE
;ORG 0x1000
PSECT stringtable,class=CONST	
;prod_table:				;table for production code
;	;	"XXXXXXXXXXXXXXXX"
;	;				ptr:
;	dw	"PRODUCTION TEST "	;0
;	dw	"   COMPLETE     "	;16
;	dw	"   32.768KHz    "	;32
;	dw	"  TC74 Sensor   "	;48
;	dw	" Press RA4, RB0 "	;64
;	dw	"   Microchip	 "      ;80
;	dw	" PICDEM 2 PLUS  "	;96
;	dw	"  		 "	;112  blank line display
;	dw	"     RS-232     "	;128
;	dw	"     		 "	;144
;	dw	"FAIL!FAIL!FAIL! "	;160
;	dw	"     EEPROM     "	;176
;	dw	"Microchip Temp= "	;192
;	dw	"<---- LED Test	 "	;208
;	dw	" Potentiometer	 "	;224

stan_table:				;table for standard code
	;	"XXXXXXXXXXXXXXXX"
	;				ptr:
	db	"   Voltmeter    "	;0
	db	"     Buzzer     "	;16
	db	"  Temperature   "	;32
	db	"     Clock      "	;48
	db	"RA4=Next RB0=Now"	;64
	db	"   Microchip    "      ;80
	db	" PICDEM 2 PLUS  "	;96
	db	"RA4=Set RB0=Menu"	;112
	db	"RA4= --> RBO= ++"	;128
	db	"   RB0 = Exit   "	;144
	db	"Volts =         "	;160
	db	"Prd.=128 DC=128 "	;176
	
psect code
start:	
	call LCDInit
	
	movlw	10100100B		;initialize USART
	movwf	TXSTA,a			;8-bit, Async, High Speed
	movlw	25
	movwf	SPBRG,a			;9.6kbaud @ 4MHz
	movlw	10010000B
	movwf	RCSTA,a

	bcf	TRISC2			;configure CCP1 module for buzzer
;	bcf	TRISC,6
	movlw	0x80
	movwf	PR2,a			;initialize PWM period 
	movlw	0x80			;initialize PWM duty cycle
	movwf	CCPR1L,a
	bcf	CCP1X
	bcf	CCP1Y
	
	movlw	0x05			;postscale 1:1, prescaler 4, Timer2 ON
	movwf	T2CON,a
		
	bsf	scroll_dir			;make switch RA4 an Input
	bsf	select_dir			;make switch RB0 an Input


;**************** STANDARD CODE MENU SELECTION *******************
			;Introduction
	movlw	80			;send "Microchip" to LCD
	movwf	ptr_pos,a
	call	stan_char_1

	movlw	96			;send "PICDEM 2 PLUS" to LCD
	movwf	ptr_pos,a
	call	stan_char_2
	call	delay_1s		;delay for display
	call	delay_1s		;delay for display
	
menu:
;------------------ VOLT MEASUREMENT  ----------------------------
	btfss	scroll			;wait for RA4 release
	goto	$-2		
	btfss	select			;wait for RB0 release
	goto	$-2

	movlw	0x00			;voltmeter
	movwf	ptr_pos,a
	call	stan_char_1

	movlw	64			;RA4=Next  RB0=Now
	movwf	ptr_pos,a
	call	stan_char_2
v_wait:
	btfss	select			;voltmeter measurement ??
	bra	voltmeter
	btfsc	scroll			;next mode ??
	bra	v_wait			;NO
	btfss	scroll			;YES
	bra	$-2			;wait for RA4 release
;------------------ BUZZER --------------------------------------
menu_buz:
	btfss	select			;wait for RB0 release
	bra	$-2			

	movlw	16			;buzzer
	movwf	ptr_pos,a
	call	stan_char_1

	movlw	64			;RA4=Next  RB0=Now
	movwf	ptr_pos,a
	call	stan_char_2
b_wait:
	btfss	select			;Buzzer sound ??
	goto	buzzer			;YES
	btfsc	scroll			;NO, next mode ??
	goto	b_wait			;NO
	btfss	scroll			;YES
	bra	$-2			;wait for RA4 release
;----------------- TEMPERATURE MEASUREMENT ----------------------
menu_temp:
	btfss	scroll			;wait for RA4 release
	bra	$-2		

	movlw	32			;temperature
	movwf	ptr_pos,a
	call	stan_char_1

	movlw	64			;RA4=Next  RB0=Now
	movwf	ptr_pos,a
	call	stan_char_2
t_wait:
	btfss	select			;temperature measurement ??
	bra	temp			;YES
	btfsc	scroll			;NO, next mode ??
	bra	t_wait			;NO
	btfss	scroll			;YES
	bra	$-2			;wait for release
;------------------ CLOCK TIME ----------------------------------
menu_clock:
	btfss	select			;wait for RB0 release
	bra	$-2		

	movlw	48			;clock
	movwf	ptr_pos,a
	call	stan_char_1

	movlw	64			;RA4=Next  RB0=Now
	movwf	ptr_pos,a
	call	stan_char_2
c_wait:
	btfss	select			;goto time ??
	bra	clock			;YES
	btfsc	scroll			;NO, next mode ??
	bra	c_wait			;NO
	btfss	scroll			;YES
	bra	$-2			;wait for release
;-------------------------------------------------------------------
	bra	menu			;begining of menu
	return

;*******************************************************************




;************* STANDARD USER CODE **********************************

;------------- Voltmeter--------------------------------------------
voltmeter:
	btfss	select			;wait for RB0 release
	bra	$-2

	movlw	01000001B		;configure A/D converter	
	movwf	ADCON0,a			;turn A/D on
	movlw	00001110B		;RA0 = analog input
	movwf	ADCON1,a

	movlw	160			;send "Volts = " to the LCD
	movwf	ptr_pos,a
	call	stan_char_1
volts_again:
	bsf	GO		;start conversion
	btfsc	GO
	bra	$-2
	movf	ADRESH,W,a

	movwf	AARGB0,a			;move adresh into AARGB1
	movlw	0xC3			;19.5mV/step   0xC3 = 195
	movwf	BARGB0,a
	call	UMUL0808L
	
	movlw	0x64			;divide result by 100 (0x64)
	movwf	BARGB0,a
	call	UDIV1608L
	
	movf	AARGB0,W,a		;prepare for 16-bit binary to BCD
	movwf	NumH,a
	movf	AARGB1,W,a
	movwf	NumL,a
	call	bin16_bcd		;get volts ready for LCD
	
	call	LCDLine_2		;display A/D result on 2nd line
	movf	Hund,W,a			;get hunds
	call	bin_bcd
	movf	LSD,W,a			;send high digit from the LSD #.xx	
	movwf	temp_wr,a
	call	d_write
	movlw	'.'			;send decimal point "."
	movwf	temp_wr,a
	call	d_write
	
	movf	Tens,W,a			;get tens
	call	bin_bcd
	movf	LSD,W,a			;send low digit   x.#x
	movwf	temp_wr,a
	call	d_write

	movf	Ones,W,a			;get ones
	call	bin_bcd
	movf	LSD,W,a			;send low digit   x.x#
	movwf	temp_wr,a
	call	d_write
	movlw	'V'			;send "V" unit
	movwf	temp_wr,a
	call	d_write

	movlw	0x20			;3 spaces	
	movwf	temp_wr,a
	call	d_write
	movlw	0x20			
	movwf	temp_wr,a
	call	d_write
	movlw	0x20			
	movwf	temp_wr,a
	call	d_write
	movlw	'R'			;send "RB0=Exit" to LCD
	movwf	temp_wr,a
	call	d_write
	movlw	'B'			
	movwf	temp_wr,a
	call	d_write
	movlw	'0'			
	movwf	temp_wr,a
	call	d_write
	movlw	'='			
	movwf	temp_wr,a
	call	d_write
	movlw	'E'			
	movwf	temp_wr,a
	call	d_write
	movlw	'x'		
	movwf	temp_wr,a
	call	d_write
	movlw	'i'			
	movwf	temp_wr,a
	call	d_write
	movlw	't'			
	movwf	temp_wr,a
	call	d_write
	movlw	0x20			;2 spaces	
	movwf	temp_wr,a
	call	d_write
	movlw	0x20			
	movwf	temp_wr,a
	call	d_write

	movlw	0x0d ;\r			;move data into TXREG
	movwf	TXREG,a			;carriage return
	btfss	TRMT		;wait for data TX
	bra	$-2

	btfss	select			;exit volt measurement ??
	bra	menu_buz			;YES
	bra	volts_again		;NO, do conversion again

;--------------------- BUZZER --------------------------------------
buzzer:
	btfss	select			;wait for RB0 release
	bra	$-2

	movlw	0x80			;start at these PWM values
	movwf	PR2,a			;initialize PWM period 
	movlw	0x80			
	movwf	CCPR1L,a			;initialize PWM duty cycle
	
	call	LCDLine_1
	movlw	176			;send "Prd.=128 DC=128" to LCD
	movwf	ptr_pos,a
	call	stan_char_1
	call	LCDLine_2
	movlw	128			;send "RA4= -> RB0 = ++" to LCD
	movwf	ptr_pos,a
	call	stan_char_2
		
	movlw	0x0F			;turn buzzer on	
	movwf	CCP1CON,a	
		
pr2_again:			
	btfsc	select			;increment PR2 ???
	bra	pr2_out			;NO
	call	delay_100ms		;YES
	call	delay_100ms		
	incf	PR2,F,a			;increment PR2
pr2_out:
	movlw	0x85			;move cursor into position
	movwf	temp_wr,a
	call	i_write

pol1:
	btfss	scroll			;goto increment CCPR1L
	bra	inc_dc
	btfsc	select			;wait for RB0 press
	bra	pol1

	movf	PR2,W,a			;send PR2 register to conversion
	call	bin_bcd

	movf	MSD,W,a			;send high digit
	movwf	temp_wr,a
	call	d_write
	movf	MsD,W,a			;send middle digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send low digit
	movwf	temp_wr,a
	call	d_write

	bra	pr2_again		

;------------------------
		;adjust Duty Cycle
inc_dc:
	btfss	scroll			;wait for button release
	bra	$-2

inc_ccpr1l:	
	btfsc	select			;increment CCPR1L ???
	goto	ccpr1l_out		;NO
	call	delay_100ms		;YES
	call	delay_100ms
	incf	CCPR1L,F,a		;increment CCPR1L
ccpr1l_out:
	movlw	0x8C			;move cursor into position
	movwf	temp_wr,a
	call	i_write

col1:
	btfss	scroll			;exit?
	bra	pwm_out
	btfsc	select			;wait for RB0 press
	bra	col1
	
	movf	CCPR1L,W,a		;send PR2 register to conversion
	call	bin_bcd
	
	movf	MSD,W,a			;send high digit
	movwf	temp_wr,a
	call	d_write
	movf	MsD,W,a			;send middle digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send low digit
	movwf	temp_wr,a
	call	d_write			
	bra	inc_ccpr1l

pwm_out:
	movlw	0
	movwf	CCP1CON,a			;turn buzzer off
	bra	menu_temp

;---------------------- Temperature -------------------------------- 
temp:
;	This code if for the TC74A5-5.0VAT temperature sensor
;		1st. Check if temperature is ready to be read in config reg.
;		2nd. If ready, retireve temperatute in hex.
;		     If not ready, check config register again.

	bsf	TRISC3			;initialize MSSP module
	bsf	TRISC4
	movlw	00101000B
	movwf	SSPCON1,a
	bsf	SMP
	movlw	5
	movwf	SSPADD,a

	bcf	TMR1IF
	clrf	TMR1H,a			;load Timer1 for 2 sec overflow
	clrf	TMR1L,a

get_temp:
	movlw	0x01			;config register command byte
	movwf	cmd_byte,a
temp_now:
	bsf	CKE		;SMBUS spec for TC74

	bsf	SEN		;write to TC74
	btfsc	SEN
	bra	$-2	
	movlw	10011010B		;send TC74 ADDRESS (write)
	movwf	SSPBUF,a
	ssprw
	btfsc	ACKSTAT		;ack?
	bra	$-2

	movf	cmd_byte,W,a		;send COMMAND byte (config)
	movwf	SSPBUF,a
	ssprw
	btfsc	ACKSTAT		;ack?
	bra	$-2

	bsf	RSEN		;send repeated start
	btfsc	RSEN
	bra	$-2
	movlw	10011011B		;send TC74 ADDRESS (read)
	movwf	SSPBUF,a
	ssprw				;module idle?
	btfsc	ACKSTAT		;ack?
	bra	$-2

	bsf	RCEN		;enable receive mode
	btfsc	RCEN
	bra	$-2

	movf	SSPBUF,W,a		;retrieve config reg or temp reg
	
	bsf	ACKDT		;send NOT-ACK
	bsf	ACKEN
	btfsc	ACKEN
	bra	$-2
			
	bsf	PEN		;stop
	btfsc	PEN
	bra	$-2
	
	btfss	cmd_byte,0,a		;config command OR temp command
	bra	convert_temp		;get temperature ready for display

	andlw	0x40			;is temp ready ??
	sublw	0x40
	btfss	ZERO
	bra	get_temp
	movlw	0x00			;temp is ready for reading
	movwf	cmd_byte,a		;send temp register command
	bra	temp_now

convert_temp:
	movwf	temperature,a
	call	bin_bcd			;get temp ready for LCD
	call	LCDLine_1
	
	movlw	'T'			;send "Temp=" to LCD
	movwf	temp_wr,a	
	call	d_write
	movlw	'e'
	movwf	temp_wr,a	
	call	d_write
	movlw	'm'
	movwf	temp_wr,a	
	call	d_write
	movlw	'p'
	movwf	temp_wr,a	
	call	d_write
	movlw	0x20			;space
	movwf	temp_wr,a	
	call	d_write
	movlw	'='
	movwf	temp_wr,a	
	call	d_write

	movlw	0x20			;space
	movwf	temp_wr,a	
	call	d_write

	movf	MSD,W,a			;send high digit
	movwf	temp_wr,a
	call	d_write
	movf	MsD,W,a			;send middle digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send low digit
	movwf	temp_wr,a
	call	d_write
	movlw	'C'			;send "C" for celcius
	movwf	temp_wr,a	
	call	d_write

	movlw	0x20			;space
	movwf	temp_wr,a	
	call	d_write
	movlw	0x20			;space
	movwf	temp_wr,a	
	call	d_write
	movlw	0x20			;space
	movwf	temp_wr,a	
	call	d_write
	
	call	LCDLine_2		;send "RB0 = Exit" to LCD
	movlw	144
	movwf	ptr_pos,a
	call	stan_char_2
	
	btfss	select			;wait for RB0 release
	bra	$-2
	call	delay_100ms
	btfss	select			;exit ?
	bra	menu_clock		;YES, goto main menu
	btfsc	TMR1IF		;2 second overflow occur ??
	call	write_eeprom		;YES
	bra	get_temp		;NO, get temperature again

	
;----------------- CLOCK ------------------------------------------

clock:
	btfss	select			;wait for RB0 button release
	bra	$-2
	movlw	0x0F			;intitialize TIMER1
	movwf	T1CON,a
	clrf	seconds,a
	clrf	minutes,a
	clrf	hours,a
overflow:	
	bcf	TMR1IF
	movlw	0x80		
	movwf	TMR1H,a			;load regs for 1 sec overflow
	clrf	TMR1L,a

	incf	seconds,F,a		;increment seconds
	movf	seconds,W,a
	sublw	60
	btfss	ZERO		;increment minutes ?
	bra	clk_done
	incf	minutes,F,a		
	clrf	seconds,a

	movf	minutes,W,a
	sublw	60
	btfss	ZERO		;increment hours ?
	bra	clk_done	
	incf	hours,F,a			
	clrf	minutes,a

	movf	hours,W,a
	sublw	13
	btfss	ZERO
	bra	clk_done
	movlw	1			;start a new 12 hour period
	movwf	hours,a
clk_done:
	movf	hours,W,a			;send hours to LCD
	call	bin_bcd

	call	LCDLine_1		;place time on line 1

	movf	MsD,W,a			;send middle digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send low digit
	movwf	temp_wr,a
	call	d_write	
	movlw	0x3A			;send  :   colon
	movwf	temp_wr,a
	call	d_write

	movf	minutes,W,a		;send minutes to LCD
	call	bin_bcd

	movf	MsD,W,a			;send middle digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send low digit
	movwf	temp_wr,a
	call	d_write	
	movlw	0x3A			; send :   colon
	movwf	temp_wr,a
	call	d_write

	movf	seconds,W,a		;send seconds to LCD
	call	bin_bcd

	movf	MsD,W,a			;send middle digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send low digit
	movwf	temp_wr,a
	call	d_write

	movlw	0x20			;send 3 spaces after 00:00:00
	movwf	temp_wr,a
	call	d_write
	movlw	0x20
	movwf	temp_wr,a
	call	d_write
	movlw	0x20
	movwf	temp_wr,a
	call	d_write
	
	movlw	112			;send "RA4=Dn RB0=Menu" to LCD
	movwf	ptr_pos,a
	call	stan_char_2

	btfss	scroll			;set time ??
	bra	set_time

	btfss	select			;return to main menu ??
	bra	menu
	
	btfss	TMR1IF		;has timer1 overflowed ?	
	bra	$-2			;NO, wait til overflow
	bra	overflow		;YES

	return
;*******************************************************************









;************************** ROUTINES ******************************
;******************************************************************
;******************************************************************

;----Standard code, Place characters on line-1--------------------------
stan_char_1:
	call	LCDLine_1		;mvoe cursor to line 1 
	movlw	16			;1-full line of LCD
	movwf	ptr_count,a
	movlw	low highword stan_table
	movwf	TBLPTRU,a
	movlw	high stan_table
	movwf	TBLPTRH,a
	movlw	low stan_table
	movwf	TBLPTRL,a
	movf	ptr_pos,W,a
	addwf	TBLPTRL,F,a
	clrf	WREG,a
	addwfc	TBLPTRH,F,a
	addwfc	TBLPTRU,F,a

stan_next_char_1:
	tblrd*+
	movff	TABLAT,temp_wr		
	call	d_write			;send character to LCD

	decfsz	ptr_count,F,a		;move pointer to next char
	bra	stan_next_char_1

	movlw	0x0a;"\n"			;move data into TXREG
	movwf	TXREG,a			;next line
	btfss	TRMT		;wait for data TX
	goto	$-2
	movlw	0x0d;"\r"			;move data into TXREG
	movwf	TXREG,a			;carriage return
	btfss	TRMT		;wait for data TX
	goto	$-2

	return

;----Standard code, Place characters on line-2--------------------------
stan_char_2:	
	call	LCDLine_2		;move cursor to line 2 
	movlw	16			;1-full line of LCD
	movwf	ptr_count,a
	movlw	low highword stan_table
	movwf	TBLPTRU,a
	movlw	high stan_table
	movwf	TBLPTRH,a
	movlw	low stan_table
	movwf	TBLPTRL,a
	movf	ptr_pos,W,a
	addwf	TBLPTRL,F,a
	clrf	WREG,a
	addwfc	TBLPTRH,F,a
	addwfc	TBLPTRU,F,a

stan_next_char_2:
	tblrd*+
	movff	TABLAT,temp_wr
	call	d_write			;send character to LCD

	decfsz	ptr_count,F,a		;move pointer to next char
	bra	stan_next_char_2

	movlw	0x0a;"\n"			;move data into TXREG
	movwf	TXREG,a			;next line
	btfss	TRMT		;wait for data TX
	goto	$-2
	movlw	0x0d;"\r"			;move data into TXREG
	movwf	TXREG,a			;carriage return
	btfss	TRMT		;wait for data TX
	goto	$-2

	return
;----------------------------------------------------------------------


;------------------ 100ms Delay --------------------------------
delay_100ms:
	movlw	0xFF
	movwf	temp_1,a
	movlw	0x83
	movwf	temp_2,a

d100l1:
	decfsz	temp_1,F,a
	bra	d100l1
	decfsz	temp_2,F,a
	bra	d100l1
	return

;---------------- 1s Delay -----------------------------------
delay_1s:
	movlw	0xFF
	movwf	temp_1,a
	movwf	temp_2,a
	movlw	0x05
	movwf	temp_3,a
d1l1:
	decfsz	temp_1,F,a
	bra	d1l1
	decfsz	temp_2,F,a
	bra	d1l1
	decfsz	temp_3,F,a
	bra	d1l1
	return	

;---------------- Set Current Time ----------------------------
set_time:
	movlw	128			;send "RA4= --> RBO= ++" to LCD
	movwf	ptr_pos,a
	call	stan_char_2
set_time_again:
	btfss	scroll			;wait for button release
	bra	$-2

	call	LCDLine_1		;start at 0x00 on LCD

	btfss	select			;wait for RB0 button release
	bra	$-2
	call	delay_100ms			
	btfss  	select			;increment hours (tens) ?
	bra	inc_hours
	bra	next_digit
inc_hours:	
	incf	hours,a
	movf	hours,W,a		;check if hours has passed 12 ?
	sublw	13
	btfss	ZERO
	bra	next_digit
	clrf	hours,a			;YES, reset hours to 00
next_digit:
	btfss	scroll			;move to next digit
	bra	inc_mins
	movf	hours,W,a		

	call	bin_bcd			;get hours ready for display
	
	movf	MsD,W,a			;send tens digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send ones digit
	movwf	temp_wr,a
	call	d_write	
	movlw	0x3A			;send   :   colon
	movwf	temp_wr,a
	call	d_write

	bra	set_time_again
	
inc_mins:
	btfss	scroll			;wait for RA4 button release
	bra	$-2
	call	LCDLine_1
	movlw	0x14			;shift cursor to right 3 places
	movwf	temp_wr,a
	call	i_write
	movlw	0x14
	movwf	temp_wr,a
	call	i_write
	movlw	0x14
	movwf	temp_wr,a
	call	i_write
	
	btfss	select			;wait for RB0 button release
	bra	$-2
	call	delay_100ms
	btfss  	select			;increment minutes (tens) ?
	bra	inc_minutes
	bra	next_digit?
inc_minutes:	
	incf	minutes,a
	movf	minutes,W,a		;check if hours has passed 12 ?
	sublw	60
	btfss	ZERO
	bra	next_digit?
	clrf	minutes,a
next_digit?:
	btfss	scroll			;move to next digit
	bra	set_time_done
	movf	minutes,W,a
		
	call	bin_bcd			;get minutes ready for display
	
	movf	MsD,W,a			;send tens digit
	movwf	temp_wr,a
	call	d_write
	movf	LSD,W,a			;send ones digit
	movwf	temp_wr,a
	call	d_write	
	movlw	0x3A			;send  :   colon
	movwf	temp_wr,a
	call	d_write	
	bra	inc_mins

set_time_done:
	btfss	scroll			;wait for RA4 button release
	bra	$-2
	bra	overflow
	
;---------------- Binary (8-bit) to BCD -----------------------
;		255 = highest possible result
bin_bcd:
	clrf	MSD,a
	clrf	MsD,a
	movwf	LSD,a		;move value to LSD
ghundreth:	
	movlw	100		;subtract 100 from LSD
	subwf	LSD,W,a
	btfss	CARRY	;is value greater then 100
	bra	gtenth		;NO goto tenths
	movwf	LSD,a		;YES, move subtraction result into LSD
	incf	MSD,F,a		;increment hundreths
	bra	ghundreth	
gtenth:
	movlw	10		;take care of tenths
	subwf	LSD,W,a
	btfss	CARRY
	bra	over		;finished conversion
	movwf	LSD,a
	incf	MsD,F,a		;increment tenths position
	bra	gtenth
over:				;0 - 9, high nibble = 3 for LCD
	movf	MSD,W,a		;get BCD values ready for LCD display
	xorlw	0x30		;convert to LCD digit
	movwf	MSD,a
	movf	MsD,W,a
	xorlw	0x30		;convert to LCD digit
	movwf	MsD,a
	movf	LSD,W,a
	xorlw	0x30		;convert to LCD digit
	movwf	LSD,a
	retlw	0

;---------------- Binary (16-bit) to BCD -----------------------
;		xxx = highest possible result
bin16_bcd:
	                       ; Takes number in NumH:NumL 
                                ; Returns decimal in 
                                ; TenK:Thou:Hund:Tens:Ones 
        swapf   NumH,W,a 
        andlw   0x0F
        addlw   0xF0
        movwf   Thou,a 
        addwf   Thou,F,a 
        addlw   0xE2 
        movwf   Hund,a 
        addlw   0x32 
        movwf   Ones,a 

        movf    NumH,W,a 
        andlw   0x0F 
        addwf   Hund,F,a 
        addwf   Hund,F,a 
        addwf   Ones,F,a 
        addlw   0xE9 
        movwf   Tens,a 
        addwf   Tens,F,a 
        addwf   Tens,F,a 

        swapf   NumL,W,a
        andlw   0x0F 
        addwf   Tens,F,a 
        addwf   Ones,F,a 

        rlcf     Tens,F,a 
        rlcf     Ones,F,a 
        comf    Ones,F,a 
        rlcf     Ones,F,a 

        movf    NumL,W,a 
        andlw   0x0F 
        addwf   Ones,F,a 
        rlcf     Thou,F,a 

        movlw   0x07 
        movwf   TenK,a 

        movlw   0x0A                             ; Ten 
Lb1: 
        decf    Tens,F,a 
        addwf   Ones,F,a 
        btfss   CARRY 
         bra   Lb1 
Lb2: 
        decf    Hund,F,a 
        addwf   Tens,F,a 
        btfss   CARRY 
         bra   Lb2 
Lb3: 
        decf    Thou,F,a 
        addwf   Hund,F,a 
        btfss   CARRY
         bra   Lb3 
Lb4: 
        decf    TenK,F,a 
        addwf   Thou,F,a 
        btfss   CARRY 
         bra   Lb4 

        retlw   0


;---------------------------- EEPROM WRITE -------------------------------
write_eeprom:	
	bsf	SEN		;start bit
	btfsc	SEN
	goto	$-2	
	movlw	10100000B		;send control byte (write)
	movwf	SSPBUF,a
	ssprw
	btfsc	ACKSTAT		;ack?
	goto	$-2

	movlw	0x00			;send slave address HIGH byte
	movwf	SSPBUF,a
	ssprw
	btfsc	ACKSTAT		;ack?
	goto	$-2

	movlw	0x05			;send slave address LOW byte(0x0005)
	movwf	SSPBUF,a
	ssprw
	btfsc	ACKSTAT		;ack?
	goto	$-2

	movf	temperature,w,a		;send slave DATA = temperature
	movwf	SSPBUF,a
	ssprw
	btfsc	ACKSTAT		;ack?
	goto	$-2

	bsf	PEN		;stop bit
	btfsc	PEN
	goto	$-2
		
	bcf	TMR1IF		;clear TIMER1 overflow flag
	clrf	TMR1L,a			;clear registers for next overflow
	clrf	TMR1H,a

	return

;*********************************************************************
end begin	
