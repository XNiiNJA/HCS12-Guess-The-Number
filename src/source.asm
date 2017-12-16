; ************************************************************************************
; Authors: Grant Oberhauser, Grant Brewer, Tj Millis, Adam Heuermann
; Description: 'Guess the Number' Game in HCS12 Assemble for the Dragon12-Plus2 Board 
; ************************************************************************************

#include "hcs12.inc"

chrY	equ	$59	;The 'y' character for the game start prompt
chary	equ	$79	;The 'Y' character for the game start prompt
chrN	equ	$4E	;The 'N' character for the game start prompt
chr0	equ	$30	

	org	$1000
endline	dc.b	$0D,$0A,0										;A string representation of endline
wel		dc.b   "Welcome to Code Guesser",$0D,$0A,0						
instc		dc.b   "Use the DIP switches to choose a diffuculty level",$0D,$0A
instc2	dc.b	"The length of the code is equal to the level",$0D,$0A
instc3 	dc.b	"The harder the level the less time you have to find the code!",$0D,$0A
instc4	dc.b	"Are you ready to begin? [press Y to start]",$0D,$0A,0
lvlsel	dc.b	"Level %i Selected",$0D,$0A,0
promp		dc.b	"Enter the Code:",0
winpromp	dc.b	"Congratulations You Found the Code!!",$0D,$0A,0
badinput	dc.b	"Oh no! The Code is %i numbers long and only consits of numbers!",$0D,$0A	;The prompt telling the user how long the number is
		dc.b	"Trust in the FORCE!",$0D,$0A,0							;Good advice.
feedback	dc.b	"Numbers placed correctly : %i",$0D,$0A						;The string containing feedback
		dc.b	"Numbers guessed correctly: %i",$0D,$0A,0

losepromp	dc.b	"YOU DIED!!",$0D,$0A,0								;The fail screen


inbuflen	dc.b	$FF		;How long the input cn be.
inbuf 		ds.b	$FF		;The buffer for input
		dc.b	0		;Forcing the buffer to end.
       		dc.b  $0D,$0A,0		;Forcing a newline for runaway buffers

code		ds.b	$FF		;The actual code is loaded here.
		dc.b	$00		;Forcing null byte at end of buffer

guess		ds.b	$ff		;The guess buffer.
		dc.b	0		;Forcing null byte at the end of the buffer

cPlace	ds.b	1			;count of numbers placed correctly in dec
cGuess	ds.b	1			;count of numbers within actual in dec
level		ds.b	1
temp		ds.b	7
		dc.b	$0D,$0A,0
results	ds.b	2			;the counts of the compare in binary

timer_count	dc.b	$00

arrb	dc.b	$3F,$06,$5b,$4f,$66,$6D,$7D,$07,$7F,$6F,$00		;7-Seg character array from 9 to 0
indx	dc.b	$00,$00,$00,$00						;Initial Index array (which character is being pulled from arrb)

digit	dc.b	00			;Which digit we are currently servicing.
;timeset	ds.w	1
smtm	equ	31			;The RTI outer counter start count
crtn	equ	62			;The RTI inner counter start count

cstart	dc.w	crtn			;The RTI inner counter
smtst	dc.b	smtm			;The RTI outer counter
curchr	dc.b	0			;The current char to write to the current 7 seg display

timdcy	equ	6			;How quickly does the beeper flatline?

rstspd	equ	1922			;The speaker reset initial count
spkrst	dc.w	rstspd			;The speaker reset current count
skrstb	dc.w	rstspd			;The speaker current reset count

spkbas	equ	200;240;480		;The length of one beep in RTI cycles

spkcnt	dc.w	spkbas			;The current count for the speaker beep length

spkenb	dc.b	$0			;When to reset spkcnt

gameov	dc.b	0			;Is the game over?

	org $1600	;Starting code at 1600


sup	nop				;use this to setup anything 
	movb	#0,DDRH			;setup port H to input(dip switches)


	movw	#$0001, cstart		;initializing starting counter 
	bset	DDRB,$7F		;Enable neccessary bits for PORTB and PTP for OUTPUTS
	movb	#%00001111,DDRP
	sei				;disable Global Interrupt Masks
	ldx	#RTI_isr			;pointer to isr
	stx	UserRTI
						
	ldaa	#$30			;set interrupt period
	;ldaa	#$12
	staa	RTICTL			;set RTI control reg
	bset	CRGINT,#$80		;enable RTICTL				
	movb	#%11111111,PTP		;disable all PTP 
	movb	#%11111111,PORTB	;initialize PORTB 


	ldx	#indx			;Load the 7 segment display array
	ldaa	#$00			;Setting the 7 segment display array to 00:00
	staa	1,x
	ldaa	#$00
	staa	2,x
	ldaa	#$00
	staa	3,x

	movb	$00, spkenb		;Disable beeper
	


	cli				;Enable Global Interrupt Masks

	rts				;Return to main subroutine

;*************************
;***CPRGUESS SUBROUTINE***
;*************************

start	ldaa	#0		;Start game logic

	ldab	PTH		;get level from DIP switches
	stab	level		;store

	pshd			;place level on stack
	ldd	#lvlsel		;Load level selected message
	jsr	[printf,pcr]	;Display message
	leas	2,sp		;Take level off stack

	
	ldx	#code		;Load a random number into the system
	ldaa	level
	jsr	sub_rng


	ldx	#indx		;Put 3 minutes on the clock	
	ldaa	#$03	
	staa	1,x
	ldaa	#$00	
	staa	2,x
	ldaa	#$00	
	staa	3,x

	ldaa	#$00		;Ensure gameover is not set.
	staa	gameov

	ldd	#rstspd		;Ensure speaker beep settings are set to inital setting
	std	spkrst

	ldd	#rstspd		;Ensure speaker beep settings are set to inital setting
	std	skrstb

	movb	$01, spkenb	;Enable the speaker login in RTI
	

kg	ldd	#promp			;Load code prompt message
	jsr	[printf,pcr]		;Display message
	
	ldd	#inbuflen		;Load buffer length
	pshd				;Put it on the stack
	ldd	#guess			;Load guess
	call	[getcmdline,pcr]
	leas	2,sp			;Reset stack after call
	
	ldd	#endline		;Print endline after loading guess
	jsr	[printf,pcr]
	
	
	ldaa	gameov		
	cmpa	#$1		;If gameov 1, we done. No more chances.
	beq	lose		;Force game to end if the game over flag has been set.

	ldd	#guess
	jsr	checklen	;check length of guess
	cmpb	level
	
	beq	godin		;If the length of the input is correct, jump to godin
	ldaa	#0		;Otherwise, print the correct length.
	ldab	level		;Load the level for output
	pshd
	ldd	#badinput	;Load the bad input prompt
	jsr	[printf,pcr]	;Print
	leas	2,sp		;Reset stack

godin	ldx	#code
	ldy	#guess
	
	jsr	cprGuess	;compare guess to actuall
	cmpb	level		;compare A to B
	beq	win		;if equal code is guessed correctly
	
	std	results		;Load the results into D
	ldaa	#0
	ldab	results
	pshd	
	ldd	results		;Loading the results into D
	ldaa	#0
	pshd
	ldd	#feedback	;Print the feedback with results.
	jsr	[printf,pcr]	;Print
	leas	4,sp		;Correct stack pointer
	ldd	#endline	;Print an endline
	jsr	[printf,pcr]
	bra	kg		;Do a loop.

win	

	movb	$00, spkenb	;Disable beeper stuff

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

	movb	$00, spkenb	;Disable beeper stuff

	movb	$00, gameov

stptm	ldx	#indx		;Reset the timer to 0	
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
	movb	#0,1,sp		;initilize local counts
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
	
	leas	-7, SP			;Creating 3 bytes for local variables

	staa	local_rtn_ln, SP

	ldb	#$00

	stab	A,X
	
	stx	local_str_ar, SP

	ldd	cstart			;Load the seed into previous rng result

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

	mul				;Doing a multiply
	
	addd	#rng_c

	ldx	#rng_m

	idiv				;After div, remainder is in D. This is our result.

	ldx	local_str_ar, SP	;Load the string start address

	dey				;Subtract string length to get index.


	;Currently:
	;X - String address
	;Y - String index
	;D - Result

	stab	local_rng_rs, SP	;Store the result into memory	

	TBA				;A is now the result


	exg	D,Y			;D is now [$00]:[index]

	std	local_temp, SP		; We need to save D to do some math.
	
	ldaa	#$0			
	ldab	local_rng_rs,SP

	ldx	#max_r

	idiv

	stab	local_act_rs, SP
	
	ldd	local_temp, SP

	ldaa	local_act_rs, SP
	
	ldx	local_str_ar, SP	;Load the string start address

	;D is now [result]:[index]

	adda	#ascii_nm_off		;Add the ASCII offset.

	staa	B, X  			;Load result into string

	suba	#ascii_nm_off		;Decrement the ASCII offset.

	stab	local_rtn_ln, SP	

	cmpb	#$00  			;Is the current index 0?

	bne	strng 			;It is not, do a looping.	

	leas	+7, SP			;Deallocate stack.

	pulx				;Pull X

	rts				;Return from subroutine



;main start **********
	org	$1900		;Starting program at $1900
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
	bne	quit		;branch to quit, will exit program
	
st	jsr	start		;jump to subrutine to start the game
	bra	mlop		;
quit	movb	#%11111111,PTP
	swi
	

decrement
	pshx				;save timing counters for ISR before decrementing
	pshy					

	ldx	#indx			;load pointer to index (which digit will be displayed on current 7-seg display)

					;First, check if we're at 0 (all 3 digits=0?)
	ldaa	$03, x
	cmpa	#0
	bne	stert
	ldaa	$02, x
	cmpa	#0
	bne	stert
	ldaa	$01, x
	cmpa	#0
	bne	stert
	movb	#$01, gameov	;If we have hit zero, it's game over.

	bra	decdd		;If we haven't started yet, we are at zero. End sub.

stert	ldaa	$03, x		;Check if the ones are at 0.
	cmpa	#0
	beq	rstone		;If we are, reset the ones.
	bra	decone		;Otherwise, decrement the ones.
rstone	ldaa	#$09		;Reseting the ones place.
	staa	$03, x		;Store the ones place.

	ldaa	$02, x		;Check the tens place
	cmpa	#0		;Is it zero?
	beq	rstten		;Yes, go to resetting tens place.
	deca			;Otherwise, decrement tens
	staa	$02, x		;Store the tens.
	bra 	decdd		;Done
rstten	
	ldaa	#$05		;Load 5 to reset the tens place
	staa	$02, x		;Store A to reset tens.

	ldaa	$01, x		;Load the minutes place.
	cmpa	#0		;Is it zero?
	bne	decmin		;If not, decrement the mins.
	bra	decdd		;Otherwise, we are done.
decmin	
	dec	$01, x		;Decrement the minutes place.
	bra	decdd		;We are done.

decone	dec	$03, x		;Decrement the ones place.

	ldaa	$03, x		;Did we just go to zero? If so, game over.
	cmpa	#0		;Comparting ones to zero...
	bne	decdd		;If not zero, we're done
	ldaa	$02, x		;Load tens place.
	cmpa	#0		;Comparting tens to zero...
	bne	decdd		;If not zero, we're done
	ldaa	$01, x		;Load minutes place.
	cmpa	#0		;Comparting mins to zero...
	bne	decdd		;If not zero, we're done
	
	movb	#$01, gameov	;If all are zero, it's game over!
	
decdd	puly			;Restore Y count
	pulx			;Restore X count

	rts


RTI_isr	

	ldaa	spkenb		;check speaker on/off from last isr loop

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

	ldx	spkrst		;Decrement the speaker reset count
	dex
	stx	spkrst

	cpx	#$0		;If the speaker reset count is not zero...
	bne	clkstt		;Jump to the clkstt label to manage 7 segment display

	ldx	skrstb		;Otherwise, load the value to reset the count to for the speaker
	cpx	#timdcy		;Make sure, we are not less than the decrement value
	ble	posts		;If we are less than that value, continue to reset other speaker counts

	exg	D,X		;Decrement the reset value
	subd	#timdcy
	exg	D,X		
posts	stx	skrstb		;Store X to the speaker reset base value
	stx	spkrst		;Store X to the speaker count value
	

	ldd	spkbas		;Reset the speaker count
	std	spkcnt


clkstt	bset	CRGFLG, #$80	;Clearing the RTI Flag
	ldaa	smtst		;load the current inner count
	deca			;Decrement
	staa	smtst		;Store
	cmpa	#$0		;compare smtst zero?
	bne	cntu		;Is it not zero?
	ldaa	#smtm		;Yes it is, load smtm back to smtst
	staa	smtst		;Store

cont	ldy	cstart		;The count needs to be decremented.
	dey
	sty	cstart		;Decrement and store.
	cpy	#$0		;Are we at zero?
	bne	cntu		;No, continue
	ldy	#crtn		;Yes, reset cstart count
	sty	cstart
	jsr	decrement	;Decrement 7 segment display.
	


cntu	movb	#%11111111,PTP	;Turn off port P to turn off 7 segment while changing values
	ldx	#arrb		;Load the array of 7 segment values.
	ldy	#indx		;Load the array of current 7 segment block values
	ldab	digit		;Load the current block we are on for the 7 segment display.
	ldaa	#0		
	ldaa	d,y
	;staa	segpt
	ldab	a,x
	stab	curchr		;Store the current character displayed
	movb	curchr,PORTB	;Store the current character displayed to PORT B
	ldaa	digit		;Load the current 7 segment display block we are on.

check0	cmpa	#0		;Compare the 7 segment digit and turn on the currect bit in Port P
	beq	ptp0		
	cmpa	#1
	beq	ptp1
	cmpa	#2
	beq	ptp2
	cmpa	#3
	beq	ptp3
	bra	done
ptp0	movb	#%11111110,PTP	;Turn on 7 segment display 0
	bra	done
ptp1	movb	#%11111101,PTP	;Turn on 7 segment display 1
	bra	done
ptp2	movb	#%11111011,PTP	;Turn on 7 segment display 2
	bra	done
ptp3	movb	#%11110111,PTP	;Turn on 7 segment display 3

done	inc	digit		;Increment the digit we are on for next look
	ldaa	digit		;load the digit and see if we need reset.
	cmpa	#4
	bge	rstdig
	bra	exit
rstdig	movb	#0,digit	;If the digit needs a reset, do so.
exit	
	rti


	end
