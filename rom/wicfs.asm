\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
\                 *** WiCFS ***                   \
\                                                 \
\             (c) Martin Barr 2012                \
\             (c) Roland Leurs 2020               \
\                                                 \
\                WiFi UEF mini-FS                 \
\        based on UPCFS by Martin Barr            \
\     The uncompressed UEF file will be read      \
\                from paged RAM                   \
\                                                 \
\                      V1.0E                      \
\             For the Acorn Electron              \
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

\System constants and program constants & variables

OSWORD	=	&FFF1		\OSWORD
OSASCI	=	$FFE3		\print A to screen
OSBYTE	=	$FFF4		\OSBYTE
OSRDCH	=	$FFE0		\read character from input stream
OSWRCH	=	$FFEE		\write character to output stream

OSFILEV	=	&0212		\OS FILEV vector
OSFSCV	=	&021E		\OS FSCV vector
BYTEV	=	&020A		\OSBYTE vector
OSFINDV	=	&021C		\OSFIND vector (Open sequential)
OSBGETV	=	&0216		\OSBGET vector (sequential read)

FILVRTN	=	&03A3		\Tape FILEV vector contents
FSCVRTN	=	&03A5		\Tape FSCV vector contents

serbuf	=	&06E0		\serial input buffer
romsel	=	&07A4		\location of external rom select code
notape	=	&0398		\location of external *TAPE trap
hchunk	=	&03CB		\Chunk header type(2) + length(4)

bufsize	=	28		\data burst (buffer) size
sbuft	=	&F5		\flag to indicate start of UEF
sbufl	=	&F8		\number of bytes left (lo)
sbufh	=	&F9		\number of bytes left (hi)
temp	=	&C4		\zp temporary
slotid	=	&C5		\UPCSF slot id (from UPURS handler)
currom	=	&CF		\current rom slot id (usually BASIC)
tmpidx	=	&C1		\temporary store for index pointers
fnlen	=	&C2		\length of current CFS block filename
inchunk	=	&CE		\chunk started (non-zero = yes)
pbl	    =	&B8		\parameter block lo (X)
pbh	    =	&B9		\parameter block hi (Y)
loadrun	=	&BA		\b0 load addr : 0 = caller, 1 = file
      				\b1 *CAT : 1 = True
		    		\b7 load/run  : 0 = *LOAD, 1 = *RUN
CFSload	=	&B0		\Current load address
CFSact2	=	&EB		\CFS active flag 2
curblk	=	&B4		\current CFS block number
nxtblk	=	&B6		\next CFS block number
blklen	=	&B5		\copy of block length ls byte
optmask	=	&B7		\mask for *OPT setting (two values)

pr_y    =   &C7     \data pointor to paged ram (Y-reg)
pr_r    =   &C8     \data pointer to paged ram (page register)

				    \the following locations are re-entrant
				    \and must only be initialised on *UPCFS

sfopen	=	&BE		\b7 sequential file open : 1 = true
				    \b2 sequential EOF : 1 = true
				    \b1 last block read : 1 = true 
		    		\b0 read buffer empty : 1 = true 
sfptr	=	&BF		\sequential file pointer (0-&FF)

\character constants

vdu_off	=	21		\turn screen off (0 for debug)
vdu_on	=	6		\turn screen on

cr	    =	13	    \<cr>
sp	    =	32	    \<sp>
esc	    =	27	    \<Escape>

\end of declarations


\------------------------------------------------------------------------------
\To ensure that the cycle critical RS232 receive routine doesn't sit across a
\page boundary, it is located first in the code and preceded by two JMPs to the
\code entry points.

	JMP	aUPCFS		\jump to *UPCFS command handler
	
	JMP	bUPCFS		\jump to *QUPCFS command handler

\-------------------------------------------------------------------------------
\Fills the buffer at serbuf, data fetched from paged RAM
\with [(bufsize) + overrun] bytes. Cycle critical code.

\-------------------------------------------------------------------------------
\*UPCFS handler. This is the user entered command to select the UPURS FS.
\This command configures the Beeb ready for the vector steal. It inserts a
\series of commands into the KB buffer and then returns. The final command
\will cause a re-entry to the UPURS rom via the *QUPCFS command.

.wicfs_cmd
.aUPCFS
	LDA	&F4		    \record which slot UPURS occupies
	STA	slotid
	LDA	#vdu_off	\turn off screen output to hide
	JSR	OSASCI		\KB auto-command sequence
	LDX	#0		    \character pointer
.a_a1
	STX	temp	    \save a copy of X, lost in OS
	LDA	#&99		\OSBYTE &99 - Insert chr into buffer
	LDY	starcom,X	\Y = chr to insert
	BMI	aquit		\if chr -ve, commands complete 
	LDX	#0		    \X = 0 = Keyboard buffer
	JSR	OSBYTE		\insert the chr
	LDX	temp		\restore pointer
	INX			    \increment
	BNE	a_a1		\and loop for next character

.aquit	PLA			\once all commands entered, exit
	TAY			    \restore registers and return to OS
	PLA
	TAX
	LDA	#0		    \set A=0 to inform OS command taken
	RTS

.starcom
	equs	"*TAPE",&0D		    \select CFS
	equs	"PAGE=&0E00",&0D	\set PAGE to &E00
	equs	"NEW",&0D		    \reset BASIC pointers
	equs	"*QUPCFS",&0D		\and call UPCFS vector set
	equb	&FF		            \command list end marker

\-------------------------------------------------------------------------------
\*QUPCFS handler. This a silent command called by UPCFS which sets FILEV, FSCV,
\FINDV and BGETV to point to the downloaded rom switch code allowing upfilev
\and upfscv to be called in place of the original CFS handlers. (The code
\download is executed first by this command.)

\external *UPCFS interface code
.bUPCFS	
    LDX	#0		        \index on X
.b_a1
   	LDA	s_filev,X		\get a byte
	STA	romsel,X		\copy to ram
	INX	        		\increment index
	CPX	#(s_end-s_filev)	\all done?
	BNE	b_a1	    	\no, loop for next

\and external code for *TAPE trap
	LDX	#0		        \index on X
.b_a2
	LDA	osb_s,X 		\get a byte
	STA	notape,X		\copy to ram
	INX			        \increment index
	CPX	#(osb_e-osb_s)	\all done?
	BNE	b_a2	    	\no, loop for next

\now set the UPCFS vectors
	LDA	OSFILEV		    \preserve OS tape vector addresses
	STA	FILVRTN
	LDA	OSFILEV+1
	STA	FILVRTN+1

	LDA	OSFSCV
	STA	FSCVRTN
	LDA	OSFSCV+1
	STA	FSCVRTN+1

\new UPCFS vector addresses
	LDA	#>romsel		\FILEV, FINDV
	STA	OSFILEV
	STA	OSFINDV

	LDA	#<romsel
	STA	OSFILEV+1
	STA	OSFINDV+1

	LDA	#>(romsel+(s_fscv-s_filev))	\FSCV
	STA	OSFSCV
	LDA	#<(romsel+(s_fscv-s_filev))
	STA	OSFSCV+1

	LDA	#>(romsel+(s_bgetv-s_filev))	\BGETV
	STA	OSBGETV
	LDA	#<(romsel+(s_bgetv-s_filev))
	STA	OSBGETV+1

	LDA	BYTEV		    \OSBYTE intercept
	STA	notape+(osb_j-osb_s)+1
	LDA	BYTEV+1
	STA	notape+(osb_j-osb_s)+2
	SEI			        \no interrupts during OSBYTE redirect
	LDA	#>notape
	STA	BYTEV
	LDA	#<notape
	STA	BYTEV+1
	CLI
	JSR	cfsinit		    \initialisations

.brom	
    LDA	#vdu_on		    \restore screen output
	JSR	OSASCI
	LDA	#0		        \display UPCFS banner
	JSR	xmess
	LDA	#1		        \and version number
	JSR	xmess

.Bquit	
    PLA			        \UPCFS initialisation complete so..
	TAY			        \..restore registers and return to OS
	PLA
	TAX
	LDA	#0      		\set A=0 to inform OS command taken
	RTS

\-------------------------------------------------------------------------------
\Main FILEV (+FINDV), FSCV and BGETV entry points. Traps full file loads,
\load & run (*RUN), sequential access file open and single byte get. 

.upfilev	BEQ	upf_a7		\If A=0, possible file close r=est
	CMP	#255		\file load?
	BEQ	upf_a1		\yes, goto process
	AND	#192		\sequential file access r=est?
	BNE	upf_a2		\yes, goto further tests
	BEQ	upf_a6		\else command not supported by UPCFS

.upf_a7	TYA			\A=0, test Y
	BEQ	upf_a8		\Y=0, close all files r=est
	CMP	#1		\if Y=1, close #1 r=est 	
	BNE	upf_a6		\else A=0, Y<>0 or 1, exit no action
.upf_a8	LDA	#0		\close file
	STA	sfopen
	STA	sfptr
	BEQ	upf_a5		\and exit claiming command

.upf_a6	JMP	xfilev		\not supported, exit no action

.upf_a1	JSR	starload		\goto action file load
	JMP	romsel+(actioned-s_filev)	\and return claiming command

.upf_a2	CMP	#128		\exclusive output r=est?
	BNE	upf_a3		\no, includes input sp process
	LDA	#12		\else output only r=ested..
	JSR	xmess		\report error..
	BEQ	upf_a5		\and exit

.upf_a3	LDA	sfopen		\file open already?
	BPL	upf_a4		\no, continue
	LDA	#13		\else report error...
	JSR	xmess
	BEQ	upf_a5		\and exit

.upf_a4	JSR	fopen		\goto action file open

.upf_a5	JMP	romsel+(actioned-s_filev)	\and return claiming command

.xfilev	JMP	romsel+(x_filev-s_filev)	\return command unclaimed

\...............................................................................
\Filters selected FSCV functions

.upfscv	CMP	#5		\*CAT ?
	BNE	upv_a1		\no, next check
	PHA
	JSR	upcat		\perform a *CAT
	PLA
	JMP	clfscv

.upv_a1	CMP	#2		\*\ ?
	BEQ	uprun		\yes, goto service
	CMP	#4		\*RUN ?
	BEQ	uprun		\yes, goto service

	CMP	#1		\EOF being checked
	BNE	upv_a2		\no, skip
	LDX	#0		\default to eof false
	LDA	sfopen		\test internal upcfs eof flag
	AND	#4		\b2 of sfopen
	BEQ	clfscv		\not eof, return X = 0 = false
	DEX			\else return X = &FF = true
	BNE	clfscv		\end of EOF test

.upv_a2	JMP	xfscv		\not a supported UPCFS command, exit

.uprun	JSR	starrun		\first, find the file and *LOAD it
	BNE	clfscv		\if file found, return to run
	LDA	loadrun		\else reset run flag before returning
	AND	#&7F
	STA	loadrun

.clfscv	JMP	romsel+(actioned-s_filev)	\return command claimed

.xfscv	JMP	romsel+(x_fscv-s_filev)	\return command unclaimed

\...............................................................................
\Handles BGET (single byte read from sequential access file)

.upbgetv	TXA			\preserve X
	PHA
	LDA	sfopen		\file open?
	BMI	bg_a1		\yes, continue
	LDA	#4		\else report no file open
	JSR	xmess
	CLC
	BCC	xbgetv		\and exit

.bg_a1	AND	#4		\EOF true?
	BEQ	bg_a2		\no, service BGET
	SEC			\else EOF, report via Carry set
	BCS	xbgetv		\and exit

.bg_a2	LDA	#0		\clear load/run flags (not used)
	STA	loadrun
	JSR	upget		\get a byte
	
.xbgetv	STA	temp		\recover X, preserving A
	PLA
	TAX
	LDA	temp

	JMP	romsel+(actioned-s_filev)	\and return claiming command
						\via FILEV and simple RTS

\===============================================================================
\Sideways ROM select code downloaded to ram @romsel. Allows intercepted FS
\vectors to call UPCFS code in rom and to return claimed or unclaimed as
\required.

\Code begins with entry points for UPCFS intercepts

.s_filev	JSR	romsel+(aupurs-s_filev)	\page in UPURS
	JMP	upfilev			\and jump to UPCFS FILEV

.s_fscv	JSR	romsel+(aupurs-s_filev)	\page in UPURS
	JMP	upfscv			\and jump to UPCFS FSCV

.s_bgetv	JSR	romsel+(aupurs-s_filev)	\page in UPURS
	JMP	upbgetv			\and jump to UPCFS BGETV

\...............................................................................
\Local common subroutine to select UPURS rom

.aupurs	PHA			\preserve A
	SEI			\no interrupts during rom switching
	LDA	&F4		\log current sw rom (probably BASIC)
	STA	currom
	LDA	#&C		\deselect BASIC (Elk quirk)
	STA	&FE05
	LDA	slotid		\then select UPURS rom
	STA	&F4
	STA	&FE05
	CLI			\restore interrupts
	PLA			\restore A
	RTS			\roms switched, return

\-------------------------------------------------------------------------------
\Return handler post-UPCFS processing

\1. Return path for unclaimed commands

				\deselect UPURS and select previous rom
.x_filev	JSR	romsel+(bupurs-s_filev)		
	JMP	(FILVRTN)		\and follow original FILEV vector

				\deselect UPURS and select previous rom
.x_fscv	JSR	romsel+(bupurs-s_filev)
	JMP	(FSCVRTN)		\and follow original FSCV vector

\2. Return path for claimed commands

				\deselect UPURS and select previous rom
.actioned	JSR	romsel+(bupurs-s_filev)

	LDY	loadrun		\are we running the program?
	BPL	ret_fscv		\no, return to OS
	PLA			\else dump OS call return
	PLA
	JMP	(&03C2)		\and execute loaded program
		
.ret_fscv	RTS			\simple RTS as command actioned

\...............................................................................
\Local common subroutine to deselect UPURS rom

.bupurs	PHA			\preserve A
	SEI			\no interrupts during rom switching
	LDA	currom		\restore active rom prior to UPCFS call
	STA	&F4
	STA	&FE05
	CLI			\restore interrupts
	PLA			\restore A
	RTS			\roms switched, return

\...............................................................................

.s_end	NOP			\dummy address marker for code download

\~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
\Download code for OSBYTE *TAPE trap. Copied to notape by *QUPCFS

.osb_s	CMP	#&8C		\*TAPE ?
	BNE	osb_j		\no, continue to OSBYTE
	RTS			\yes, return no action

.osb_j	JMP	&0000		\continue to OSBYTE at OS vector..
				\..address written by *QUPCFS
.osb_e	NOP

\===============================================================================
\Loads a file into memory (*LOAD)

.starload	LDA	#0		\clear flags
	STA	loadrun
	JSR	wsinit		\initialise workspace (&B0..&BF)
	LDA	#&C0		\set *OPT mask for load
	STA	optmask
	JSR	flinit		\initialise load parameters
.runentry	JSR	newuef		\check_for/process new uef
	BCS	stl_nf		\on error, return flagging not found
	JSR	findf		\find the embedded CFSfile
	BEQ	stl_nf		\if A=0, file not found

	LDA	loadrun		\file found, load addr from Block 00?
	AND	#1
	BEQ	stl_a1		\no, addr already set by caller, skip
	LDA	&03BE		\else copy file addr to current address
	STA	CFSload
	LDA	&03BF
	STA	CFSload+1
	LDA	&03C0
	STA	CFSload+2
	LDA	&03C1
	STA	CFSload+3

.stl_a1	JSR	loadblk		\load CFS data block
	BCS	stl_nf		\exit on error
	LDA	&3CA		\last block?
	AND	#&80
	BNE	stl_end		\yes, load complete
.stl_a2	LDA	curblk		\else update current/next block
	STA	nxtblk
	INC	nxtblk
	JSR	chunk		\and fetch next chunk
	BCS	stl_x
	JSR	cfstest		\cfs block?	
	BEQ	stl_a3		\no, goto skip
	JSR	header		\fetch the CFS block header
	BCS	stl_x
	JSR	prblock		\display block cfs info
	JMP	stl_a1		\and loop to load

.stl_a3	JSR	chskip		\else skip the non-cfs chunk
	BCS	stl_nf		\exit immediately on skip error
	JMP	stl_a2		\and loop for next chunk

.stl_end	JSR	lastblk		\process last block output
	LDA	#1		\flag file found to OS
	BNE	stl_x

.stl_nf	LDA	#0		\flag file not found to OS

.stl_x	RTS			\and return

\-------------------------------------------------------------------------------
\Loads current CFS data block into memory

.loadblk	JSR	getbyte		\get a block data byte from PC
	BCS	ldb_err		\abort on error
	LDY	#0		\write to Beeb memory
	STA	(CFSload),Y
	INC	CFSload		\increment Beeb load address
	BNE	ldb_a1
	INC	CFSload+1

.ldb_a1	DEC	&3C8		\decrement CFS block length count
	LDA	&3C8
	CMP	#&FF
	BNE	ldb_a2
	DEC	&3C9

.ldb_a2	DEC	hchunk+2		\decrement Chunk length count
	LDA	hchunk+2
	CMP	#&FF
	BNE	ldb_a3
	DEC	hchunk+3

.ldb_a3	CLC			\end of CFS data block?
	LDA	&3C8
	ADC	&3C9
	BNE	loadblk		\no, loop for next byte

	JSR	adjlen		\account for CFS header already read
	LDX	hchunk+2		\fetch count of residual CFS bytes
	BEQ	ldb_a4		\no residual, return
	JSR	discard		\else discard residual
	BCS	ldb_x		\exit immediately if error occurred

.ldb_a4	CLC			\no error exit
	BCC	ldb_x

.ldb_err	LDA	#8		\report unexpected EOF
	JSR	xmess
	SEC			\and exit flagging error

.ldb_x	RTS			\and return		

\-------------------------------------------------------------------------------
\For a file load, analyses the calling parameters to identify and fetch any
\filename and/or explicit load address.

.flinit	STX	pbl		\collect filename & load addr (if any) 
	STY	pbh
	LDA	loadrun		\initial default is file load address
	ORA	#1		\b0=1
	STA	loadrun

	LDY	#6		\explicit load address from caller?
	LDA	(pbl),Y
	BNE	fl_a2		\no, skip address fetch

	LDY	#2		\fetch explicit load address
.fl_a1	LDA	(pbl),Y		\get a load addr byte
	STA	CFSload-2,Y		\save it
	INY
	CPY	#4		\all done?
	BNE	fl_a1		\no, loop to fetch 4 bytes
	LDA	loadrun		\flag external load address
	AND	#&FE		\b0=0
	STA	loadrun

.fl_a2	LDY	#0		\fetch filename (if any)
	LDA	(pbl),Y		\pointer lo
	PHA			\save lo
	INY
	LDA	(pbl),Y		\pointer hi
	STA	pbh		\switch pointers to filename
	PLA			\rerieve lo
	STA	pbl
.fl_name	LDY	#0		\fetch filename (called here by fopen)
	LDX	#0
.fl_a5	LDA	(pbl),Y		\get first character
	CMP	#&22		\is first character a double quote?
	BEQ	fl_a3		\yes, ignore
	BNE	fl_a7		\else enter filename fetch loop	
.fl_a6	LDA	(pbl),Y		\get a character
.fl_a7	CMP	#cr		\end of entered filename is <cr>..
	BEQ	fl_a4		\yes, goto finalise
	CMP	#sp		\..or <space>
	BEQ	fl_a4
	CMP	#&22		\..or <">
	BEQ	fl_a4
	CMP	#&7C		\..or <||>
	BEQ	fl_a4
	JSR	upper		\else rationalise case
	STA	&03D2,X
	INX			\save chr in CFS workspace
.fl_a3	INY
	BNE	fl_a6		\and loop for next chr

.fl_a4	LDA	#0		\terminate CFS filename with a zero
	STA	&03D2,X

	RTS			\and return

\-------------------------------------------------------------------------------
\Executes *RUN or */ After run-specific inits, joins *LOAD code

.starrun	JSR	wsinit		\initialise CFS workspace
	LDA	#&C0		\set *OPT mask for load
	STA	optmask
	LDA	loadrun		\set UPCFS run flag true
	ORA	#&81		\and load addr from file flag
	STA	loadrun
	STX	pbl		\fetch the filename (if any)
	STY	pbh
	LDX	#0
	LDY	#0
.sr_a5	LDA	(pbl),Y		\get first character
	CMP	#&22		\is first character a double quote?
	BEQ	sr_a3		\yes, ignore
	BNE	sr_a7		\else enter filename fetch loop	
.sr_a6	LDA	(pbl),Y		\get a character
.sr_a7	CMP	#cr		\end of entered filename is <cr>..
	BEQ	sr_a4		\yes, goto finalise
	CMP	#sp		\..or <space>
	BEQ	sr_a4
	CMP	#&22		\..or <">
	BEQ	sr_a4
	CMP	#&7C		\..or <||>
	BEQ	sr_a4
	JSR	upper		\else rationalise case
	STA	&03D2,X
	INX			\save chr in CFS workspace
.sr_a3	INY
	BNE	sr_a6 

.sr_a4	LDA	#0		\terminate CFS filename with a zero
	STA	&03D2,X
	
	JMP	runentry		\and merge with *LOAD code

\-------------------------------------------------------------------------------
\Opens a file for sequential access (read only for UPCFS)

.fopen	JSR	wsinit		\initialise workspace (&B0..&BF)
	LDA	#&0C		\set *OPT mask for sequential access
	STA	optmask
	STX	pbl		\save XY filename pointer
	STY	pbh
	JSR	fl_name		\fetch filename
	LDX	#&FF		\copy filename into BGET filename store
.fo_a1	INX
	LDA	&03D2,X		\from sought...
	STA	&03A7,X		\to BGET...
	BNE	fo_a1		\loop until null terminator written
	JSR	newuef		\check_for/process new uef
	BCS	fo_err		\on error, return reporting not found
	JSR	findf		\find the embedded CFS file
	BCS	fo_err		\exit on error if file not found
	LDA	sfopen		\flag file open and buffer empty
	ORA	#&81
	STA	sfopen
	LDA	#1		\return file handle #1
	CLC			\clear error flag
	BCC	fo_x		\and return

.fo_err	LDA	#3		\report file not found
	JSR	xmess
	LDA	#0		\return A=0, file not found, no handle
	SEC			\set error flag

.fo_x	RTS			\and return	

\-------------------------------------------------------------------------------
\Fetches one byte from an open sequential access file. Maintains the buffer in
\page &A filling as necessary until EOF.

.upget	LDA	#&0C		\set *OPT mask for sequential access
	STA	optmask
	LDA	sfopen		\get file status
	AND	#1		\buffer empty?
	BEQ	gt_a2		\no, continue
	LDA	sfopen		\else last block already read?
	AND	#2
	BEQ	gt_a5		\no, more blocks available
	SEC			\else flag error
	BCS	gt_x		\and exit
.gt_a5	JSR	fillget		\else fill the buffer

.gt_a2	LDX	sfptr		\fetch the next byte
	LDA	&A00,X
	PHA			\hold byte
	LDA	sfptr		\check if last byte read
	CMP	#&FF		\if ptr &FF, must always be last byte
	BEQ	gt_a3		\so goto set buffer empty flag
	LDA	sfopen		\if not &FF, is this last block?
	AND	#2
	BEQ	gt_a4		\no, no further checks
	LDA	blklen		\else last block, check ptr
	SEC			\which is 1 too many indexed from 0
	SBC	#1
	CMP	sfptr		\against copy of block length ls byte
	BNE	gt_a4		\not last byte, continue

.gt_a3	JSR	prblock		\update screen block
	LDA	sfopen		\buffer now empty, set flag
	ORA	#1
	STA	sfopen
	AND	#&83		\test for eof
	CMP	#&83		\file open, last block read, buf empty ?
	BNE	gt_a4		\no, not EOF
	ORA	#4		\else set EOF flag true
	STA	sfopen
	JSR	lastblk		\display last block summary

.gt_a4	INC	sfptr		\always increment buffer pointer
	CLC
	PLA			\retrieve fetched byte

.gt_x	RTS			\and return

\-------------------------------------------------------------------------------
\Fills the BGET buffer (&A00-&AFF) from the open input file

.fillget	LDA	#0		\reset buffer address to &0A00
	STA	CFSload
	LDA	#&A
	STA	CFSload+1
	JSR	loadblk		\load the cued CFS data block
	BCS	fg_x		\exit on error
	LDA	#0		\reset buffer pointer
	STA	sfptr
	LDA	sfopen		\reset buffer empty flag
	AND	#&FE
	STA	sfopen
	LDA	&3CA		\last block?
	AND	#&80
	BEQ	fg_a1		\no, continue
	LDA	sfopen		\else set last block read flag
	ORA	#2
	STA	sfopen
	BNE	fg_a4		\and skip next block cue

.fg_a1	LDA	curblk		\cue next CFS block ready for next fill
	STA	nxtblk		\update current/next block
	INC	nxtblk
.fg_a3	JSR	chunk		\fetch next chunk
	BCS	fg_x		\exit on error
	JSR	cfstest		\cfs block?	
	BNE	fg_a2		\yes, goto complete cue
	JSR	chskip		\else skip the non-cfs chunk
	BCS	fg_x		\exit on skip error
	JMP	fg_a3		\else loop for next chunk

.fg_a2	JSR	header		\CFS block found, fetch the header
	BCS	fg_x		\exit on error

.fg_a4	CLC			\good fill

.fg_x	RTS

\-------------------------------------------------------------------------------
\Determines if at start of UEF and if so, reads & validates title header.
\Returns C=1 if error reading/checking title else returns C=0

\get a copy of the next byte in buffer
.newuef	
    LDA	sbuft		\start of file?
	BNE	new_a1		\no, copy byte directly
    INC sbuft       \increase once, so it's marked not start of file
.new_a1
	JSR	getbyte		\else perform standard read
	BCS	new_x		\return immediately on error

.new_a2
   	CMP	#'U'		\if a 'U', assume header to validate
	BEQ	new_a4
	CMP	#&1F		\if &1F (possibly gzip'd) assume..
	BNE	new_a3		\..header to validate else skip check
.new_a4
	JSR	f_title		\'U' or &1F so validate header
	BCS	new_x		\pass any header error (C=1) to caller

.new_a3	
    CLC			\flag checks ok - header good or mid-uef

.new_x	
    RTS			\and return

\-------------------------------------------------------------------------------
\Locates the r=ired CFS file in the UEF. Returns A=1 if file found else A=0

.findf	LDA	&E3		\report searching if not *OPT1,0
	AND	optmask		\test message bits
	BEQ	fnd_a0		\if messages surpressed, skip
	LDA	#10		\else report searching
	JSR	xmess
	LDA	#cr
	JSR	OSASCI
.fnd_a0	JSR	chunk		\fetch a Chunk
	BCS	fnd_err		\error, exit find
	JSR	cfstest		\test if CFS tape block
	BNE	fnd_a1		\yes, continue
	JSR	chskip		\skip a non-cfs chunk
	BCS	fnd_err		\error, exit find
	JMP	fnd_a0		\and loop for next chunk

.fnd_a1	JSR	header		\fetch the CFS block header
	BCS	fnd_err		\error, exit find
	LDX	#0		\check if r=ired file 
.fnd_a2	LDA	&03D2,X		\any filename entered?
	BEQ	fnd_yes		\no, first file is a default match
	LDA	&03B2,X		\else get a block name character
	STA	temp		\save a copy
	CMP	&03D2,X		\compare with sought name character
	BNE	fnd_no		\mismatch, not sought file
	LDA	temp		\retrieve character
	BEQ	fnd_yes		\end of names, good match
	INX
	BNE	fnd_a2		\loop for next character

.fnd_no	JSR	prblock		\display block cfs info
	LDA	&3CA		\test for last block
	AND	#&80		\ = Bit 7 of Block Flag
	BEQ	fnd_a3		\not last block, goto skip
	JSR	lastblk		\else process last block display

.fnd_a3	JSR	adjlen		\prepare to skip remainder of CFS block
	JSR	chskip		\skip remainder
	BCS	fnd_err		\error, exit find
	JMP	fnd_a0		\and loop for next chunk

.fnd_yes	LDA	&E3		\report loading if not *OPT1,0
	AND	optmask		\test message bits
	BEQ	fnd_a4		\if messages surpressed, skip
	LDA	#11		\else report loading
	JSR	xmess
	LDA	#cr
	JSR	OSASCI
.fnd_a4	JSR	prblock		\display block cfs info
	LDA	#1		\file found, return A=1
	CLC			\no error
	BCC	fnd_rtn

.fnd_err	LDA	#0		\file not found, return A=0
	SEC			\error

.fnd_rtn	RTS
	
\-------------------------------------------------------------------------------
\Display handler for last block of a CFS file
\Tests for *OPT1,0 and if TRUE, returns no action (messages surpressed)

.lastblk	LDA	&E3		\CFS Options Byte
	AND	optmask		\test message bits
	BEQ	lblk_x		\if messages surpressed, exit no action

	LDA	#sp		\last block, always print 16 bit length
	JSR	OSWRCH
	LDA	&3C6		\length = current block number...
	JSR	printhex
	LDA	blklen		\... + current block length
	JSR	printhex

	LDA	&E3		\at last block, test for *OPT1,2
	AND	optmask		\ = Bits 7,6 set of &E3
	CMP	optmask
	BNE	lblk_a1		\no extended info
	
	LDA	#sp		\else add 16 bit load & execution
	JSR	OSWRCH
	LDA	&3BF		\load address
	JSR	printhex
	LDA	&3BE
	JSR	printhex
	LDA	#sp		\<space>
	JSR	OSWRCH
	LDA	&3C3		\execution address
	JSR	printhex
	LDA	&3C2
	JSR	printhex
.lblk_a1	LDA	#cr		\new line
	JSR	OSASCI
.lblk_x	LDA	#0		\reset current/next block
	STA	curblk
	STA	nxtblk

	RTS			\and return

\-------------------------------------------------------------------------------
\Following a CFS header load, prints the standard CFS block output. Saves a
\copy of this block number in curblk for comparison with expected block nxtblk
\Tests for *OPT1,0 and if TRUE, returns no action (messages surpressed)
 
.prblock	LDA	&E3		\CFS Options Byte
	AND	optmask		\test message bits
	BEQ	prb_a5		\if messages surpressed, exit only..
				\..updating block number record

	LDA	#cr		\else cursor to left
	JSR	OSWRCH
	LDX	#0		\print the block filename (overwrite)
.prb_a1	LDA	&3B2,X
	BEQ	prb_a2		\null is last byte (non-printed)
	JSR	OSWRCH
	INX
	BNE	prb_a1		\loop till done

.prb_a2	CPX	#10		\all 10 filename characters used?
	BEQ	prb_a4		\yes, skip formatting
.prb_a3	LDA	#sp		\else pad out to 10 spaces
	JSR	OSWRCH
	INX
	CPX	#10
	BNE	prb_a3

.prb_a4	LDA	#sp		\<space>
	JSR	OSWRCH
	LDA	&3C6		\print current block number in hex
	JSR	printhex
.prb_a5	LDA	&3C6
	STA	curblk		\update CFS current block record
		

.prb_x	RTS			\and return		

\-------------------------------------------------------------------------------
\Tests if next Chunk (header just loaded) is CFS. Returns A=1 if CFS tape block
\else returns A=0

.cfstest	LDA	hchunk		\looking for chunk type &0100
	BNE	cfst_no		\not CFS tape block, skip
	LDA	hchunk+1
	CMP	#&01
	BNE	cfst_no
	JSR	getbyte		\chunk is &0100, confirm is tape block
	CMP	#&2A		\sychronisation byte?
	BEQ	cfst_yes		\CFS tape block, process

	DEC	hchunk+2		\not a CFS block, reduce length by 1..
	LDA	hchunk+2		\..catering for underflow
	CMP	#&FF
	BNE	cfst_no
	DEC	hchunk+3
	LDA	hchunk+3
	CMP	#&FF
	BNE	cfst_no
	DEC	hchunk+4
	LDA	hchunk+4
	CMP	#&FF
	BNE	cfst_no
	DEC	hchunk+5
.cfst_no	LDA	#0		\return A=0, not CFS
	BEQ	cfst_x		\and exit

.cfst_yes	LDA	#1		\return A=1, CFS tape block

.cfst_x	RTS

\-------------------------------------------------------------------------------
\Initialises UPCFS workspace and resets 6522

.wsinit				\workspace inits (&B0-&BD)
	STX	temp		\preserve X
	LDA	#0		\initilaise CFS zp block descriptors
	LDX	#0		\index on X
.wsi_a1	STA	&B0,X
	INX
	CPX	#&0E
	BNE	wsi_a1		\loop till all done
	LDX	temp
	RTS

\-------------------------------------------------------------------------------
\Performs a *CAT of the UEF file showing tape files only as per CFS

.upcat	LDA	#cr		\begin with a blank line
	JSR	OSASCI
	JSR	f_title		\validate UEF file title
	BCC	upc_a1		\title ok, continue
	JMP	upc_x		\else quit
	
.upc_a1	JSR	wsinit		\init workspace
	LDA	#&C0		\set *OPT mask for load
	STA	optmask
	LDA	loadrun		\set *CAT flag
	ORA	#2
	STA	loadrun

.upc_a2	JSR	chunk		\fetch next chunk header into mem
	BCC	upc_a9		\good fetch, continue
	JMP	upc_x		\else exit

.upc_a9	JSR	cfstest		\CFS block?
	BNE	upc_a10		\yes, continue
	JMP	notcfs		\else goto skip current non-cfs block

.upc_a10	JSR	header		\tape block, fetch the header
	BCS	upc_x		\exit immediately on error
	JSR	prblock		\else print filename and block number

	LDA	curblk		\check this is the expected block
	CMP	nxtblk		\expected block number
	BEQ	upc_a5		\block ok, continue

	LDA	#cr		\block out of sequence, report
	JSR	OSASCI
	LDA	#6
	JSR	xmess

.upc_a5	LDA	&3CA		\test for last block
	AND	#&80		\ = Bit 7 of Block Flag
	BNE	upc_a6		\last block, goto process
	INC	nxtblk		\else increment 'next block'
	JSR	adjlen		\prepare to skip remainder of CFS block
	JSR	chskip		\and skip
	BCS	upc_x		\exit immediately on error
	JMP	upc_a2		\loop for next Chunk 

.upc_a6	JSR	lastblk		\display last block info

	JSR	adjlen		\prepare to skip remainder of CFS block
	JSR	chskip		\and skip
	BCS	upc_x		\exit immediately on error
	JMP	upc_a2		\loop for next Chunk

.notcfs	JSR	chskip		\skip this chunk
	BCS	upc_x		\exit immediately on error
	JMP	upc_a2		\and loop for next chunk

.upc_x	RTS


\-------------------------------------------------------------------------------
\Validates UEF file by checking that first 10 bytes are 'UEF File!' + &00

.f_title	LDX	#&FF		\index on X
.ft_a1	INX			\increment index
	STX	tmpidx		\preserve index
	JSR	getbyte		\fetch UEF byte
	BCS	titerr		\error, no byte available
	CMP	#&1F		\is 1st byte &1F and possibly a gzip?
	BNE	ft_a2		\no, continue
	JSR	getbyte		\else get second byte
	BCS	titerr		\none available, error anyway
	CMP	#&8B		\is 2nd byte &8B?
	BNE	titerr		\no, error anyway
	LDA	#2		    \gzip error
	BNE	terr		\and exit reporting error

.ft_a2	LDX	tmpidx	\restore index
	CMP	ueft,X		\check character against reference
	BNE	titerr		\error, title mismatch
	CMP	#0		    \title end?
	BNE	ft_a1		\no, loop for next character
	LDX	#2		    \title ok, discard 2 UEF version bytes
	JSR	discard
	JMP	f_rtn		\Carry will prpogate any discard error

.titerr	
    LDA	#5		\report UEF bad
.terr	
    JSR	xmess
	SEC			    \C = 1 = title error	

.f_rtn	RTS			\return

.ueft	equs	"UEF File!"
	    equb	0

\-------------------------------------------------------------------------------
\Fetches a CFS tape block header into CFS memory

.header	LDX	#&FF		\fetching filename, index on X
.hd_a1	INX			\increment index
	STX	tmpidx		\preserve index
	JSR	getbyte		\get a filename byte
	BCS	hd_err		\abort on error
	STA	temp		\hold
	LDA	loadrun		\if not *CAT, convert to upper case
	AND	#2
	BNE	hd_a3		\*CAT, skip conversion
	LDA	temp		\else convert to upper case
	JSR	upper
	STA	temp
.hd_a3	LDA	temp		\recover filename character
	LDX	tmpidx		\restore index
	STA	&3B2,X		\stash it
	CMP	#0		\end of filename null?
	BNE	hd_a1		\no, loop for next chr
	INX			\adjust X to length of filename inc. 00
	STX	fnlen		\and save

	LDX	#&FF		\fetching block descriptors, index on X
.hd_a2	INX			\increment index
	STX	tmpidx		\preserve index
	JSR	getbyte		\get a descriptor byte
	BCS	hd_err		\abort on error
	LDX	tmpidx		\restore index
	STA	&3BE,X		\stash it
	CPX	#12		\end of block descriptors
	BNE	hd_a2		\no, loop for next byte
	LDA	&3C8		\take a copy of block length ls byte
	STA	blklen
	LDX	#6		\discard spares (4) & header CRC (2)
	JSR	discard
	BCS	hd_x		\if discard error, exit with propogate
	CLC			\return no error
	BCC	hd_x

.hd_err	LDA	#8		\report unexpected EOF error
	JSR	xmess
	SEC			\return flagging error
	
.hd_x	RTS			\and exit

\-------------------------------------------------------------------------------
\Adjusts CFS block length to account for filename + leading descriptors

.adjlen	LDA	fnlen		\block filename length
	CLC
	ADC	#20		\plus leading/trailing descriptors
	STA	temp		\and save
	LDA	hchunk+2		\CFS block length lo
	SEC
	SBC	temp
	STA	hchunk+2
	BCS	adj_x
	DEC	hchunk+3
.adj_x	LDA	#0
	STA	hchunk+4
	STA	hchunk+5
	RTS			\return  

\-------------------------------------------------------------------------------
\Discards (X) bytes from the UEF file. (To skip 256 bytes, set X=0)

.discard	STX	tmpidx		\init index
.dsc_a1	JSR	getbyte		\get one byte
	BCS	dsc_err		\if EOF, report error
	DEC	tmpidx		\count down
	BNE	dsc_a1		\loop until done
	CLC			\return no error
	BCC	dsc_x

.dsc_err	LDA	#8		\report unexpected EOF error
	JSR	xmess
	SEC			\return flagging error
	
.dsc_x	RTS			\and exit

\-------------------------------------------------------------------------------
\Skip the current Chunk whose length is stored in hchunk+2.. (ls,midl,midh,ms)

.chskip	LDX	hchunk+2		\ls chunk length
	BEQ	chs_a1		\no ls bytes
	JSR	discard		\else discard ls bytes
	BCS	chs_x		\exit on error
.chs_a1	LDX	hchunk+3		\midl chunk length
	BEQ	chs_a5		\no midl bytes
.chs_a2	LDX	#0		\discard 256 byte blocks
	JSR	discard
	BCS	chs_x		\exit on error
	DEC	hchunk+3
	BNE	chs_a1		\and loop until midl discarded
.chs_a5	LDA	hchunk+4		\midh chunk length
	BEQ	chs_a3		\none to discard, process ms length
.chs_a4	DEC	hchunk+4		\else discard midh in 256*256 blocks
	JMP	chs_a2		\until mid=0
.chs_a3	LDA	hchunk+5		\ms chunk length
	BEQ	chs_ok		\none to discard, exit
	DEC	hchunk+5		\else discard ms in 256*256*256 blocks
	JMP	chs_a4		\until ms=0

.chs_ok	CLC			\Clear carry if no errors from discards

.chs_x	RTS			\return

\-------------------------------------------------------------------------------
\Fetches next 6-byte Chunk header into memory

.chunk	LDA	#0		\reset chunk in progress flag
	STA	inchunk
	LDX	#&FF		\index on X
.ch_a1	INX			\increment index
	STX	tmpidx		\preserve index
	JSR	getbyte		\get a chunk byte
	BCS	cherr		\error, no byte available
	LDX	tmpidx		\restore index
	INC	inchunk		\flag chunk in progress
	STA	hchunk,X		\stash it
	CPX	#5		\done 6 bytes?
	BNE	ch_a1		\no, loop for next

	LDA	hchunk+1		\test for valid Chunk major type
	CMP	#&FF		\&FF = reserved but valid
	BEQ	chok		\= &FF
	CMP	#5		\if not &FF, must be 0..4
	BCC	chok		\= 0..4
	LDA	#cr		\else Chunk invalid, print 16 bit type
	JSR	OSASCI
	LDA	hchunk+1
	JSR	printhex
	LDA	hchunk
	JSR	printhex
	LDA	#7		\followed by error message
	JSR	xmess
.ch_a3	JSR	getbyte		\pull bytes until link clear
	BCC	ch_a3	
	BCS	ch_a2		\and exit flagging error

.chok	CLC			\all done, exit Carry clear
	BCC	ch_rtn

.cherr	LDA	#cr		\print cr/lf
	JSR	OSASCI
	LDA	inchunk		\chunk data started?
	BNE	ch_a4		\yes, flag unexpected EOF
	LDA	#9		\else EOF reached
	BNE	ch_a5		\goto report
.ch_a4	LDA	#8		\report unexpected UEF EOF
.ch_a5	JSR	xmess
.ch_a2	SEC			\C = 1 = chunk error	

.ch_rtn	RTS			\return

\-------------------------------------------------------------------------------
\Returns one byte in A from the User Serial Port. Fills buffer as required
\until end of PC file. Returns C=0 if byte in A else returns C=1 if no further
\bytes available (end of UEF)

.getbyte	
    lda sbufl       \check if end-of-tape is reached
    ora sbufh       \when empty this will result to &00
    beq nodata      \jump if &00, end-of-tape is reached
    jsr set_bank_1  \select paged ram bank
    ldy pr_y        \load pointer to paged ram
    lda pr_r
    sta pagereg
    lda pageram,y   \load data
    sta &FC38       \write to serial A port just as an indicator that we get a byte
    pha             \save data
    iny             \increment pointer
    bne getbyte1    \jump if not end of page
    inc pagereg     \increment page register
.getbyte1
    sty pr_y        \save pointer
    lda pagereg     \load page register
    sta pr_r        \save page register
    jsr set_bank_0  \select first paged ram bank
    dec sbufl       \decrement tape counter
    lda sbufl
    cmp #&FF
    bne getbyte2
    dec sbufh
.getbyte2
    pla
	CLC			\and return flagging byte ready (C=0)
	BCC	bcx

.nodata	SEC			\return flagging no data (C=1)

.bcx	RTS

\-------------------------------------------------------------------------------
\Converts a..z to uppercase (A..Z unaffected). Enter with character in A

.upper
	CMP	#'a'		\< "a" ?
	BMI	up_x		\yes, no conversion
	CMP	#'{'		\> "z" ?
	BPL	up_x		\yes, no conversion
	AND	#&DF		\a..z so convert to A..Z
.up_x
	RTS 			\and return

\-------------------------------------------------------------------------------
\Program initialisations

.cfsinit
	LDA	#1		    \set CFS active flags true
	STA	CFSact2
    JSR wget_context_switch_in
    LDA #&FF        \get tape length 
    STA pagereg     \ (this is stored in the last two bytes of the paged RAM)
    LDA &FDFE       
    STA sbufl
    LDA &FDFF
    STA sbufh
    JSR wget_context_switch_out
	LDA	#0
    STA pr_y        \reset pointer to paged ram
    sta pr_r
	STA	sfopen		\reset sequential file control bytes
	STA	sfptr
	STA	sbuft		\set start-of-tape indicator
	RTS			    \and return

\-------------------------------------------------------------------------------
\Multi-message print routine.
\ALL messages are 15 characters long (padded with trailing spaces if necessary)
\and are selected via A = <message number> in the max. range 0-15
\Note 1 : exits A = 0 and thus caller can branch always via BEQ on return
\Note 2 : The last message ONLY can be longer than 15 characters as follows...
\	Max length last message is given by : 254 - (#messages x 16) + <cr>
\Note 3 : If required, multiple long messages can be used by padding the
\         following dummy text string with an approriate number of spaces.

.txt0	equs	"WiFi UEF FS    ",&0D
.txt1	equs	"Ver 1.0E 251112",&0D
.txt2	equs	"File is gzip!  ",&0D
.txt3	equs	"File not found!",&0D
.txt4	equs	"No file open!  ",&0D
.txt5	equs	"UEF Header?    ",&0D
.txt6	equs	"Block sequence?",&0D
.txt7	equs	" Chunk type?   ",&0D
.txt8	equs	"Unexpected EOF!",&0D
.txt9	equs	"End of UEF     ",&0D
.txt10	equs	"Searching      ",&0D
.txt11	equs	"Loading        ",&0D
.txt12	equs	"Cannot write!  ",&0D

.xmess	ASL	A		\multiply message number by 16
	ASL A
	ASL A
	ASL A
	TAX
.xmess_a1
	LDA	txt0,X		\get a character
	JSR	OSASCI		\print it
	INX			    \increment index
	CMP	#cr		    \<cr>?
	BNE xmess_a1	\no, loop for next character
	RTS			    \else finished, return

\-------------------------------------------------------------------------------
\** end of WiCFS **

