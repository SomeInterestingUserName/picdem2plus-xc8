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

EXTRN	LCDInit, temp_wr, d_write, i_write, LCDLine_1, LCDLine_2, Delay1ms,Delay30ms

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

;variables
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
;PROG1
PSECT stringtable,class=CONST	
	
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
	db	"RA4= + RBO= Exit"	;192
	db	"      LEDs      "	;208
	db	" Hacked in 2025 "	;224
	db	" by Jiawei Chen "	;240
	
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
		
	btfsc	scroll
	goto	intro
	goto	intro2

;**************** STANDARD CODE MENU SELECTION *******************
			;Introduction
intro:
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
;----------------- GPIO LEDs ------------------------------------
menu_leds:
	btfss	select			;wait for RB0 release
	bra	$-2		

	movlw	208			;leds
	movwf	ptr_pos,a
	call	stan_char_1

	movlw	64			;RA4=Next  RB0=Now
	movwf	ptr_pos,a
	call	stan_char_2
l_wait:
	btfss	select			;temperature measurement ??
	bra	leds			;YES
	btfsc	scroll			;NO, next mode ??
	bra	l_wait			;NO
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
	
	movlw	"P"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"r"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"d"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"."			
	movwf	TXREG,a	
	btfss	TRMT
	bra	$-2
	movlw	"="
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	
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
	
	movlw	0x0d ;\r			;move data into TXREG
	movwf	TXREG,a			;carriage return
	btfss	TRMT		;wait for data TX
	bra	$-2

	bra	pr2_again		

;------------------------
		;adjust Duty Cycle
inc_dc:
	btfss	scroll			;wait for button release
	bra	$-2
	
	movlw	0x0a ;\n		;print newline + carriage return
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	0x0d ;\r
	movwf	TXREG,a
	btfss	TRMT
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
	
	movlw	"D"			;send "DC="
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"C"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"="
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	
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
	
	movlw	0x0d ;\r
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	
	bra	inc_ccpr1l

pwm_out:
	movlw	0
	movwf	CCP1CON,a			;turn buzzer off
	movlw	0x0a
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	0x0d
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
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
	bra	menu_leds
	
	btfss	TMR1IF		;has timer1 overflowed ?	
	bra	$-2			;NO, wait til overflow
	bra	overflow		;YES

	return
	
;----------------- LEDs --------------------------------------------
; Cycles through hexadecimal 0x0-0xF on the LEDs (RB[3:0]) when RA4 is pressed
; This demo also shows a technique to have a GPIO pin (RB0) serve simultaneously
; as an input and an output by briefly switching its modes while the LEDs are
; illuminated to poll its status. When done correctly, the visual effect can be
; reduced to being barely perceptible. 
leds:
	btfss	select			;wait for RB0 release
	bra	$-2
		
	bcf	TRISB3
	bcf	TRISB2
	bcf	TRISB1
	bcf	TRISB0
	
	movlw	0xf0
	andwf	LATB,F,a   ; clear bottom 4 bits of PORTB
		
leds_again:			
	btfsc	scroll			;increment PR2 ???
	bra	leds_out			;NO
	call	delay_100ms		;YES
	call	delay_100ms		
	
	movlw	00001111B	; check if RA[3:0] are all 1's, if so, reset
	andwf	LATB,W,a
	comf	WREG,a
	btfsc	ZERO
	goto reset_leds_to_zero
	incf	LATB,F,a			;increment PR2
	goto leds_out

reset_leds_to_zero:
	movlw	0xf0
	andwf	LATB,F,a	    ; Set lower 4 bits of PORTB to 0
	
leds_out:
	call LCDLine_1

leds_pol:
	movlw	'R'
	movwf	temp_wr,a
	call	d_write
	movlw	'B'
	movwf	temp_wr,a
	call	d_write
	movlw	'['
	movwf	temp_wr,a
	call	d_write
	movlw	'3'
	movwf	temp_wr,a
	call	d_write
	movlw	':'
	movwf	temp_wr,a
	call	d_write
	movlw	'0'
	movwf	temp_wr,a
	call	d_write
	movlw	']'
	movwf	temp_wr,a
	call	d_write
	movlw	'='
	movwf	temp_wr,a
	call	d_write
	movlw	'0'
	movwf	temp_wr,a
	call	d_write
	movlw	'b'
	movwf	temp_wr,a
	call	d_write
	
	btfsc	RB3
	movlw	'1'
	btfss	RB3
	movlw	'0'
	movwf	temp_wr,a
	call	d_write
	
	btfsc	RB2
	movlw	'1'
	btfss	RB2
	movlw	'0'
	movwf	temp_wr,a
	call	d_write
	
	btfsc	RB1
	movlw	'1'
	btfss	RB1
	movlw	'0'
	movwf	temp_wr,a
	call	d_write
	
	btfsc	RB0
	movlw	'1'
	btfss	RB0
	movlw	'0'
	movwf	temp_wr,a
	call	d_write
	
	movlw	0x20; space			;move data into TXREG
	movwf	TXREG,a			;next line
	btfss	TRMT		;wait for data TX
	goto	$-2
	movlw	0x20; space			;move data into TXREG
	movwf	TXREG,a			;next line
	btfss	TRMT		;wait for data TX
	goto	$-2
	movlw	0x20; space			;move data into TXREG
	movwf	TXREG,a			;next line
	btfss	TRMT		;wait for data TXee
	goto	$-2
	
	call	LCDLine_2
	movlw	192			;send "RA4= + RB0 = Exit" to LCD
	movwf	ptr_pos,a
	call	stan_char_2
	
wait_leds:
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
	bsf	TRISB3	    ; turn LED pins into input to scan the button
	bsf	TRISB2
	bsf	TRISB1
	bsf	TRISB0
	call	Delay1ms    ; delay to allow debounce capacitor to charge
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms
	call	Delay1ms

	btfss	select	; RB0 = Exit
	goto	leds_exit
	bcf	TRISB3	; Set LEDs back to output after polling RB0
	bcf	TRISB2
	bcf	TRISB1
	bcf	TRISB0
	btfss	scroll	; RA4 = increment
	goto	leds_again
	goto	wait_leds

leds_exit:
	movlw	0xf0
	andwf	LATB,F,a   ; clear bottom 4 bits of PORTB
	bsf	TRISB3	   ; restore as inputs
	bsf	TRISB2
	bsf	TRISB1
	bsf	TRISB0
	
	bra	menu

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
	movff TABLAT,temp_wr	
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
	movff TABLAT,temp_wr	
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
	bra	inc_mins_before
	movlw	"H"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"o"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"u"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"r"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"s"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"="
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	
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
	
	movlw	0x0d
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	
	bra	set_time_again
	
inc_mins_before:
	movlw	0x0a
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	0x0d
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	bra inc_mins
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
	
	movlw	"M"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"i"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"n"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"s"
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	"="
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	
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
	
	movlw	0x0d
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	
	bra	inc_mins

set_time_done:
	btfss	scroll			;wait for RA4 button release
	bra	$-2
	movlw	0x0a
	movwf	TXREG,a
	btfss	TRMT
	bra	$-2
	movlw	0x0d
	movwf	TXREG,a
	btfss	TRMT
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

#define C4	238
#define Db4	224
#define D4	212
#define Eb4	200
#define E4	189
#define F4	178
#define Gb4	167
#define G4	158
#define Ab4	149
#define A4	141
#define Bb4	133
#define B4	126
#define C5	119
#define Db5	112
#define D5	105
#define Eb5	99
#define E5	94
#define F5	88
#define Gb5	83
#define G5	79
#define Ab5	74
#define A5	70
#define Bb5	66
#define B5	62
#define EMPTY	0
#define ENDSONG	255
	
intro2:	
	movlw	0x06			;postscale 1:1, prescaler 16, Timer2 ON
	movwf	T2CON,a
	call	play_notes
	; put everything back to where they were before
	movlw	0
	movwf	CCP1CON,a			;turn buzzer off
	movlw	0x05			;postscale 1:1, prescaler 4, Timer2 ON
	movwf	T2CON,a
	bsf	TRISB0
	bsf	TRISB1
	bsf	TRISB2
	bsf	TRISB3
	bcf	RB0
	bcf	RB1
	bcf	RB2
	bcf	RB3	
	
	movlw	224			
	movwf	ptr_pos,a
	call	stan_char_1
	movlw	240			
	movwf	ptr_pos,a
	call	stan_char_2
	call	delay_1s		;delay for display
	call	delay_1s		;delay for display
	
	goto	intro
	
play_notes:
	bcf	TRISB0			;prepare LED GPIOs to flash
	bcf	TRISB1
	bcf	TRISB2
	bcf	TRISB3
	bsf	RB0
	bcf	RB1
	bsf	RB2
	bcf	RB3
	movlw	0x0F			;turn buzzer on	
	movwf	CCP1CON,a	
	clrf	ptr_pos,b
	
	movlw	low highword notes
	movwf	TBLPTRU,a
	movlw	high notes
	movwf	TBLPTRH,a
	movlw	low notes
	movwf	TBLPTRL,a
	movf	ptr_pos,W,b
	addwf	TBLPTRL,F,a
	clrf	WREG,a
	addwfc	TBLPTRH,F,a
	addwfc	TBLPTRU,F,a
	
get_lcd_lines:
	
	tblrd*+
	movf	TABLAT,W,a
	movwf	PR2,a
	bcf	CARRY
	rrcf	PR2,W,a
	
	movwf	CCPR1L,a
	
	;flash LEDs
	movlw	0x0f
	xorwf	PORTB,F,a
	
	movlw	16			;1-full line of LCD
	movwf	ptr_count,b
	call	LCDLine_1		;mvoe cursor to line 1 

next_lcd_lines_1:
	tblrd*+
	movf	TABLAT,W,a
	movwf   temp_wr,b		
	call	d_write			;send character to LCD

	decfsz	ptr_count,F,b		;move pointer to next char
	bra	next_lcd_lines_1
	
	movlw	0x0a;"\n"			;move data into TXREG
	movwf	TXREG,a			;next line
	btfss	TRMT		;wait for data TX
	goto	$-2
	movlw	0x0d;"\r"			;move data into TXREG
	movwf	TXREG,a			;carriage return
	btfss	TRMT		;wait for data TX
	goto	$-2

	movlw	16
	movwf	ptr_count,b
	call	LCDLine_2
next_lcd_lines_2:
	tblrd*+
	movf	TABLAT,W,a
	movwf   temp_wr,b		
	call	d_write			;send character to LCD

	decfsz	ptr_count,F,b		;move pointer to next char
	bra	next_lcd_lines_2
	
	movlw	0x0a;"\n"			;move data into TXREG
	movwf	TXREG,a			;next line
	btfss	TRMT		;wait for data TX
	goto	$-2
	movlw	0x0d;"\r"			;move data into TXREG
	movwf	TXREG,a			;carriage return
	btfss	TRMT		;wait for data TX
	goto	$-2
	
	call Delay30ms	; smaller delay on first note to account for print time

play_next_note:
	tblrd*+
	; 255 means end of song
	movlw	ENDSONG
	cpfseq	TABLAT,a
	goto	not_end
	return
	
not_end:
	movf	TABLAT,W,a
	btfsc	ZERO; 0 means end of note sequence, start writing next LCD lines
	goto get_lcd_lines

	movwf	PR2,a
	bcf	CARRY
	rrcf	PR2,W,a
	
	movwf	CCPR1L,a
	
	;flash LEDs
	movlw	0x0f
	xorwf	PORTB,F,a
	    
	call	delay_200ms

	goto play_next_note

delay_200ms:
	call delay_100ms
	call delay_100ms
	return
	
psect data

; Note data consists of three kinds of structures:
; 1. First note plus first LCD lines: a single note followed by 16 LCD chars
;	This allows the note to play while LCD/UART data is being printed
;	so the song plays with no gaps or notes held for too long
; 2. Second line: 16 LCD chars
; 3. Note data: any number of notes ended by either EMPTY or ENDSONG

notes:	
	db  C5,"  Hail! to the  "
	db  "victors valiant!"
	db  C5,C5,C5,Ab4,Ab4,Bb4,Bb4,C5,C5,Ab4,Ab4,Bb4,Bb4,C5,C5,EMPTY
	db  Db5,"  Hail! to the  "
	db  "conq'ring heros!"
	db  Db5,Db5,Db5,Bb4,Bb4,C5,C5,Db5,Db5,Bb4,Bb4,C5,C5,Db5,Db5,EMPTY
	db  Eb5,"  Hail!  Hail!  "
	db  "  to  Michigan  "
	db  Eb5,Eb5,Eb5,F5,F5,F5,C5,C5,C5,Db5,Db5,Ab4,Ab4,EMPTY
	db  Bb4,"  the  leaders  "
	db  "   and  best!   "
	db  Bb4,C5,C5,C5,C5,Bb4,Bb4,Ab4,Ab4,Eb5,Eb5,G4,G4,Ab4,Ab4,Bb4,Bb4,EMPTY
	
	db  C5,"  Hail! to the  "
	db  "victors valiant!"
	db  C5,C5,C5,Ab4,Ab4,Bb4,Bb4,C5,C5,Ab4,Ab4,Bb4,Bb4,C5,C5,EMPTY
	db  Db5,"  Hail! to the  "
	db  "conq'ring heros!"
	db  Db5,Db5,Db5,Bb4,Bb4,C5,C5,Db5,Db5,Bb4,Bb4,C5,C5,Db5,Db5,EMPTY
	db  Eb5,"  Hail!  Hail!  "
	db  "  to  Michigan  "
	db  Eb5,Eb5,Eb5,F5,F5,F5,C5,C5,C5,Db5,Db5,Ab4,Ab4,EMPTY
	db  Bb4," the  Champions "
	db  "  of the West!  "
	db  Bb4,C5,C5,Eb5,Eb5,C5,C5,C5,Bb4,Ab4,Ab4,Ab4,Ab4,ENDSONG
psect code
	
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
