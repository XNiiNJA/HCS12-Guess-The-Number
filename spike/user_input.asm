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

inbuflen	dc.b	$FF
inbuf 		ds.b	$FF
       		dc.b  $0D,$0A,0

code		ds.b	$FF	;The actual code is loaded here.
guess		ds.b	$ff
		dc.b	0

cPlace	ds.b	1	;count of numbers placed correctly in dec
cGuess	ds.b	1	;count of numbers within actual in dec
level		ds.b	1
temp		ds.b	7
		dc.b	$0D,$0A,0
results	ds.b	2	;the counts of the compare in binary

timer_count	dc.b	$00


	org $2000
sup	nop			;use this to setup anything 
	movb	#0,DDRH		;setup port H to input(dip switches)
	
	rts

start	ldaa	#0
	ldab	PTH		;get level from DIP switches
	stab	level		;store

	swi

	;Load a random number into the system
	ldx	#code
	ldaa	#$04
	jsr	sub_rng

	pshd			;place level on stack
	ldd	#lvlsel		;Load level selected message
	jsr	[printf,pcr]	;Display message
	leas	2,sp		;Take level off stack

kg	ldd	#promp		;Load code prompt message
	jsr	[printf,pcr]	;Display message
	
	ldd	#inbuflen	;Load buffer length
	pshd			;Put it on the stack
	ldd	#guess		;Load gues
	call	[getcmdline,pcr]
	leas	2,sp
	ldd	#endline
	jsr	[printf,pcr]
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
win	ldd	#winpromp
	jsr	[printf,pcr]
	ldd	#endline
	jsr	[printf,pcr]
	jsr	[printf,pcr]
	rts		

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
	beq	done		;exit subrutine at null byte
	bra	term		;loop until null byte
done	pulx
	rts

;**************************
;*******SUB_RNG DATA*******
;**************************

local_rtn_ln	equ 0
local_str_ar	equ 1
local_rng_rs	equ 3
ascii_nm_off	equ 48

;**************************
;****SUB_RNG SUBROUTINE****
;**************************

sub_rng	pshx
	
	leas	-4, SP		;Creating 3 bytes for local variables

	staa	local_rtn_ln, SP

	ldb	#$00

	stab	A,X
	
	stx	local_str_ar, SP

	ldaa	timer_count	;Load the seed into previous rng result

	staa	local_rng_rs, SP

rng_m	equ	10
rng_a	equ	56
rng_c	equ	56
max_r	equ	10

	;The equation for LCG is Xn+1 = (a*Xn + c) mod m

rng_lp	ldd	$00
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
	bne	rng_lp ;It is not, do a looping.	
	leas	+4, SP;Deallocate stack.
	pulx
	rts




;main start **********
	org	$3000		;Starting program at 3000
	jsr	sup		;Jump to sup subroutine for initial setup
	ldd	#wel		;Load welcome message
	jsr	[printf,pcr]	;Print welcome message
mlop	ldd	#instc		;Load instruction message
	jsr	[printf,pcr]	;Print instruction message
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
quit	swi
	end









