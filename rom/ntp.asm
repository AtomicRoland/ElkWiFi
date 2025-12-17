\ Sideway ROM for Electron Wifi board

\ Get time from NTP server
\ (c) Timo Hartong, July 2023
\     http://www.timohartong.riscos.fr/NTP/index.html
\ Version 1.00

\ Syntax:       *TIME (or *DATE for compatibility with previous versions)
\               *TIMEZONE <offset from UTC>   (may be abbreviated to *TZ)

\ Contants specific for NTP so in this file
DRNOK% 		= 0 
DROK% 		= 1
FDBS% 		= &FD00
\ Area time.All one byte
HR%			= &80
MIN%		= &81
SEC%		= &82   
\ Area date.Yr 4 bytes rest 1
DAY%		= &84
MN%			= &85
YR%			= &88
\ Area date calculation
DYS% 		= &FD8C \ 4
ERA% 		= &FD90 \ 4
DOE% 		= &FD94 \ 4  
YOE% 		= &FD98 \ 4 
DOY% 		= &FD9C \ 4  
\REM Div32 variables
zNum% 		= &FDA0 \ 4 
zDen% 		= &FDA4 \ 4
zTemp% 		= &FDA8 \ 4
zRem% 		= &FDAC \ 4 
\REM Mul32
NM1% 		= &FDB0 \ 4  
NM2% 		= &FDB4 \ 4 
MLR% 		= &FDB8 \ 8 
\ Misc
STORE% 		= &FDC0 \ 4 
DAYT%  		= &FDC4 \ 4
TIMEVAR% 	= &C8 	\ 5  
MP% 		= &FDD0 \ 1
DOW%		= &FDD1	\ 1 Day of week
YRCENT%		= &FDD2 \ 1 Century part of the Year
YRTENS%		= &FDD3 \ 1 Centure 10's part of the year
BCDSCRAP	= &FDD4 \ 1 Scrap for BCD conversions
tst1		= &FDF0
tst2 		= &FDF1
tst3		= &FDF2
tst4 		= &FDF3
param1		= &F8
param2		= &F9
setTime		= &FB  
storetime 	= &FC
RSTAT% 		= &FD
UtcOffNeg 	= &FE
UtcOff 		= &FF

\ Date string area and ip-address eare on page 1 of Wi-Fi RAM
\ Sat,04 Mar 1923.13:12:12
\ DDD,dd mmm yyyy.hh:mm:ss 
\ 0123456789ABCDEF01234567
Day 		= &00	  \ Three positions Mon,Tue,Wed,Thu,Fri,Sat,Son
DayNr		= &04	  \ Padding zero
MonthName	= &07	  \ Name of the month
Year		= &0B	  \ Year 
Hour		= &10	  \ Hour
Minutes		= &13	  \ Minutes
Seconds		= &16	  \ Seconds
\
IpAddres	= &20	  \ Start of IP-address

.ntp_date_time_host
equs "UDP",&0d
\equs "0.nl.pool.ntp.org",&0D
equs "ntp.time.nl",&0D
equs "123",&0d,&00

.timestring
equs "Day,DD Mon Year.HH:MM:SS",&0d,&00

.daynames
equs "Sun",&00	\ 0
equs "Mon",&00	\ 4
equs "Tue",&00	\ 8
equs "Wed",&00	\ 12
equs "Thu",&00	\ 16
equs "Fri",&00	\ 20
equs "Sat",&00	\ 24

.monthnames
equs "    "	\ 0		Too lazy to substract one from the month
equs "Jan "	\ 4
equs "Feb "	\ 8
equs "Mar "	\ 12
equs "Apr "	\ 16
equs "May "	\ 20
equs "Jun "	\ 24
equs "Jul "	\ 28
equs "Aug "	\ 32
equs "Sep "	\ 36
equs "Oct "	\ 40
equs "Nov "	\ 44
equs "Dec "	\ 48

.ntp_data_req	
equb &1B		\ Eight bits. Mode 
equb &00		\ Eight bits. Stratum level of the local clock.         
equb &00		\ Eight bits. Maximum interval between successive messages.
equb &00		\ Eight bits. Precision of the local clock.	
equd &00000000 	\ 32 bits. Total round trip delay time.
equd &00000000	\ 32 bits. Max error aloud from primary clock source.
equd &00000000	\ 32 bits. Reference clock identifier.
equd &00000000	\ 32 bits. Reference time-stamp seconds.
equd &00000000	\ 32 bits. Reference time-stamp fraction of a second.
equd &00000000	\ 32 bits. Originate time-stamp seconds.
equd &00000000	\ 32 bits. Originate time-stamp fraction of a second.
equd &00000000	\ 32 bits. Received time-stamp seconds.
equd &00000000	\ 32 bits. Received time-stamp fraction of a second.
equd &00000000	\ 32 bits and the most important field the client cares about. Transmit time-stamp seconds.
equd &00000000	\ 32 bits. Transmit time-stamp fraction of a second.
.ntp_data_req_end

\ OS_Word 14
.ntpdriver
	sta save_a                 \ save registers
	stx save_y
	sty save_x					 \ This has to be done to fix X = low and Y = high and be able to use paramblok
	
	ldy #0						 \ On location 0 the reason code
	lda (paramblok),y
	cmp #0						 \ Return clock in ASCII string
	beq ReturnString
	cmp #1						 \ Return clock in BCD
	beq SevenByte	  			\ 7 Byte return string
	cmp #9
	beq EighByte	  			\ 8 Byte return string
	rts
	
.ReturnString				\ OS_Word 14 return string
	jsr OSWordCommon
	jsr SelPageOne				\ The string is in page 1
	ldy #0						\ Start of the string
.RSL1						\ Copy the timestring in the parameter block
	lda FDBS%,y
	sta (paramblok),y			
	iny
	cpy #25
	bne RSL1
	rts	
	
\ Function of the OSWORD 14 Function 1 return date and time in BCD in 7 Bit BCD 
\ FIXME add binary to BCD conversion.
\ FIXME Change ProcLogic that no error is given when there is no time or date.
.SevenByte
	jsr OSWordCommon
	jsr SelPZ
	ldy #0
	lda YRTENS%
	jsr BN2BCD
	sta (paramblok),y			\ Year &00 - &99
	iny
	lda FDBS% + MN%
	jsr BN2BCD
	sta (paramblok),y			\ Month &00 - &12
	iny
	lda FDBS% + DAY%
	jsr BN2BCD
	sta (paramblok),y			\ Day of month &00 - &31
	iny
	lda DOW%
	jsr BN2BCD
	sta (paramblok),y			\ Day of week &0 - &6
	iny
	lda FDBS% + HR%
	jsr BN2BCD
	sta (paramblok),y			\ Hours &00 - &23
	iny
	lda FDBS% + MIN%
	jsr BN2BCD
	sta (paramblok),y			\ Minutes &00 - &59 
	iny
	lda FDBS% +SEC%
	jsr BN2BCD
	sta (paramblok),y			\ Seconds &00 - &59
	rts

.EighByte
	jsr OSWordCommon
	jsr SelPZ
	ldy #0
	lda YRCENT%
	jsr BN2BCD
	sta (paramblok),y			\ Year &00 - &99
	iny
	lda YRTENS%
	jsr BN2BCD
	sta (paramblok),y			\ Year &00 - &99
	iny
	lda FDBS% + MN%
	jsr BN2BCD
	sta (paramblok),y			\ Month &00 - &12
	iny
	lda FDBS% + DAY%
	jsr BN2BCD
	sta (paramblok),y			\ Day of month &00 - &31
	iny
	lda DOW%
	jsr BN2BCD
	sta (paramblok),y			\ Day of week &0 - &6
	iny
	lda FDBS% + HR%
	jsr BN2BCD
	sta (paramblok),y			\ Hours &00 - &23
	iny
	lda FDBS% + MIN%
	jsr BN2BCD
	sta (paramblok),y			\ Minutes &00 - &59 
	iny
	lda FDBS% +SEC%
	jsr BN2BCD
	sta (paramblok),y			\ Seconds &00 - &59
	rts

.OSWordCommon
	lda save_y					\ First store paramblok
	pha							\ Put on stack
	lda save_x
	pha							\ Put on stack
	jsr ProcLogic				\ Get date and time and decode it
	jsr CrTimeStr				\ We have date and time create the date and time string
	pla
	sta save_x
	pla
	sta save_y
	rts
	
\ Convert binary data into BCD 
\ Entry:
\ A = binary data
\ Exit:
\ A = BCD Data
.BN2BCD
	ldx #&FF					\ start quotient at -1
	SEC							\ Set carry for initial subtraction
.BN2BCDL1
	inx							
	sbc #10
	bcs BN2BCDL1				\ branch is A still larger that 10
	adc #10						\ add the last 10 back
	sta BCDSCRAP				\ Save the 1's digit
	txa							\ get 10's digit
	asl A
	asl A
	asl A
	asl A						\ Move 10's to high nibble of A
	ora BCDSCRAP				\ OR 10's with 1's 
	rts
	
.BCD2BN
	tay
	and #&F0
	lsr A
	sta BCDSCRAP
	lsr A
	lsr A
	clc
	adc BCDSCRAP
	sta BCDSCRAP
	tya
	and #&0F
	clc
	adc BCDSCRAP
	rts

\ Get NTP Time
\ We have the command if a '0' is behind the command the time is not stored
\ if the command is followed by a '1' the time is stored in the TIME variable
.ntptime_cmd
	lda (line),y                \ load current character in command line
	cmp #&0D                    \ test if no paramaters given
	beq ntptime_cmd_L1
	jsr skipspace
	cmp #'1'
	beq ntptime_cmd_L2
.ntptime_cmd_L1
	jsr ProcLogic
	jsr PrintTimeAndDate
	jmp call_claimed		\ end of command
.ntptime_cmd_L2
	jsr ProcLogic
	jsr PrintTimeAndDate
	jsr StoreToTIME
	jmp call_claimed		\ end of command

\ Set UTC offset
.utcoff_cmd
	lda (line),y                \ load current character in command line
    cmp #&0D                    \ test if no paramaters given
    beq utcoff_error           	\ if &0D then there are no parameters
	jmp utcoff_cmd_decode
	
.utcoff_error
	jsr printtext              	\ no destination, print a message
	equs "Usage: *TIMEZONE <offset from UTC>",&0D,&EA
	jmp call_claimed			\ end of command
	
\ If we look to the command we can have the following situation:
\ | n | &0D => one digits
\ | n | n | &0D => Two digits 
\ | - | n | &0D => One negative digit 
\ | - | n | n | &0D => Two negative digits

.utcoff_cmd_decode
	jsr skipspace				\ forward Y pointer to first non-space character
	iny
	lda (line),y 				
	cmp #&0D
	beq UtcOff_OneDigit
	iny
	lda (line),y 
	cmp #&0D
	beq UtcOff_L3
	dey
	dey	
	lda (line),y 
	cmp #'-'					\ With 3 characters the first 
	bne utcoff_error
	iny
	lda (line),y
	and #&0F					\ Do a simple AND to get number
	sta NM1%					\ FIXME not copro compitable
	lda #10
	sta NM2%
	jsr Mul32
	lda MLR%
	sta NM1%
	iny
	lda (line),y
	and #&0F
	sta NM2%
	jsr Add32
	lda NM1%
	cmp #13
	bmi utcoff_cmd_end
	jmp utcoff_error			\ Out of range value ( -12 ) 
.utcoff_cmd_end
	sec
	lda #0
	sbc NM1%
	jmp UtcOffWrite
	
.UtcOff_OneDigit
	dey
	lda (line),y
	and #&0F					\ Do a simple AND to get number
.UtcOffWrite
    tay                         \ Transfer offset to Y register
	jsr SetUtcOff               \ Write to storage
	jmp call_claimed			\ end of command

\ Two characters this can have the following forms:
\ 1) | n | n |. This means some conversion has to be done
\ 2) | - | n |. A negative number	
.UtcOff_L3
	dey
	dey
	lda (line),y
	cmp #'-'
	beq utcoff_2Neg
	and #&0F					\ Do a simple AND to get number
	sta NM1%					\ FIXME not copro compitable
	lda #10
	sta NM2%
	jsr Mul32
	lda MLR%
	sta NM1%
	iny
	lda (line),y
	and #&0F
	sta NM2%
	jsr Add32
	lda NM1%
	cmp #15						\ Maximise input to +14 
	bmi UtcOff_L3_End
	jmp utcoff_error			\ Out of range value ( +12 ) 
.UtcOff_L3_End
	jmp UtcOffWrite

\ A single negative number	
.utcoff_2Neg
	iny							\ We want to have the number first
	lda (line),y
	and #&0F					\ Do a simple AND to get number
	sta (line),y
	sec
	lda #0
	sbc (line),y
	jmp UtcOffWrite

\ Set the UTC value to the default value
.SetUTCToZero
    jsr GetDefaultOffset        \ Read the default UTC Offset (= time zone)
    jmp SetUtcOff               \ Write this to storage and return from subroutine

\  Process logic
.ProcLogic 
	lda #WriteJim
	ldx #RSTAT%
	ldy #DRNOK%
	jsr osbyte
	jsr GetData 
	jsr GetResData
	\ Check result if NOK return
	lda #ReadJim
	ldx #RSTAT%
	jsr osbyte
	cpy #DROK%
	beq ProcLogicEnd
	jmp date_time_error
.ProcLogicEnd
	jsr DecodeData	
	rts

\ After getting the time transform it to date and time. After the UTC correction
.DecodeData
	jsr UTCCorr  			\ Apply UTC offset correction 
	jsr DecoTime 			\ Get the time
	jsr DecoDate			\ Get the date
	jsr SplitYear			\ Split the year into Century and year tens
	jsr GetDayOfWeek		\ Calculate the day of the week
	rts

.GetData
	jsr ClearBuff 
	jsr UDPConn
	jsr UDPReq 
	jsr CloseConn 
	rts

\ Sets first and second page of WiFi RAM to 0
.ClearBuff
	lda #WriteFred
	ldx #&FF
	ldy #0
	jsr osbyte
	lda #WriteJim
	ldx #&F0	\ Was &FD
.ClearBuffL1
	ldy #0
	jsr osbyte
	dex
	bne ClearBuffL1 
	\ Now select page 1 
	lda #WriteFred
	ldx #&FF
	ldy #1
	jsr osbyte
	lda #WriteJim
	ldx #&40	
.ClearBuffL2
	ldy #0
	jsr osbyte
	dex
	bne ClearBuffL2
	rts

\ Set up connection and get data
.UDPConn
	lda #8                         \ open tcp connection to server
	ldx #>ntp_date_time_host
	ldy #<ntp_date_time_host
	jsr wifidriver
	rts
   
.UDPReq
	\ set pointer to ntp data request
	lda #<ntp_data_req
	sta data_counter+0
	lda #>ntp_data_req
	sta data_counter+1
	\ set data length
	lda #<(ntp_data_req_end-ntp_data_req)
	sta data_counter+2
	lda #>(ntp_data_req_end-ntp_data_req)
	sta data_counter+3
	lda #0
	sta data_counter+4
	ldx #data_counter              \ load index to parameters
	lda #13                        \ send get command
	jsr wifidriver
	rts

.CloseConn
	lda #14
	jsr wifidriver
	rts

.GetResData
	lda #WriteFred
	ldx #&FF
	ldy #0
	jsr osbyte
	ldx #0
	lda #ReadJim
.GRDL1
	\ Find correct response ( "+IPD" )
	jsr osbyte
	cpy #'+' 
	bne GRDNRSP
	inx
	jsr osbyte
	cpy #'I'
	bne GRDNRSP
	inx
	jsr osbyte 
	cpy #'P'
	bne GRDNRSP
	inx 
	jsr osbyte 
	cpy #'D' 
	bne GRDNRSP
	JMP GRDL2 
.GRDNRSP 		\ No (part off ) "+IPD" string found
	inx
	cpx #&80 	\ Have we reached vars ?
	bcc GRDL1 	\ No, Continue search for "+IPD"
				\ Yes return
.GRDND
	rts
.GRDL2 			\ Now start hunt for ':'  
	jsr osbyte 
	cpy #':'
	beq GRDSD
	inx
	cpx #&80 	\ Have we reached vars ?
	bcc GRDL2
	rts
.GRDSD  
	\ From ':' add the Offset to time in NTP struct \
	\ Taking endianity into account and store in a temp variable
	txa
	clc
	adc #41
	tax
	\ Offset to pointer added
	lda #ReadJim
	jsr osbyte
	sty STORE%+3  
	inx
	jsr osbyte
	sty STORE%+2
	inx
	jsr osbyte
	sty STORE%+1
	inx
	jsr osbyte
	sty STORE%
	\ quick test on time data \
	lda STORE%+3
	beq GRDND
	\ Result OK set in receive flag
	lda #WriteJim
	ldx #RSTAT% 
	ldy #DROK%
	jsr osbyte
	rts

.date_time_error  
 ldx #(error_no_date_time-error_table)
 jmp error


.SplitYear							\ Split year which is in binary form into Century and tens
	txa:pha
	tya:pha
	jsr SelPZ						\ Make sure the correct page in Wi-Fi RAM is selected.
	jsr ClearNums					\ Clear NM1% and NM2% to do calculation year / 100
	ldx #3							
.SPL1
	lda FDBS%+YR%,X : sta NM1%,X	\ Copy year into NM1%
	dex
	bpl SPL1						\ Copy year in NM1%
	lda #100						\ 
	sta NM2%						\ Store in NM2% 
	jsr Div32						\ Result of the addition is still in NM1% now do the division
	lda zRem% : sta YRTENS%			\ Store tens part
	lda zNum% : sta YRCENT%			\ Store Century part
	pla:tay
	pla:tax
	rts

\ Routine to calculate the day of the week. NTP counts the days from 1970.01.01 
\ Based on the C function : (z+4) % 7
.GetDayOfWeek 
	jsr SelPZ						\ Make sure the correct page in Wi-Fi RAM is selected.
	ldx #3
.GDOW1
	lda #0
	sta NM2%,X						\ Clear all of NM2%
	lda DAYT%,X
	sta NM1%,X						\ Copy the number of days since 1970.01.01 into NM1%
	DEX
	bpl GDOW1
	lda #1 							\ 1-1-1900 = Monday 
	sta NM2%
	jsr Add32						\ Do the (z+n) part
	lda #7
	sta NM2%
	jsr Div32						\ Result of the addition is still in NM1% now do the division
	lda zRem%
	sta DOW%						\ Store the result in Day of the week var
	rts

.UTCCorr
	\ UTC Correction must be executed before any time and date related action.
	\ This function gets the UTC correction out the variable and adds or substracts
	\ it from the time
	txa:pha
	tya:pha
	\ Get UTC flag
	jsr GetUtcOff
	\ The UTC value can be 0, positive or negative. All need slightly different algoritms. 0 means no action is needed
	cpy #0
	beq UTCCEND
	BMI UTCCNEG
	tya:pha
	jsr SelPZ
	pla:TAY
	jsr StoZero
	sty NM2% \ UTC > 0
	jsr Mul32 
	jsr StoMLR
	jsr Add32
	jsr NMToSTR
	JMP UTCCEND
.UTCCNEG
	tya:pha
	jsr SelPZ
	pla:TAY
	jsr StoZero
	DEY
	tya
	EOR #&FF
	STA NM2%
	jsr Mul32
	jsr StoMLR
	jsr Sub32
	jsr NMToSTR
.UTCCEND
	pla:TAY
	pla:TAX
	rts
	
.NMToSTR
\ Copies NM1% to STORE%
\ Reg. X and A preserved 
	txa:pha
	pha 
	ldx #3
.NMTSTR1
	lda NM1%,X:STA STORE%,X
	DEX 
	bpl NMTSTR1
	pla
	pla:TAX  
	rts

.StoMLR
	\ Copies STORE% to NM1%
	\ Copies MLR% to NM2%
	\ Preserves A and Z
	txa:pha
	pha 
	ldx #3
.STMLR1
	lda STORE%,X:STA NM1%,X
	lda MLR%,X:STA NM2%,X  
	DEX
	bpl STMLR1
	pla
	pla:TAX
	rts
	
.StoZero
\ Copy STORE % in NM1%
\ Fill NM2% with 0
\ Reg. X  and A preserved  
	txa:pha
	pha 
	ldx #3
	.STZE1
	lda HrsS,X : STA NM1%,X
	lda #0: STA NM2%,X
	DEX
	bpl STZE1 
	pla
	pla:TAX
	rts
	
.SelPZ
\ Select page 0 in the Wi-Fi RAM
\ Reg X,Y and A preserved
	pha
	txa:pha
	tya:pha
	lda #WriteFred
	ldx #&FF
	ldy #0
	jsr osbyte 
	pla:tay 
	pla:tax
	pla
	rts
	
\ Select page 1 in the Wi-Fi RAM
.SelPageOne
	pha
	txa:pha
	tya:pha
	lda #WriteFred
	ldx #&FF
	ldy #1
	jsr osbyte 
	pla:tay 
	pla:tax
	pla
	rts

\ The first step is to have the raw value ( which is whole seconds ) and split in time
\ and days. For this we devide the raw value with the number of seconds in a Day
\ ( 24 hrs * 60 minutes * 60 seconds )
.DecoTime
	ldx #3
.DTL1 										
	lda STORE%,X:sta NM1%,X 			\ Load the raw value
	lda DayS,X:sta NM2%,X  				\ Load the divisor 86,400
	dex
	bpl DTL1
	jsr Div32 							\ Do the devide
	\ hours = seconds / 3600 \
	ldx #3								\ 4 bytes of relevant data
.DTL2
	lda zNum%,X:sta DAYT%,X 			\ Store the the number of days 
	lda zRem%,X:sta NM1%,X   			\ Prepare the seconds to be divided by 3600 to hrs
	lda zRem%,X:sta FDBS% + TIMEVAR%,X	\ To be used to set TIME value
	lda HrsS,X:sta NM2%,X 				\ Load 3600 
	dex
	bpl DTL2 							\ Loop until all 4 bytes are stored
	jsr Div32 							\ Do the divide
	lda zNum%:sta FDBS% + HR%			\ To store the hour we only need to store the lower byte
	ldx #3
.DTL3
	lda zRem%,X:sta NM1%,X 				\ Now the last part the minutes and Seconds
	lda #0:sta NM2%,X  					\ Clear the variable for the division
	dex
	bpl DTL3
	lda #&3C:sta NM2%					\ Devide by 60
	jsr Div32  							\ Do the divide
	lda zNum% : sta FDBS% + MIN%		\ Store the results
	lda zRem% : sta FDBS% + SEC%  
	rts									\ Function completed
	
.DayS
EQUD &00015180
.HrsS
EQUD &00000E10
.YrCr
EQUD &000A968D
.Yr400
EQUD &00023AB1
.c1460
EQUD &000005B4
.c36524
EQUD &00008EAC
.c146096
EQUD &00023AB0

\ 
.DecoDate
	ldx #3
.DDL1 
	lda DAYT%,X:sta NM1%,X 				\ Get the number of the dates
	lda YrCr,X:sta NM2%,X 				\ The shift . How does this work
	dex
	bpl DDL1 							\ Loop until all 4 bytes are prepared
	jsr Add32							\ Do the shift   
	ldx #3 
.DDL3 									\ Now calculate the era we have simplified the algoritm here because the era will 
										\ the era will always be 5 ( 2000-03-01	to 2400-02-29 ). The calculation is : era = days / 146097
	lda NM1%,X:sta DYS%,X  
	lda Yr400,X:sta NM2%,X 				\ The constant is 146097
	dex
	bpl DDL3 							\ Loop until all 4 bytes are stored
	jsr Div32							\ Do the divide
	ldx #3
.DDL5 									\ Now we want the day number in are. This is done with the calculation days - era * 146097 
										\ Because we are in assembly this calculation is done in steps. First we do era * 146097 
	lda zNum%,X:sta ERA%,X 				\ Store the ERA
	lda zNum%,X:sta NM1%,X 				\ Prepare for the calculation
	dex
	bpl DDL5							\ Loop until all 4 bytes are stored
	jsr Mul32							\ Do the multiplication
	ldx #3
.DDL6 
										\ substract the multiplication from the days
	lda MLR%,X:sta NM2%,X 				\ era * 146097 
	lda DYS%,X:sta NM1%,X 				\ days
	dex	
	bpl DDL6							\ Loop until all 4 bytes are stored 
	jsr Sub32							\ Do the subtraction
	ldx #3
.DDL7 									\ The next calculation is yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365
										\ First the calculation doe - doe / 1460. Start with the calculation doe / 1460 
	lda NM1%,X:sta DOE%,X				\ Store the result in doe%
	lda c1460,X:sta NM2%,X				\ Constant 1460 for doe/1460
	dex
	bpl DDL7							\ Loop until all 4 bytes are stored 
	jsr Div32							\ Do the division 
	ldx #3
.DDL8 									\ Now doe - doe/1460
	lda zNum%,X:sta NM2%,X
	lda DOE%,X:sta NM1%,X
	dex
	bpl DDL8 							\ Loop until all 4 bytes are stored 
	jsr Sub32							\ Do the subtraction
	ldx #3
.DDL9 									\ Now the doe/36524 part
	lda NM1%,X:sta STORE%,X 			\ Store the result in an intermidiate variable
	lda DOE%,X:sta NM1%,X  				\ 
	lda c36524,X:sta NM2%,X  			\ Constant 36524
	dex
	bpl DDL9							\ Loop until all 4 bytes are stored 
	jsr Div32							\ Do the devide
	ldx #3
.DDLA 
	lda zNum%,X:sta NM1%,X 				\ Get result of devision
	lda STORE%,X:sta NM2%,X 			\ Get the intermidiate value to be added
	dex
	bpl DDLA 							\ Loop until all 4 bytes are stored
	jsr Add32							\ Do the addition
	ldx #3
.DDLB									\ The - doe/146096 calculation
	lda NM1%,X: sta STORE%,X 			\ First put the result of the last calculation 
	lda DOE%,X:sta NM1%,X 				\ Prepare for doe/146096 
	lda c146096,X:sta NM2%,X  			\ Constant 146096
	dex
	bpl DDLB 							\ Loop until all 4 bytes are stored 
	jsr Div32							\ Do the Devide
	ldx #3
.DDLC
	lda STORE%,X:sta NM1%,X				\ Get the intermidiate value to be substracted
	lda zNum%,X:sta NM2%,X 				\ Get the result of the division
	dex
	bpl DDLC							\ Loop until all 4 bytes are stored 
	jsr Sub32							\ Do the subtraction
	ldx #3
.DDLD 									\ Do the  / 365 part
	lda year,X:sta NM2%,X  				\ constant 365
	dex									
	bpl DDLD 							\ Loop until all 4 bytes are stored 
	jsr Div32							\ Do the division
	\ Store result in YOE% 
	ldx #3   
.DDLE 
	lda zNum%,X:sta YOE%,X  
	dex
	bpl DDLE							\ Loop until all 4 bytes are stored
										\ yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365 calculation complete
	ldx #3
.DDLF									\ Calculation : year = yoe + era * 400 
	lda ERA%,X:sta NM1%,X 				\ Load Era
	lda c400,X:sta NM2%,X 				\ Constant 400
	dex
	bpl DDLF							\ Loop until all 4 bytes are stored
	jsr Mul32							\ Do the multiplication 
	ldx #3
.DDL10									
	lda MLR%,X:sta NM1%,X   			\ Load the result from era * 400
	lda YOE%,X:sta NM2%,X 				\ Load yoe
	dex
	bpl DDL10
	jsr Add32							
	ldx #3 								\ Now store the year ( 4 bytes )
.DDL11
	lda NM1%,X:sta FDBS% + YR%,X		
	dex
	bpl DDL11
	ldx #3								\ Storage of the year complete
										\ Next calcualtion is  const unsigned doy = doe - (365*yoe + yoe/4 - yoe/100)
										\ First do the 365 * yoe calcualtion
.DDL12
	lda year,X:sta NM1%,X
	lda YOE%,X:sta NM2%,X 
	dex
	bpl DDL12
	jsr Mul32
	ldx #3
										\ The result is NM1%
										\ yoe / 4 which is basiccly a logical shift so we do shifting 
.DDL13
	lda YOE%,X:sta NM2%,X
	dex 
	bpl DDL13
	ldx #1
.DDL14
	LSR NM2%+3  
	ROR NM2%+2 
	ROR NM2%+1 
	ROR NM2% 
	dex
	bpl DDL14
	jsr Add32							\ We have done yoe/4 and the result from 365 * yoe is still in NM1% so we only have to do addition
	ldx #3
.DDL15 
	lda NM1%,X:sta STORE%,X    			\ Now save the intermidiate result from 365 * yoe + yoe /4 
	lda #0:sta NM2%,X  					\ clear NM2%
	lda YOE%,X:sta NM1%,X  			
	dex
	bpl DDL15
	lda #100:sta NM2% 					
	jsr Div32							\ you/100 calcualtion done
	ldx #3
.DDL16  
	lda zNum%,X:sta NM2%,X  			\ Get the result of the devision
	lda STORE%,X:sta NM1%,X 			\ Get the intermidiate result from 365 * yoe + yoe /4 
	dex
	bpl DDL16
	jsr Sub32							\ Now we have the result from 365*yoe + yoe/4 - yoe/100
	ldx #3
.DDL17
	lda NM1%,X:sta NM2%,X  				\ Do the last part doy = doe - (...)
	lda DOE%,X:sta NM1%,X 
	dex
	bpl DDL17
	jsr Sub32
	ldx #3
.DDL18
	lda NM1%,X:sta DOY%,X     			\ Store the result in DOY% and already prepare for the next calcualtion mp = (5*doy + 2)/153;
	lda #0:sta NM2%,X  					\ Clear NM2% to zero
	dex
	bpl DDL18
	lda #5:sta NM2% 
	jsr Mul32							\  5 * doy
	lda #2:sta NM2%  
	jsr Add32							\  5 * doy + 2
	lda #153:sta NM2% 
	jsr Div32							\ (5*doy + 2)/153
	lda zNum%:sta MP%   				\ The result which is one byte can be stored in MP%
										\ First we focus on the month m = mp < 10 ? mp+3 : mp-9;
	cmp #10
	bpl DDL19
	ADC #3
	sta FDBS%+MN%						
	JMP DDL1A 
.DDL19
	SBC #9
	sta FDBS%+MN%
.DDL1A
	cmp #3								\ ????
	bpl DDL1B							\ Do y + (m <= 2)
	ldx #3
.DDL1C
	lda FDBS% + YR%,X:sta NM1%,X		\ Load the stored year
	lda #0:sta NM2%,X  					\ Clear NM2%
	dex
	bpl DDL1C
	lda #1:sta NM2%  					\ Load 1
	jsr Add32
	ldx #3
.DDL1D
	lda NM1%,X:sta FDBS%+YR%,X			\ Store the year variable back
	dex
	bpl DDL1D
										\ d = doy - (153*mp+2)/5 + 1;
.DDL1B									\ Clear NM1% and NM2%
	ldx #3
	lda #0
.DDL20 
	sta NM1%,X:sta NM2%,X 
	dex
	bpl DDL20
	lda #153:sta NM2%
	lda MP%: sta NM1%  
	jsr Mul32							\ 153*mp
	lda #2:sta NM2% 
	jsr Add32							\ 153*mp+2
	lda #5:sta NM2%  
	jsr Div32							\ (153*mp+2)/5
	ldx #3
.DDL21									\ doy - (...)/5
	lda zNum%,X:sta NM2%,X 
	lda DOY%,X:sta NM1%,X 
	dex
	bpl DDL21
	jsr Sub32
	ldx #3
	lda #0
.DDL22
	sta NM2%,X							\ Clear NM2%
	dex
	bpl DDL22
	lda #1:sta NM2%
	jsr Add32							
	lda NM1% :sta FDBS%+DAY%			\ Store the result in day
	rts
.year
EQUD &0000016D
.c400
EQUD &00000190

\ 32 bits multiplication routine
.Mul32
	lda #0
	sta MLR%+4
	sta MLR%+5 
	sta MLR%+6
	sta MLR%+7
	ldx #3
.Mul32L1
	lda NM1%,X:sta MLR%,X
	dex
	bpl Mul32L1 
	ldx #&21
	bne staRT_R
.SHIFT_R
	bcc ROTATE_R 
	lda MLR%+4  
	CLC
	adc NM2% 
	sta MLR%+4 
	lda MLR%+5
	adc NM2%+1
	sta MLR%+5 
	lda MLR%+6   
	adc NM2%+2
	sta MLR%+6   
	lda MLR%+7 
	adc NM2%+3
	sta MLR%+7 
.ROTATE_R
	ROR A
	ROR MLR%+6
	ROR MLR%+5
	ROR MLR%+4
.staRT_R 
	ROR MLR%+3
	ROR MLR%+2
	ROR MLR%+1
	ROR MLR%
	dex
	bne SHIFT_R
	ldx #3
.Mul32L2
	lda MLR%,X:sta NM1%,X      
	dex
	bpl Mul32L2 
	rts

.Sub32  
	PHP
	txa:pha
	tya:pha
	ldx #4
	ldy #0
	CLD 
	SEC 
.Sub32L1
	lda NM1%,Y
	SBC NM2%,Y
	sta NM1%,Y
	INY
	dex
	bne Sub32L1
	pla:TAY
	pla:TAX 
	PLP
	rts

\ 32 Bits addition routine
.Add32
	txa:pha
	tya:pha
	ldy #0
	ldx #4
	CLD
	CLC
.Add32L1
	lda NM1%,Y
	adc NM2%,Y
	sta NM1%,Y
	INY
	dex
	bne Add32L1 
	pla:TAY
	pla:TAX
	rts
	
\ 32 Bits devision routine
.Div32
	txa:pha
	tya:pha
	lda #0
	sta &FCFF
	ldx #3
.CND
	lda NM1%,X:sta zNum%,X  
	lda NM2%,X:sta zDen%,X  
	lda #0:sta zRem%,X
	dex
	bpl CND 
	ldx #32
.Divide 
	ASL zNum%
	ROL zNum% + 1
	ROL zNum% + 2
	ROL zNum% + 3
	ROL zRem% 
	ROL zRem% + 1
	ROL zRem% + 2
	ROL zRem% + 3
	SEC
.Subtract 
	lda zRem% 
	SBC zDen%
	sta zTemp%
	lda zRem% + 1
	SBC zDen% + 1
	sta zTemp% + 1   
	lda zRem% + 2
	SBC zDen% + 2
	sta zTemp% + 2  
	lda zRem% + 3
	SBC zDen% + 3
	sta zTemp% + 3     
	bcc Next
	INC zNum%
	ldy #3
.CpTmpToRem
	lda zTemp%, Y
	sta zRem% , Y
	DEY
	bpl CpTmpToRem
.Next 
	dex
	bne Divide
	pla:TAY
	pla:TAX
	rts
	
\ Stores the calculated time to TIME var  
.StoreToTIME 
	jsr SelPZ
	ldx #3
.STTI1
	lda #0:sta NM1%,X
	lda FDBS%+TIMEVAR%,X: sta NM2%,X
	dex
	bpl STTI1
	lda #100:sta NM1%
	jsr Mul32
	ldx #3
.STTI2
	lda MLR%,X:sta FDBS%+TIMEVAR%,X
	dex
	bpl STTI2
	lda #&2
	ldx #(FDBS%+TIMEVAR%) MOD 256
	ldy #(FDBS%+TIMEVAR%) DIV 256
	jsr osword
	rts

.PrintTimeAndDate				\ Create and print the time string
								\ With the command *TIME the time is created and printed but
								\ with OS_Word for example not
	jsr CrTimeStr		\ First create the time string
	jsr PrintTimeDate			\ Print it
	rts

.CrTimeStr
								\ Prints the date and time stored to a string in the current implementaiton
								\ the string is printed directly afterwards but that this could be changed if
								\ needed
								\ Region common are for date and time : and .
	jsr SelPageOne				\ The date string is one page 1
	lda #'.'
	sta FDBS% + Hour - 1
	lda #':'
	sta FDBS% + Hour + 2
	sta FDBS% + Minutes + 2
								\ Region day of the month
	jsr SelPZ					\ Go back to page 0 
	lda FDBS% + DAY%
	jsr splitdigits
	jsr SelPageOne	
	sta FDBS% + DayNr
	txa
	sta FDBS% + DayNr + 1
	lda #' '
	sta FDBS% + DayNr + 2
								\ Region Month
	jsr SelPZ					\ Make sure page 0 on the Wi-Fi card selected
								\ Printing the month is a text so we have to convert the month number into text
	lda FDBS% + MN%				\ Get the month
	ASL	A						\ Multiply number by 4 so we have the 
	ASL	A
	tax							\ Transfer A into X
	ldy #0
	jsr SelPageOne				\ The date string is one page 1
	lda monthnames, X
	sta FDBS% + MonthName
	inx
	lda monthnames, X
	sta FDBS% + MonthName + 1
	inx
	lda monthnames, X
	sta FDBS% + MonthName + 2
	inx
	lda monthnames, X
	sta FDBS% + MonthName + 3
								\ Year area. The year is split into a year and a century
	jsr SelPZ					\ Select page 0 to reset MN1 and MN2
	lda YRCENT%
	jsr splitdigits				\ Split the value into two ASCII numbers
	jsr SelPageOne				\ On page 1 of RAM of Wi-Fi card the string is located
	sta FDBS% + Year
	txa
	sta FDBS% + Year + 1		\ The century is now printed
	jsr SelPZ					\ Go to page 0 to get the stored year back
	lda YRTENS%
	jsr splitdigits				\ Split the value into two ASCII numbers
	jsr SelPageOne				\ On page 1 of RAM of Wi-Fi card the string is located
	sta FDBS% + Year + 2
	txa
	sta FDBS% + Year + 3		\ The tens of the year is now printed
								\ The year has been converted into ASCII now continue with converting time
								\ Region time preparation. This entails already setting the locations with . and :

								\ Region Hours 
	jsr SelPZ					\ Go back to page 0 
	lda FDBS% + HR%
	jsr splitdigits				\ Split the value into two ASCII numbers
	jsr SelPageOne				\ On page 1 of RAM of Wi-Fi card the string is located
	sta FDBS% + Hour
	txa
	sta FDBS% + Hour + 1
								\ Region Minutes
	jsr SelPZ					\ In page 0 time and data is stored
	lda FDBS% + MIN%			\ Get minutes
	jsr splitdigits				\ Split the value into two ASCII numbers
	jsr SelPageOne				\ On page 1 of RAM of Wi-Fi card the string is located
	sta FDBS% + Minutes
	txa
	sta FDBS% + Minutes + 1
								\ Region Seconds
	jsr SelPZ					\ In page 0 time and date is stored
	lda FDBS% + SEC%			\ Get seconds
	jsr splitdigits				\ Split the value into two ASCII numbers
	jsr SelPageOne				\ On page 1 of RAM of Wi-Fi card the string is located
	sta FDBS% + Seconds
	txa
	sta FDBS% + Seconds + 1
	lda #&0D
	sta FDBS% + Seconds + 2
								\ Region Day of the week
	jsr SelPZ					\ In page 0 time and date is stored
	lda DOW%					\ Load the day of the week
	ASL	A						\ Multiply number by 4
	ASL	A
	tax							\ Transfer A into X
	dex  						\ Substract 1 to correct for the loop
	jsr SelPageOne				\ The string is in page 1
	ldy #Day					\ Load the constant constant of the day in the string
	dey
.CreateStringL1
	inx
	iny
	lda daynames, X
	sta FDBS%, Y
	bne CreateStringL1
	lda #','					\ End of the day name add ,
	sta FDBS%, Y
	rts
	
.PrintTimeDate
	jsr SelPageOne				\ The string is in page 1
	ldx #0						\ Start of the string
.PTAD_L1
	lda FDBS%,x
	inx
	jsr oswrch
	bne PTAD_L1
	jsr osnewl
	rts

\ in A register number to spilt in ASCII numbers
\ OUt:
\ Reg A : High nible in ASCII number
\ Reg X : Low nible in ASCII number
\ Author : Simon Voortman
.splitdigits
	ldy #&FF				\ Start quoteint at -1
	cld
	sec						\ Set carry for initial subtraction
.SD01
	iny						\ add 1 to quotient
	sbc #10					\
	bcs SD01				\ branch if A is till larger that 10
	adc #10					\ add the last 10 back
	clc
	adc #'0'
	tax						\ units digit to X
	tya						\ 10's digit to A
	clc
	adc #'0'
	clc						\ clear carry
	rts

.ClearNums
	\ NM1 and NM2 are in one line \
	ldx #7
	lda #0
.CNL1
	sta NM1%,X 
	dex
	bpl CNL1
	rts


\ SetUtcOff
\ Writes UTC Offset (= time zone) from Y register into Paged RAM storage. A and X remain unchanged.
\ The UFC Offset is stored in the last byte of the last page in the second bank of paged RAM to
\ try to avoid that is will be overwritten by other software. However, it is not guaranteed that this
\ will never happen. A faulty offset will only result into a wrong date/time value.
.SetUtcOff
    pha                     \ save A
    jsr save_bank_nr        \ save current RAM bank number
    jsr set_bank_1          \ select Paged RAM bank 1
    lda pagereg             \ load page register
    pha                     \ save it on stack
    lda #&FF                \ load page number
    sta pagereg             \ set in page register
    sty pageram+&FF         \ read UTC offset
    pla                     \ restore page register
    sta pagereg
    jsr restore_bank_nr     \ restore the bank number
    pla                     \ restore A
    rts                     \ return from subroutine


\ GetUtcOff
\ Reads UTC Offset (= time zone) from Paged RAM storage into Y. A and X remain unchanged.
.GetUtcOff
    pha                     \ save A
    jsr save_bank_nr        \ save current RAM bank number
    jsr set_bank_1          \ select Paged RAM bank 1
    lda pagereg             \ load page register
    pha                     \ save it on stack
    lda #&FF                \ load page number
    sta pagereg             \ set in page register
    ldy pageram+&FF         \ read UTC offset
    pla                     \ restore page register
    sta pagereg
    jsr restore_bank_nr     \ restore the bank number
    pla                     \ restore A
    rts                     \ return from subroutine

\ GetDefaultOff
\ Reads the default Offset (= time zone) from ROM storage into Y. A and X remain unchanged. Please use
\ this routine to read the default offset just in case the storage location of the offset gets modified
\ in the futere.
.GetDefaultOffset
    ldy default_tz          \ load default time zone value
    rts                     \ that's all for now :-)
