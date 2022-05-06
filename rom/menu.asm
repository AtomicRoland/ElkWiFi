\ MENU  routines

\ Syntax:     *MENU
 
.menu_cmd
    \ Switch off any disk system by performing *TAPE and set PAGE=&E00
    lda #&8C        \load A for *TAPE (osbyte 140)
    jsr osbyte

    ldx #<menu_wget \load pointer to command string
    ldy #>menu_wget
    jsr oscli       \pass the command to the CLI
	ldx	#0		    \character pointer
.m_a1
	stx	temp	    \save a copy of X, lost in OS
	lda	#&99		\OSBYTE &99 - Insert chr into buffer
	ldy	menu_call,x	\Y = chr to insert
	bmi	mquit		\if chr -ve, commands complete 
	ldx	#0		    \X = 0 = Keyboard buffer
	jsr osbyte		\insert the chr
	ldx	temp		\restore pointer
	inx			    \increment
	bne	m_a1		\and loop for next character
.mquit
    jmp call_claimed

.menu_wget
	equs	"*WGET HTTP://ACORNELECTRON.NL/uefarchive/MENU E00",&0D
.menu_call
    equs    "CALL &E00",&0D
	equb	&FF		            \command list end marker
    equb    &EA
