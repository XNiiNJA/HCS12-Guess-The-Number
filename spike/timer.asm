#include	"hcs12.inc"


	org	$1000
arrb	dc.b	$3F,$06,$5b,$4f,$66,$6D,$7D,$07,$7F,$6F,$00		;$6F,$7F,$07,$7D,$6D,$66,$4f,$5b,$06,$3F,$00
indx	dc.b	$00,$00,$00,$00					;$3F,$06,$5b,$4f,$66,$6D,$7D,$07,$7F,$6F,$00
	org	$1200
digit	dc.b	00
timeset	ds.w	1
smtm	equ	$04
crtn	equ	$CD3F

cstart	dc.w	crtn
smtst	dc.b	smtm
count	dc.b	0
segpt	dc.b	0
curchr	dc.b	0

	org	$1500
	movw	#$0001, cstart
	bset	DDRB,$7F
	movb	#%00001111,DDRP
	sei				;disable Global Interrupt Masks
	lds	#$3C00			;set stack pointer
	ldx	#RTI_isr			;pointer to isr
	stx	UserRTI					
	ldaa	#$7f			;set interrupt period
	staa	RTICTL			;set RTI control reg
	bset	CRGINT,#$80		;enable RTICTL				;
	movb	#%11111111,PTP
	movb	#%11111111,PORTB
	ldx	#indx	
	ldaa	#$03	
	staa	1,x
	ldaa	#$00
	staa	2,x
	ldaa	#$00
	staa	3,x
	cli				;Enable Global Interrupt Masks
;*************************************************	
always	nop
	bra	always

;*************************************************
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
	
decdd	puly
	pulx

		rts
;*************************************************
RTI_isr	;swi
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
exit	rti
	end