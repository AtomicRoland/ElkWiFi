\ routines.asm

\ This routine prints a text string until a byte is read with bit7 set. It returns
\ to the first instruction after the string to be printed. This routine will usually
\ be called to print fixed strings in the ROM.
.printtext          pla                     \ get low byte from stack
                    sta zp                  \ set in workspace
                    pla                     \ get high byte from stack
                    sta zp+1                \ set in workspace
.printtext_l1       ldy #0                  \ load index
                    inc zp                  \ increment pointer
                    bne printtext_l2        
                    inc zp+1
.printtext_l2       lda (zp),y              \ load character
                    bmi printtext_l3        \ jmp if end of string
                    jsr osasci              \ print character
                    jmp printtext_l1        \ next character
.printtext_l3       jmp (zp)                \ return to calling routine


\ This routine prints a text string until the &0D character is encountered. It returns
\ after the calling jsr instruction. This routine will usually be called to print text
\ strings from the ESP8266 response.
\.print_string
.print_string       jsr read_buffer          \ read character
                    beq print_string_end     \ on end of buffer also end routine
                    jsr osasci               \ print it
                    cmp #&0D                 \ test end of string
                    bne print_string         \ continue for next character
.print_string_end   rts                      \ end of routine


\ This routine reads characters from the command line and returns after the first
\ non-space character. The Y register points to this character. The accu holds the
\ first non-space character.
.skipspace          iny                     \ increment pointer
.skipspace1         lda (line),y            \ load character
                    cmp #&20                \ is it a space
                    beq skipspace           \ yes, read next character
                    rts                     \ it's not a space, return


\ This routine prints the value of the accu in hex digits
.printhex           pha                     \ save accu
                    lsr a                   \ shift high nibble to low
                    lsr a
                    lsr a
                    lsr a
                    jsr printhex_l1         \ print nibble
                    pla                     \ restore value
 .printhex_l1       and #&0F                \ remove high nibble
                    cmp #&0A                \ test for hex digit
                    bcc printhex_l2         \ if not then continue
                    adc #6                  \ add 6 for hex letter
 .printhex_l2       adc #&30                \ add &30 for ascii value
                    jmp osasci              \ print the digit and return

\ This routine converts the hexadecimal string in the string buffer to
\ a 16 bit integer address. The destination in the zeropage is pointed by the
\ X register. On exit X and Y will be preserved. A indicates whether there 
\ was an address (A <> 0) or not (A == 0)
.string2hex         tya                     \ save Y register on stack
                    pha
                    lda #0                  \ reset accu and zeropage
                    sta &00,x
                    sta &01,x
                    sta &02,x
                    tay                     \ reset pointer
.string2hex_l1      lda strbuf,y            \ load character
                    cmp #&0D                \ check for end of string
                    beq string2hex_end      \ it's the end, so jump
                    jsr digit2hex           \ convert to hex value
                    bcs string2hex_end      \ a false digit was encountered, end routine
                    asl a                   \ shift four times left
                    asl a
                    asl a
                    asl a
                    sty &02,x               \ save index
                    ldy #4                  \ load bit shift counter
.string2hex_l2      asl a                   \ shift left
                    rol &00,x               \ shift into zeropage
                    rol &01,x               \ shift also high byte
                    dey                     \ decrease counter
                    bne string2hex_l2       \ do next bit
                    ldy &02,x               \ restore the index
                    iny                     \ increment index
                    bne string2hex_l1       \ process next digit
.string2hex_end     pla                     \ restore Y
                    tay
                    lda &02,x               \ load saved index, if 0 then there was no parameter
                    rts

\ Converts an ascii character to hexadecimal value. If the character is not a valid hex digit 
\ then the routine will exit with A undefined and carry set. If no error is encountered then A
\ holds the hex value and the carry is cleared.
.digit2hex          cmp #'0'                \ test for character smaller than '0'
                    bcc digit2hex_inv       \ jump if invalid character
                    cmp #':'                \ test if character larger than '9'
                    bcc digit2hex_conv      \ jmp if valid character
                    sbc #7                  \ substract 7 to skip characters &3A-&3F
                    bcc digit2hex_inv       \ jmp if invalid character 
                    cmp #'@'                \ test for larger than '@'
                    bcs digit2hex_inv       \ jump if invalid character
.digit2hex_conv     and #&0F                \ clear high nibble so the hex value is in the accu
                    rts
.digit2hex_inv      sec                     \ set carry
                    rts

\ This short routine restores the registers X and Y and sets the accumulator to &00 to claim a call.
.call_claimed
                    \ jsr restore_bank_nr     \ restore paged ram bank number
                    pla                     \ restore x and y
                    tax
                    pla
                    tay
                    lda #&00
                    rts

 \ find routine: search for a needle in a haystack.
 \ The haystack is the paged ram. 
 \ zeropage: X-reg    = pointer to memory block in current selected ram page
 \           needle   = pointer to string
 \           size     = number of bytes to search
 \ on exit:  carry = 1: string found, X points directly after needle in paged ram buffer
 \           carry = 0: string not found
 \           registers A and X are undefined

.fnd
 ldy #0                         \ reset index
.fnd1
 jsr read_buffer                \ read the data at position X
 beq fnd_not_found              \ if the end of data is reached then the string is not found
 cmp (needle),y                 \ compare with needle
 bne fnd                        \ if not equal reset search pointer
 iny
 cpy size
 bne fnd1
 sec
 rts
.fnd_not_found
 clc
 rts
 
\ Check if the string, pointed by X, in the buffer is "OK". 
\ On exit: Z = 1 -> yes, it is "OK"
\          Z = 0 -> no, it is not "OK"
\          A = not modified
\          X = not modified
.test_ok
 pha
 lda pageram,x
 cmp #'O'
 bne test1
 lda pageram+1,x  \\ this goes wrong if x=255 !
 cmp #'K'
.test1
 pla
 rts
  
\ Check if the string, pointed by X, in the buffer is "ERROR" (actually it is a bit lazy, only 
\ checks for the string "ERR" 
\ On exit: Z = 1 -> yes, it is "ERR"
\          Z = 0 -> no, it is not "ERR"
\          A = undefined
\          X = undefined (however, still points to the next position for reading the buffer)
.test_error
 pha
 jsr read_buffer
 cmp #'E'
 bne test1
 jsr read_buffer
 cmp #'R'
 bne test1
 jsr read_buffer
 cmp #'R'
 pla
 rts

\ Search for the next occurence of the newline character (&0A). 
\ On exit:  A is undefined (&0A if found, otherwise unknown) 
\           X points to the next character 
\           Z = 1 if end of buffer is reached
\           Z = 0 if newline is found
.search0a
 jsr read_buffer        \ read character from buffer
 beq search0a_l1        \ jump if end of buffer is reached
 cmp #&0A               \ compare with &0A
 bne search0a           \ it's not, keep searching
 cmp #&0D               \ it is &0A, compare to another value to clear the Z-flag
.search0a_l1     
 rts                    \ return

\ Check if the escape key is pressed. On exit the carry shows the escape status:
\ c = 0: no escape
\ c = 1: escape pressed
\ A, X and Y are preserved
.check_esc
if __ELECTRON__
 bit &FF                \ load escape flag
 bmi esc_pressed        \ acknowledge if pressed
 clc                    \ clear carry for no escape pressed
 rts                    \ return from subroutine
.esc_pressed
 lda #126               \ Acknowledge the escape
 jsr osbyte
 sec                    \ set carry for escape
 rts                    \ return from subroutine
else
 rts    ; not implemented for the Atom, yet
endif

\ Wait for two vertical sync for a short delay
.wait
if __ELECTRON__
 pha
 lda #19
 jsr osbyte
 jsr osbyte
 pla
else
 jsr &FE66
 jsr &FE66
endif
 rts

\ Read a parameter from the command line. The parameter will be stored in 'strbuf'. On exit X indicates
\ whether there was a parameter ( x <> 0 ) or not ( x == 0 )
.read_cli_param             \ Read a parameter from the command line
 ldx #0                     \ Reset pointer for storing the parameter
.read_param_loop
 lda (line),y               \ Read the next character from the command line
 cmp #&0D                   \ Is it end of line?
 beq read_param_end         \ Yes, jump to the end of the routine
 cmp #'"'                   \ is it a double quote?
 beq read_param_quoted      \ Yes, jump for slightly modified routine
 cmp #&20                   \ Is it a space (end of parameter)
 beq read_param_end         \ Yes, jump to the end of the routine
 sta strbuf,x               \ Store in temporary space
 iny                        \ Increment pointer on command line
 inx                        \ Increment storage pointer
 cpx #&FF                   \ Test for end of storage
 bne read_param_loop        \ Go for the next character
.read_param_end
 lda #&0D                   \ Terminate the parameter string
 sta strbuf,x                 
 rts                        \ End of routine

.read_param_quoted
 iny                        \ increment pointer
 lda (line),y               \ read next character
 cmp #&0D                   \ check for end of line
 beq read_param_error       \ jump for error (missing closing quote)
 sta strbuf,x               \ store character in string buffer
 inx                        \ increment storage pointer
 cmp #'"'                   \ check for quote
 bne read_param_quoted      \ if not then jump for next character
 dex                        \ decrement storage pointer
 iny                        \ increment input pointer
 lda (line),y               \ read next character
 cmp #'"'                   \ check for double quote
 bne read_param_end         \ if not double then it was the closing quote, jump to end
 inx                        \ increment input pointer
 bcs read_param_quoted      \ jump for next character

.read_param_error
 ldx #(error_bad_param - error_table)       \ load "parameter error"
 jmp error                  \ throw an error

\ Copy the parameter at 'strbuf' to the parameter block (called heap, because in the original Atom version
\ it was really on the heap). X should be set to zero at the first call.
.copy_to_heap
 sty save_y                 \ save Y register
 ldy #0                     \ reset pointer
.cth1
 lda strbuf,y               \ read parameter
 iny
 sta heap,x                 \ write to heap
 inx                        \ increment heap pointer
 cmp #&0D                   \ test for end of string
 bne cth1                   \ not the end, continue for next character
 ldy save_y                 \ restore Y register
 rts                        \ end subroutine
 
\ Print the WiFi logo
\ If Mode 7 print blue up-arrow, else use user defined character &80 to print logo

scrmode     = &355          \ current screen mode
udcmem      = &C00          \ user defined character memory
alphablue   = &84           \ teletext code for alphanumeric blue characters
uparrow     = &5E           \ teletext up-arrow symbol

if __ELECTRON__
.print_logo
 jsr test_wifi_ena          \ test wifi enabled status
 bne logo2                  \ jump if wifi is disabled
 lda scrmode
 cmp #7                     \ check if mode 7
 bne not_mode7
 lda #alphablue             \ print alpha blue code
 jsr oswrch
 lda #uparrow
 jmp oswrch                 \ printup-arrow and leave
.not_mode7
 ldx #0
.logo_loop1
 lda udcmem,X               \ save current contents of udc memory
 pha
 lda wifi_symbol,X          \ load udc with logo
 sta udcmem,X
 inx
 cpx #8
 bne logo_loop1
 lda #&20                   \ print space
 jsr oswrch
 lda #&80                   \ print logo
 jsr oswrch
 ldx #7
.logo_loop2
 pla                        \ restore udc memory
 sta udcmem,X
 dex
 bpl logo_loop2
.logo2
 rts                        \ end of routine
else
 rts
endif

.wifi_symbol
 equb &3E,&41,&1C,&22,&08,&14,&00,&08

\ Test presense of paged ram
\ This test is destructive for both the ram content and the A register.
\ Returns with Z=0 for ram error.
.test_paged_ram
 lda #&AA                   \ load byte
 sta pageram                \ write to memory
 lda pageram                \ read memory
 cmp #&AA                   \ compare with value
 bne ram_error              \ jump of not equal
 lda #&55                   \ load byte
 sta pageram                \ write to memory
 lda pageram                \ read memory
 cmp #&55                   \ compare with value
.ram_error
 rts                        \ return from subroutine

\ Calculate CRC16
\ Copied from: http://mdfs.net/Info/Comp/Comms/CRC16.htm

.crc_cmd                    \ temporary for development, testing and debugging.
 jsr crc16
 lda crc+1
 jsr printhex
 lda crc
 jsr printhex
 jsr osnewl
 jmp call_claimed
 
 
.crc16
\ Set start address of data
 lda #&00                       :\ Data block starts at &2000
 sta data_pointer
 lda #&20
 sta data_pointer+1
\ Set data length
 lda #&00                       :\ Data length is 16k
 sta datalen
 lda #&40
 sta datalen+1
\ Initialize crc
 lda #&00
 sta crc
 sta crc+1

.bytelp
 LDX #8                         :\ Prepare to rotate CRC 8 bits
 LDA (data_pointer-8 AND &FF,X) :\ Fetch byte from memory

\ The following code updates the CRC with the byte in A ---------+
 EOR crc+1                      :\ EOR byte into CRC top byte    |
.rotlp                          :\                               |
 ASL crc+0:ROL A                :\ Rotate CRC clearing bit 0     |
 BCC clear                      :\ b15 was clear, skip past      |
 TAY                            :\ Hold CRC high byte in Y       |
 LDA crc+0:EOR #&21:STA crc+0   :\ CRC=CRC EOR &1021, XMODEM polynomic
 TYA:EOR #&10                   :\ Get CRC high byte back from Y |
.clear                          :\ b15 was zero                  |
 DEX:BNE rotlp                  :\ Loop for 8 bits               |
 STA crc+1                      :\ Store CRC high byte           |
\ ---------------------------------------------------------------+

 INC data_pointer+0:BNE next:INC data_pointer+1 :\ Step to next byte
.next

\ Now do a 16-bit decrement
 LDA datalen+0:BNE skip             :\ num.lo<>0, not wrapping from 00 to FF
 DEC datalen+1                      :\ Wrapping from 00 to FF, dec. high byte
.skip
 DEC datalen+0:BNE bytelp           :\ Dec. low byte, loop until num.lo=0
 LDA datalen+1:BNE bytelp           :\ Loop until num=0
 RTS

.save_registers                     \ save registers
 sta save_a
 stx save_x
 sty save_y
 rts

.restore_registers                  \ restore registers
 lda save_a
 ldx save_x
 ldy save_y
 rts

\ Calculates  DIVEND / DIVSOR = RESULT	
.div16
 divisor = zp+6                     \ just to make the code more human readable
 dividend = zp                    \ what a coincidence .... this is the address of baudrate
 remainder = zp+2                   \ not necessary, but it's calculated
 result = dividend                  \ more readability

 lda #0	                            \ reset remainder
 sta remainder
 sta remainder+1
 ldx #16	                        \ the number of bits

.div16loop	
 asl dividend	                    \ dividend lb & hb*2, msb to carry
 rol dividend+1	
 rol remainder	                    \ remainder lb & hb * 2 + msb from carry
 rol remainder+1
 lda remainder
 sec                                \ set carry for substraction
 sbc divisor	                    \ substract divisor to see if it fits in
 tay	                            \ lb result -> Y, for we may need it later
 lda remainder+1
 sbc divisor+1
 bcc div16skip	                    \ if carry=0 then divisor didn't fit in yet

 sta remainder+1	                \ else save substraction result as new remainder,
 sty remainder	
 inc result	                        \ and INCrement result cause divisor fit in 1 times

.div16skip
 dex
 bne div16loop	
 rts                                \ do you understand it? I don't ;-)

.wait_a_second                      \ wait a second....
 ldx #50                            \ load counter
.was1
 txa
 pha
 lda #&13
 jsr osbyte
 pla
 tax
 dex                                \ decrement counter
 bne was1                           \ jump if not ready
 rts                                \ return
