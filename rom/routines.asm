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
.call_claimed       pla                     \ restore x and y
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
 
\ Print the Acorn Electron logo
if __ELECTRON__
.print_logo
 ldx #7                     \ load index for copy
.logo1
 lda wifi_symbol,x          \ load data
 sta &60A0,x                \ write to screen
 dex                        \ decrement index
 bpl logo1                  \ jump if bytes follow
 lda #7                     \ sound beep
 jmp oswrch                 \ end of routine
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
