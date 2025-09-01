;************************************************************************
;*	Microchip Technology Inc. 2002					*
;*	Assembler version: 2.0000					*
;*	Filename: 							*
;*		p18math.asm (main routine)   				*
;*	Dependents:							*
;*		p18lcd.asm						*
;*		p18demo.asm						*
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
;*			and functions as a slave.			*
;*		4. Clock						*
;*			This function is a real-time clock. When the	*
;*			mode is entered, time begins at 00:00:00. The 	*
;*			user can set the time if desired.		*
;************************************************************************

list	p=18f452
#include	<xc.inc>

#define	_C	CARRY

;MATH_VAR
PSECT udata_acs
AARGB0:		DS 1
AARGB1:		DS 1
AARGB5:		DS 1
BARGB0:		DS 1
BARGB1:		DS 1
REMB0:		DS 1
REMB1:		DS 1
TEMP:		DS 1
LOOPCOUNT:	DS 1

GLOBAL	AARGB0, AARGB1, BARGB0

PSECT PROG2,reloc=2,class=CODE
;---------------- 8 * 8 UNSIGNED MULTIPLY -----------------------

;       Max Timing:     3+12+6*8+7 = 70 clks
;       Min Timing:     3+7*6+5+3 = 53 clks
;       PM: 19            DM: 4
UMUL0808L:
		CLRF    AARGB1,a
                MOVLW   0x08
                MOVWF   LOOPCOUNT,a
                MOVF    AARGB0,W,a

LOOPUM0808A:
                RRCF     BARGB0, F,a
                BTFSC   _C
                bra    LUM0808NAP
                DECFSZ  LOOPCOUNT, F,a
                bra    LOOPUM0808A

                CLRF    AARGB0,a
                RETLW   0x00

LUM0808NAP:
                BCF     _C
                bra    LUM0808NA

LOOPUM0808:
                RRCF             BARGB0, F,a
                BTFSC   _C
                ADDWF   AARGB0, F,a
LUM0808NA:       RRCF    AARGB0, F,a
                RRCF    AARGB1, F,a
                DECFSZ          LOOPCOUNT, F,a
                bra            LOOPUM0808
		return
		GLOBAL	UMUL0808L
;----------------  16/8 UNSIGNED DIVIDE	  ------------------------
              
;       Max Timing: 2+7*12+11+3+7*24+23 = 291 clks
;       Min Timing: 2+7*11+10+3+7*17+16 = 227 clks
;       PM: 39                                  DM: 7

UDIV1608L:
		GLOBAL		UDIV1608L
		CLRF            REMB0,a
                MOVLW           8
                MOVWF           LOOPCOUNT,a

LOOPU1608A:      RLCF             AARGB0,W,a
                RLCF             REMB0, F,a
                MOVF            BARGB0,W,a
                SUBWF           REMB0, F,a

                BTFSC           _C
                bra            UOK68A          
                ADDWF           REMB0, F,a
                BCF             _C
UOK68A:          RLCF             AARGB0, F,a

                DECFSZ          LOOPCOUNT, F,a
                bra            LOOPU1608A

                CLRF            TEMP,a

                MOVLW           8
                MOVWF           LOOPCOUNT,a

LOOPU1608B:      RLCF             AARGB1,W,a
                RLCF             REMB0, F,a
                RLCF             TEMP, F,a
                MOVF            BARGB0,W,a
                SUBWF           REMB0, F,a
                CLRF            AARGB5,a
		movlw		0x00
                BTFSS           _C
                INCFSZ          AARGB5,W,a
                SUBWF           TEMP, F,a

                BTFSC           _C
                bra            UOK68B          
                MOVF            BARGB0,W,a
                ADDWF           REMB0, F,a
                CLRF            AARGB5,a
		movlw		0x00
                BTFSC           _C
                INCFSZ          AARGB5,W,a
                ADDWF           TEMP, F,a

                BCF             _C
UOK68B:          RLCF             AARGB1, F,a

                DECFSZ          LOOPCOUNT, F,a
                bra            LOOPU1608B
		return
		GLOBAL	UDIV1608L

		end
