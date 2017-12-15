#include "hcs12.inc"

chrY	equ	$59
chary	equ	$79
chrN	equ	$4E
chr0	equ	$30

	org	$1000
endline	dc.b	$0D,$0A,0
wel		dc.b   "Welcome to Code Guesser",$0D,$0A,0
instc		dc.b   "Use the DIP switches to choose a diffuculty level",$0D,$0A
instc2	dc.b	"The length of the code is equal to the level",$0D,$0A
instc3 	dc.b	"The harder the level the less time you have to find the code!",$0D,$0A
instc4	dc.b	"Are you ready to begin? [press Y to start]",$0D,$0A,0
lvlsel	dc.b	"Level %i Selected",$0D,$0A,0
promp		dc.b	"Enter the Code:",0
winpromp	dc.b	"Congratulations You Found the Code!!",$0D,$0A,0
badinput	dc.b	"Oh no! The Code is %i numbers long and only consits of numbers!",$0D,$0A
		dc.b	"Trust in the FORCE!",$0D,$0A,0
feedback	dc.b	"Numbers placed correctly : %i",$0D,$0A
		dc.b	"Numbers guessed correctly: %i",$0D,$0A,0

losepromp	dc.b	"YOU DIED!!",$0D,$0A,0


inbuflen	dc.b	$FF
inbuf 		ds.b	$FF
		dc.b	0
       		dc.b  $0D,$0A,0

code		ds.b	$FF	;The actual code is loaded here.
		dc.b	$00	;Forcing null byte at end of buffer

guess		ds.b	$ff
		dc.b	0

cPlace	ds.b	1	;count of numbers placed correctly in dec
cGuess	ds.b	1	;count of numbers within actual in dec
level		ds.b	1
temp		ds.b	7
		dc.b	$0D,$0A,0
results	ds.b	2	;the counts of the compare in binary

timer_count	dc.b	$00

arrb	dc.b	$3F,$06,$5b,$4f,$66,$6D,$7D,$07,$7F,$6F,$00		;$6F,$7F,$07,$7D,$6D,$66,$4f,$5b,$06,$3F,$00
indx	dc.b	$00,$00,$00,$00					;$3F,$06,$5b,$4f,$66,$6D,$7D,$07,$7F,$6F,$00

digit	dc.b	00
timeset	ds.w	1
smtm	equ	31;$01
crtn	equ	62;$00AD;$CD3F

cstart	dc.w	crtn
smtst	dc.b	smtm
count	dc.b	0
segpt	dc.b	0
curchr	dc.b	0

timdcy	equ	6

rstspd	equ	1922
spkrst	dc.w	rstspd
skrstb	dc.w	rstspd

spkbas	equ	200;240;480

spkon	dc.w	spkbas

spkoff	dc.w	1922	;Init in sup

spkcnt	dc.w	spkbas

spkenb	dc.b	$0

gameov	dc.b	0

	org $1600


sup	nop			;use this to setup anything 
	movb	#0,DDRH		;setup port H to input(dip switches)
	
	ldaa	#smtm
	ldab	#crtn
	mul	

	std	spkoff


	movw	#$0001, cstart
	bset	DDRB,$7F
	movb	#%00001111,DDRP
	sei				;disable Global Interrupt Masks
	ldx	#RTI_isr			;pointer to isr
	stx	UserRTI
						
	ldaa	#$30			;set interrupt period
	;ldaa	#$12
	staa	RTICTL			;set RTI control reg
	bset	CRGINT,#$80		;enable RTICTL				;
	movb	#%11111111,PTP
	movb	#%11111111,PORTB
	ldx	#indx	
	ldaa	#$00	
	staa	1,x
	ldaa	#$00
	staa	2,x
	ldaa	#$00
	staa	3,x
	movb	$00, spkenb		;Disable beeper stuff
	


	cli				;Enable Global Interrupt Masks

	rts

start	ldaa	#0
	ldab	PTH		;get level from DIP switches
	stab	level		;store

	pshd			;place level on stack
	ldd	#lvlsel		;Load level selected message
	jsr	[printf,pcr]	;Display message
	leas	2,sp		;Take level off stack

	;Load a random number into the system
	ldx	#code
	ldaa	level
	jsr	sub_rng

	;;ldd	#code		;Load level selected message
	;;jsr	[printf,pcr]	;Display message

	ldx	#indx		;Put 3 minutes on the clock	
	ldaa	#$03	
	staa	1,x
	ldaa	#$00	
	staa	2,x
	ldaa	#$00	
	staa	3,x

	ldaa	#$00
	staa	gameov

	ldd	#rstspd
	std	spkrst

	ldd	#rstspd
	std	skrstb

	movb	$01, spkenb
	

kg	ldd	#promp		;Load code prompt message
	jsr	[printf,pcr]	;Display message
	
	ldd	#inbuflen	;Load buffer length
	pshd			;Put it on the stack
	ldd	#guess		;Load gues
	call	[getcmdline,pcr]
	leas	2,sp
	
	ldd	#endline
	jsr	[printf,pcr]
	
	
	ldaa	gameov
	cmpa	#$1		;If gameov 1, we done. No more chances.
	beq	lose

	ldd	#guess
	jsr	checklen	;check length of guess
	cmpb	level
	
	beq	godin
	ldaa	#0
	ldab	level
	pshd
	ldd	#badinput
	jsr	[printf,pcr]
	leas	2,sp

godin	ldx	#code
	ldy	#guess
	
	jsr	cprGuess	;compare guess to actuall
	cmpb	level		;compare A to B
	beq	win		;if equal code is guessed correctly
	std	results
	ldaa	#0
	ldab	results
	pshd	
	ldd	results
	ldaa	#0
	pshd
	ldd	#feedback
	jsr	[printf,pcr]
	leas	4,sp
	ldd	#endline
	jsr	[printf,pcr]
	bra	kg

win	;ldaa	#$00	
	;staa	1,x
	;ldaa	#$00	
	;staa	2,x
	;ldaa	#$00	
	;staa	3,x

	movb	$00, spkenb		;Disable beeper stuff

	ldd	#winpromp
	jsr	[printf,pcr]
	ldd	#endline
	jsr	[printf,pcr]
	jsr	[printf,pcr]
	bra	stptm

lose	ldd	#losepromp
	jsr	[printf,pcr]
	ldd	#endline
	jsr	[printf,pcr]
	jsr	[printf,pcr]

	movb	$00, spkenb		;Disable beeper stuff

	movb	$00, gameov


stptm	ldx	#indx	
	ldaa	#$00	
	staa	1,x
	ldaa	#$00
	staa	2,x
	ldaa	#$00
	staa	3,x

dloop	rts		

;*************************
;***CHECKLEN SUBROUTINE***
;*************************
checklen	nop		;find the length of the input string
				;return -1 if an invalid length otherwise
				;the length of the array
	pshx
	pshy
	tfr	D,X		;place array address in x
	ldab	#0
loopD	ldaa	1,x+		;load num
	cmpa	#0
	beq	exitA
	incb	
	bra	loopD
exitA	ldaa	#0
	puly
	pulx
	rts

;*************************
;***CPRGUESS SUBROUTINE***
;*************************
cprGuess	nop		;(compare the entered guess against the actual)
				; start addresses in X and Y
				; X -> actual code
				; Y -> guess
	pshX
	pshY
	leas	-2,sp		;lease 2 bytes for counts in stack
	movb	#0,0,sp
	movb	#0,1,sp	;initilize local counts
loop1	ldaa	1,x+		;load first num of actual
	ldab	1,y+		;load first num of guess
	cmpa	#0		;check for null byte
	beq	next		;if null go to next loop
	cba			;compare nums
	bne	loop1
	inc	1,sp		;nums are equal increment count of correct placement
	bra	loop1
next	
	ldy	2,sp		;count how many nums in guess exist in the code
	jsr	reduce		;reduce the set of nums in guess
loop3	ldx	4,sp		;load starting addresses of actual
	ldaa	1,Y+		;load num from guess
	cmpa	#0
	beq	dgc		;if null of guess terminate outer loop
loop2	ldab	1,X+		;load num from actual
	cmpb	#0
	beq	loop3		;load next value in guess
	cba			;compare nums
	bne	loop2		;look at next num in actual
	inc	0,sp		;increment count of exist
	bra	loop3		;it exists so move onto next value

dgc	ldd	0,SP
	leas	6,sp
	rts

;*************************
;****REDUCE SUBROUTINE****
;*************************
reduce	nop	;takes an array of dec nums and reduces
		;the set to unique values only 
		;Y -> starting address
	pshx		;place x on stack
	pshd		;place d on stack
	tfr	Y,X	;copy start address to X
	ldab	#$0	;
	pshb		;place null byte onto stack
loopA	ldab	1,X+	;load num from array
	cmpb	#0	;check for null
	beq	nxt	;branch to next step
	pshb		;place num on stack
	bra	loopA	;
nxt	ldaa	#0	
	staa	0,y	;place null onto mem array
	tfr	sp,x	;load stack point
	pshx		
	pshy		;place addresses on stack
loopB	ldy	0,sp	;load start address
	ldab	1,x+	;grab first of stack array
	cmpb	#0
	beq	doneR
loopC	ldaa	1,y+	;grab first off mem array
	cmpA	#0	;check for null
	beq	add	;branch and add accum B contents to mem array
	cba		;compare a to b
	beq	loopB	;it is alread stored next num in stack array
	bra	loopC	;check next num
add	stab	1,-y	
	ldaa	#0
	staa	1,+y
	bra	loopB
	
doneR	puly	
	pulx	
empty	pulb	
	cmpb	#0
	bne	empty
	puld
	pulx
	rts

;**************************
;****BIN2DEC SUBROUTINE****
;**************************
bin2dec	nop			;(num to convert, starting address to store at)	
					;D -> num to convert
					;X -> start address to store at
	pshx
	movb	#0,1,-SP	;place null byte onto stack
	ldx	#10		;place ten into reg X
loop	cpd	#$0		;loop until quotient is zero
	beq	term		;if int component is zero exit
	ldx	#10
	idiv
	addd	#chr0		;ascii offset
	pshb			;place ascii value onto stack
	xgdx			;place integer into X
	bra	loop
term	pula
	staa	1,Y+		
	cmpa	#0
	beq	bindn		;exit subrutine at null byte
	bra	term		;loop until null byte
bindn	pulx
	rts

;**************************
;*******SUB_RNG DATA*******
;**************************

local_rtn_ln	equ 0
local_str_ar	equ 1
local_rng_rs	equ 3
local_temp	equ 4
local_act_rs	equ 6

ascii_nm_off	equ 48


;********************************
;*******SUB_RNG SUBROUTINE*******
;********************************

sub_rng	pshx
	
	leas	-7, SP		;Creating 3 bytes for local variables

	staa	local_rtn_ln, SP

	ldb	#$00

	stab	A,X
	
	stx	local_str_ar, SP

	ldd	cstart		;Load the seed into previous rng result

	stab	local_rng_rs, SP

rng_m	equ	209
rng_a	equ	100
rng_c	equ	1
max_r	equ	10

	;The equation for LCG is Xn+1 = (a*Xn + c) mod m

strng	ldd	$00

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

	;;ldaa	local_rng_rs, SP	

	std	local_temp, SP; We need to save D to do some math.

	
	ldaa	#$0
	ldab	local_rng_rs,SP

	ldx	#max_r

	idiv

	stab	local_act_rs, SP
	
	ldd	local_temp, SP

	ldaa	local_act_rs, SP
	
	ldx	local_str_ar, SP	;Load the string start address

	;D is now [result]:[index]

	adda	#ascii_nm_off	;Add the ASCII offset.

	staa	B, X  ;Load result into string

	suba	#ascii_nm_off	;Decrement the ASCII offset.

	stab	local_rtn_ln, SP	

	cmpb	#$00  ;Is the current index 0?

	bne	strng ;It is not, do a looping.	

	leas	+7, SP;Deallocate stack.

	pulx

	rts



;main start **********
	org	$1900		;Starting program at 3000
	lds	#$3C00
	
	bset	DDRT, BIT5
	bset	PTT, BIT5


	jsr	sup		;Jump to sup subroutine for initial setup
	ldd	#wel		;Load welcome message
	sei
	jsr	[printf,pcr]	;Print welcome message
	cli
mlop	ldd	#instc		;Load instruction message
	
	sei
	jsr	[printf,pcr]	;Print instruction message
	cli

	ldd	inbuflen	;Load a buffer length
	pshd			;Push said buffer length
	ldd	#inbuf		;Push actual buffer start address.
	call	[getcmdline,pcr];Ask for input.
	leas	2,sp		;Take buffer length off stack
	ldaa	inbuf	
		
	cmpa	#chrY		;compare the input to Y
	beq	st
	cmpa	#chary
	bne	quit		;brach to quit, will exit program
	
st	jsr	start		;jump to subrutine to start the game
	bra	mlop		;
quit	movb	#%11111111,PTP
	swi
	

decrement
	pshx
	pshy	

	ldx	#indx

	;First, check if we're at 0
	ldaa	$03, x
	cmpa	#0
	bne	stert
	ldaa	$02, x
	cmpa	#0
	bne	stert
	ldaa	$01, x
	cmpa	#0
	bne	stert
	movb	#$01, gameov

	bra	decdd

stert	ldaa	$03, x
	cmpa	#0
	beq	rstone
	bra	decone
rstone	ldaa	#$09
	staa	$03, x

	ldaa	$02, x
	cmpa	#0
	beq	rstten
	deca		;Decrement 02
	staa	$02, x	;Store
	bra 	decdd	;Done
rstten	
	ldaa	#$05
	staa	$02, x

	ldaa	$01, x
	cmpa	#0
	bne	decmin
	bra	decdd
decmin	
	dec	$01, x
	bra	decdd

decone	dec	$03, x

	ldaa	$03, x	;Did we just go to zero? If so, game over.
	cmpa	#0
	bne	decdd
	ldaa	$02, x
	cmpa	#0
	bne	decdd
	ldaa	$01, x
	cmpa	#0
	bne	decdd
	
	movb	#$01, gameov
	
decdd	puly
	pulx

	rts


RTI_isr	

	lda	spkenb

	cmpa	#$00
	
	beq	clkstt

	ldd	spkcnt		;Load the count for the 'beep'
	
	cpd	#$0000		;Check if the count is at 0.

	beq	spkd		;If it is, skip beeping stuff.

	subd	#1		;If the spkcnt is not zero, decrement

	std	spkcnt		;Store the new spkcnt

	ldaa	PTT		;Load the current port T
	
	bita	#BIT5		;Is bit 5 set?

	beq	spko
	
spkn	bclr	PTT, BIT5	;If the bit was set, clear it.

	bra	spkd
spko	bset	PTT, BIT5	;If the bit was clear, set it.

	bra 	spkd

spkd	

	ldx	spkrst
	dex
	stx	spkrst

	cpx	#$0
	bne	clkstt

	ldx	skrstb
	cpx	#timdcy
	ble	posts

	exg	D,X
	subd	#timdcy
	exg	D,X
posts	stx	skrstb	
	stx	spkrst
	

	ldd	spkbas	;Reset the speaker timer
	std	spkcnt
	

;	ldd	spkrst
;	subd	#1
;	std	spkrst
;	
;	ldy	spkrst
;	cpy	#$00
;
;	bne	clkstt
;
;	ldd	spkbas	;Reset the speaker timer
;	std	spkcnt
;
;	ldd	skrstb
;	subd	#9
;	std	spkrst
;	std	skrstb


clkstt	bset	CRGFLG, #$80
	ldaa	smtst
	deca
	staa	smtst
	cmpa	#$0
	bne	cntu
	ldaa	#smtm
	staa	smtst

cont	ldy	cstart
	dey
	sty	cstart
	cpy	#$0
	bne	cntu
	ldy	#crtn
	sty	cstart
	jsr	decrement
	


cntu	movb	#%11111111,PTP
	ldx	#arrb
	ldy	#indx
	ldab	digit
	ldaa	#0
	ldaa	d,y
	staa	segpt
	ldab	a,x
	stab	curchr
	movb	curchr,PORTB
	ldaa	digit
check0	cmpa	#0
	beq	ptp0
	cmpa	#1
	beq	ptp1
	cmpa	#2
	beq	ptp2
	cmpa	#3
	beq	ptp3
	bra	done
ptp0	movb	#%11111110,PTP
	bra	done
ptp1	movb	#%11111101,PTP
	bra	done
ptp2	movb	#%11111011,PTP
	bra	done
ptp3	movb	#%11110111,PTP

done	inc	digit
	ldaa	digit
	cmpa	#4
	bge	rstdig
	bra	exit
rstdig	movb	#0,digit
exit	;bclr	PTT, BIT5
	rti


	end