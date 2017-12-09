#include "hcs12.inc"

	org	$1000		;Start at 1000 for storing variables
count	dc.b	$00		;The number of times the interupt has ran this cycle
config	dc.b    $00		;The configuration to run
	org	$1100
arr	dc.b	0,0,0,0,0,0,0,0,0
endln	dc.b	$0D, $0A, $00


	org	$1500		;Start 1t 1500 for code.setup	movb	#$FF, DDRP	;Make sure the 7-seg display is off

	sei			;Disabling interrupts while setting up interrupts.

	lds	#$3C00

	ldx	#RTI_isr	;Set the interrupt service routine address.

	stx	UserRTI		;Set it here.

	ldaa	#$10		;Load the RTI timer configuration
	
	staa	RTICTL		;Store it...
	
	bset	CRGINT, #$80	;Enable the RTI

	cli			;Done setting up interrupts, enable.

loop	nop			;Don't do anything else forever.

	ldx #arr	
	
	ldaa #$04

	jsr	sub_rng		;Call the sub_cwcnt subroutine

	ldd #arr

	jsr [printf, PCR]

	ldd #endln

	jsr [printf, PCR]

	bra loop		;Branch for not doing anything.


local_rtn_ln	equ 0
local_str_ar	equ 1
local_rng_rs	equ 3
ascii_nm_off	equ 48

sub_rng	pshx
	
	leas	-4, SP		;Creating 3 bytes for local variables

	staa	local_rtn_ln, SP

	ldb	#$00

	stab	A,X
	
	stx	local_str_ar, SP

	ldaa	count		;Load the seed into previous rng result

	staa	local_rng_rs, SP

rng_m	equ	10
rng_a	equ	56
rng_c	equ	56
max_r	equ	10

	;The equation for LCG is Xn+1 = (a*Xn + c) mod m

start	ldd	$00

	ldb	local_rtn_ln, SP	;Load the length left

	exg	D,Y			;Move D to Y

	ldaa	local_rng_rs, SP	;Getting the previous result from memory 

	ldab	#rng_a

	mul	;Doing a multiply
	
	addd	#rng_c

	ldx	#rng_m

	idiv	;After div, remainder is in D. This is our result.

	ldx	local_str_ar, SP	;Load the string start address

	dey	;Subtract string length to get index.


	;Currently:
	;X - String address
	;Y - String index
	;D - Result

	stab	local_rng_rs, SP	;Store the result into memory	

	

	TBA	;A is now the result




	exg	D,Y	;D is now [$00]:[index]

	ldaa	local_rng_rs, SP	

	

	;D is now [result]:[index]

	adda	#ascii_nm_off	;Add the ASCII offset.

	staa	B, X  ;Load result into string

	suba	#ascii_nm_off	;Decrement the ASCII offset.

	stab	local_rtn_ln, SP	

	cmpb	#$00  ;Is the current index 0?

	bne	start ;It is not, do a looping.	

	leas	+4, SP;Deallocate stack.

	pulx

	rts

btn_ISR	jsr sub_rng	;To be implemented
			;To be implemented
			;To be implemented
btn_dne	nop		;To be implemented



RTI_isr	bset	CRGFLG, #$80	;Lock RTI

	ldaa count		;Load the current count and increment.

	inca

	staa count

done	rti			;Unlock RTI

	end			;Done with ASM code.