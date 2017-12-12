#include   "hcs12.inc"
lcdPort	equ	PTH   ; LCD data pins (PH7~PH0)
lcdDIR	equ	DDRH  ; LCD data direction port
lcdCtl	equ	PTK	  ; LCD control port
lcdCtlDir	equ	DDRK	; LCD control port direction 
lcdE	equ	$80     	; E signal pin
lcdRW	equ	$20	; R/W signal pin
lcdRS	equ	$10     ; RS signal pin
	org	$1500
	lds	#$1500  	; set up stack pointer
	jsr	openlcd	; initialize the LCD
	ldx	#msg1lcd
	jsr	puts2lcd
	ldaa	#$C0	; move to the second row
	jsr	cmd2lcd	
	ldx	#msg2lcd
	jsr	puts2lcd
	swi
msg1lcd   fcc	"hello   world!"
	dc.b	0
msg2lcd   fcc	"I am ready!"
	dc.b	0

; include the previous four LCD functions 

puts2lcd	ldaa  	1,x+   	; get one character from the string delayby50us
		beq   	done_puts ; reach NULL character? jsr   	
		jsr	putc2lcd
		bra   	puts2lcd
done_puts 	rts 

putc2lcd 	bset  lcdCtl,lcdRS 
			bclr	lcdCtl,lcdRW
			bset  lcdCtl,lcdE  
			staa  lcdPort        
			nop                   
			nop                   
			bclr  lcdCtl,lcdE   
			bset  lcdCtl,lcdRW
			ldy	#1

			rts

openlcd movb	#$FF,lcdDIR    	; configure port H for output
		bset	lcdCtlDir,$B0	; configure control pins for output
		ldy	#5	; wait for LCD to complete internal 
		ldaa	#$38            	; set 8-bit data, 2-line display, 5x8 font
		jsr	cmd2lcd         	;       "
		ldaa  	#$0F            	; turn on display, cursor, and blinking
		jsr   	cmd2lcd         	;       "
		ldaa  	#$06            	; move cursor right (entry mode set instruction)
		jsr   	cmd2lcd         	;       "
		ldaa  	#$01            	; clear LCD screen and return to home position
		jsr   	cmd2lcd         	;       "
		ldy   	#2              	; wait until "clear display" command is complete
		rts	;       "

cmd2lcd	bclr	lcdCtl,lcdRS+lcdRW
	bset	lcdCtl,lcdE
	staa	lcdPort
	nop
	nop
	bclr	lcdCtl,lcdE
	bset	lcdCtl,lcdRW
	ldy	#1
	rts
	