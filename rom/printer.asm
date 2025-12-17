\ Elk WiFi printer driver
\ This printer driver supports two types of printer:
\ - serial printer
\ - network printer to Linux host

 printer_ID = 6             \ our internal printer ID

.printer_cmd                \ set User Print Vector to ROM
 jsr skipspace1             \ read first character on command line
 jsr read_cli_param         \ read first parameter from command line
 cpx #&00                   \ test if any parameter given, x will be > 0
 beq printer_help           \ continue if there are no parameters

 lda strbuf                 \ read first character of the parameter
 and #&DF                   \ convert to upper case
 cmp #'S'                   \ compare with S (serial)
 beq printer_serial         \ initialize serial printer
 cmp #'T'                   \ compare with T (tcp)
 beq printer_network        \ initialize network printer
 cmp #'N'                   \ compare with N (network), same as T
 beq printer_network        \ initialize network printer
 cmp #'O'                   \ compare with O (off)
 beq printer_off
.printer_bad_param
 ldx #(error_bad_option-error_table)
 jmp error                  \ unrecognized option, throw an error


.printer_help               
 jsr printer_syntax         \ printer syntax
 jmp printer_end

.printer_serial
 jsr printer_set_vectors    \ set printer vectors
 jsr printer_serial_setup   \ setup serial printer
 jmp printer_end

.printer_network
 jsr printer_set_vectors    \ set printer vectors
 jsr printer_network_setup  \ setup network printer
 jmp printer_end

.printer_off
 sei                        \ disable interrupts
 lda uptsav                 \ load old vector
 sta uptvec                 \ restore it
 lda uptsav+1
 sta uptsav
 cli                        \ enable interrupts
 lda #0
 sta uptype

.printer_end
 jmp call_claimed           \ that's it, for now....                   


.printer_set_vectors
 lda uptype                 \ check if printer driver already actived is
 bne printer_skip_vectors

 lda uptvec                 \ save original vector address
 sta uptsav
 lda uptvec+1
 sta uptsav+1

 \ Get extended vector address
 lda #&A8                   \ load OSBYTE entry parameters
 ldx #&00
 ldy #&FF
 jsr osbyte                 \ do osbyte call
 stx zp                     \ store extended vector address space
 sty zp+1
 txa                        \ transfer low byte to A
 clc                        \ clear carry for addition
 adc #(17*3)                \ uptvec is the 17th vector
 sta zp                     \ store in zero page
 lda zp+1                   \ load high byte
 adc #0                     \ add the carry
 sta zp+1                   \ write back to zero page. 

 \ Now write the new vector, pointing to this ROM
 sei                        \ disable interrupts
 ldy #0                     \ clear index
 lda #<uptvector            \ load low byte
 sta (zp),y                 \ write to vector
 iny                        \ increment pointer
 lda #>uptvector            \ load high byte
 sta (zp),y                 \ write to vector
 iny                        \ increment pointer
 lda shadow                 \ load current ROM bank number
 sta (zp),y                 \ write to vector

 \ Now set the uptvec to the extended print vector in MOS
 lda #(17*3)                \ uptvec is the 17th vector
 sta uptvec                 
 lda #&FF
 sta uptvec+1
 cli                        \ enable interrupts
.printer_skip_vectors
 rts

.uptvector                  \ the new vector
 cpy #printer_ID            \ compare with our printer ID
 bne uptvector_end1         \ jump if it's not our printer
 jsr save_registers         \ save registers

 asl a                      \ multiply A by 2
 tax                        \ transfer to X register
 lda uptvectab,x            \ load low byte of function
 sta zp                     \ store in zero page
 lda uptvectab+1,x          \ load high byte of function
 sta zp+1                   \ store in zero page
 ldx save_x                 \ restore x register 
 jsr printerfunction        \ execute the printer function

.uptvector_end
 jsr restore_registers      \ restore registers
.uptvector_end1
 jmp (uptsav)               \ jump to the old vector

.printerfunction
 jmp (zp)                   \ jump to the specified function
 
.osremv
 jmp (&022C)                \ jump indirect to buffer remove vector

.uptvectab
 equb <printer0, >printer0
 equb <printer1, >printer1
 equb <printer2, >printer2
 equb <printer3, >printer3
 equb <printer4, >printer4
 equb <printer5, >printer5

.cipmode0   equb '0',&0D
.cipmode1   equb '1',&0D

.printer0                   \ fetch character from buffer and print it
 clv                        \ clear overflow flag (we want to pull a byte from the buffer)
 jsr osremv                 \ read byte from the printer buffer
 bcs printer0_sleep         \ the buffer is empty, put printer driver to sleep
 tya                        \ transfer character to A
 jsr send_to_printer        \ print its value
 jmp printer0               \ make printer buffer empty (fast printing this way :-)
 
.printer0_sleep
 lda #&7B                   \ load OSBYTE call number
 jmp osbyte                 \ put printer driver to sleep and return

.printer1                   \ activate printer
 clv                        \ clear overflow flag
 jsr osremv                 \ read character from printer buffer
 bcs printer1_end           \ jump if there is no character
 jsr send_to_printer        \ send character to printer
 clc                        \ clear carry to set printer driver active
.printer1_end
 rts                        \ return
 

.printer2                   \ vdu 2 received: connect to printer
 ldx #>netprt               \ load high byte printer address into X
 ldy #<netprt               \ load low byte printer address into Y
 lda #&08                   \ load function number
 jsr wifidriver             \ open TCP connection to printer
 ldx #>cipmode1             \ load high byte transfer mode 1
 ldy #<cipmode1             \ load low byte transfer mode 1
 lda #27                    \ load function number
 jsr wifidriver             \ call the driver to start pass-through transfer mode)
 jsr send_command
 equs "AT+CIPSEND",&0D,&EA
 rts                        \ end routine

.printer3                   \ vdu 3 received, stop printing
 jsr wait_a_second          \ if it does not wait, the +++ for ending pass-through is not correctly processed (?)
 lda #'+'                   \ send three plus signs to end pass-through mode
 jsr send_byte
 jsr send_byte
 jsr send_byte
 jsr wait_a_second          \ guess what it does now....?

 ldx #>cipmode0             \ load high byte transfer mode 0
 ldy #<cipmode0             \ load low byte transfer mode 0
 lda #27                    \ load function number
 jsr wifidriver             \ call the driver to restore normal transfer mode
 lda #14                    \ load function number
 jsr wifidriver             \ disconnect the printer
.printer4                   \ not specified, ignored
 rts                        \ end of routine
 
.printer5                   \ printer change, enables line feed to be send to printer
 ldx #255                   \ load character ignored by printer
 lda #6                     \ load osbyte function number
 jsr osbyte
 rts

.send_to_printer
 pha                        \ save byte to print
 lda uptype                 \ load printer type
 cmp #1                     \ is it a serial printer
 beq send_serial_printer    \ yes, then send it to the serial printer
 cmp #2                     \ is it a network printer
 beq send_network_printer   \ yes, then send it to the network printer
 pla                        \ otherwise just ignore it
 rts

.send_serial_printer
 pla                        \ restore data
 sta &FC38                  \ write to serial port
 rts

.send_network_printer
 pla
 jsr send_byte              \ send to printer
 rts                        \ it's not more than that :-)

.printer_serial_setup
 lda #1                     \ load printer type serial
 sta uptype                 \ store in memory
 ldx #1                     \ set pointer to strbuf (first character was the 'S')
 lda strbuf,x               \ load character
 cmp #':'                   \ check for colon
 bne printer_syntax         \ jump if no colon 
 jsr parse_serial_params    \ read the serial settings
 jsr serial_setup_a         \ set up port A of the uart
 rts

.printer_network_setup
 lda #2                     \ load printer type serial
 sta uptype                 \ store in memory
 ldx #1                     \ set pointer to strbuf (first character was the 'N')
 lda strbuf,x               \ load character
 cmp #':'                   \ check for colon
 bne printer_syntax         \ jump if no colon 
 jsr parse_net_params       \ read the IP settings
 rts

.printer_syntax 
 jsr printtext
 equs "Syntax: *PRINTER S:baud,par,data,stop",&0D
 equs "        *PRINTER N:hostname",&0D
 equs "        *PRINTER OFF",&0D,&EA
 rts

.bad_option_error
 ldx #(error_bad_param-error_table)
 jmp error

\ The next routine parses the command line and places the values to ZP and up
\ Syntax: baudrate (integer), parity (O,E,N,1,0) ,databits (7 or 8), stopbits (1 or 2)
\ any fault in one of these parameters will throw a "bad parameter" error
.parse_serial_params
 inx                        \ increment pointer to strbuf
 lda #0                     \ reset baud rate
 sta baudrate
 sta baudrate+1
 sta baudrate+2
.parse_baudrate
 lda strbuf,x               \ load character
 inx                        \ increment pointer
 beq bad_option_error       \ way too long parameter, error
 cmp #','                   \ test for end of baudrate
 beq parse_parity           \ jump if comma found
 cmp #&0D                   \ test for end of parameters
 beq printer_syntax         \ print syntax
 sec                        \ set carry for substraction
 sbc #'0'                   \ substract &30
 bmi bad_option_error       \ jump if negative
 cmp #10                    \ test for 9, looks silly doesn't it?
 bpl bad_option_error       \ jmp if larger than 9       
 jsr mul10                  \ multiply by 10 and add A to baudrate 
 jmp parse_baudrate         \ go for the next digit

.parse_parity
 lda strbuf,x               \ load character
 cmp #'O'                   \ test for 'O'
 beq parse_parity_odd
 cmp #'E'                   \ test for 'E'
 beq parse_parity_even
 cmp #'N'                   \ test for 'N'
 beq parse_parity_none
 cmp #'1'                   \ test for '1'
 beq parse_parity_mark 
 cmp #'0'                   \ test for '0'
 beq parse_parity_space
 jmp bad_option_error       \ none of these options, so it's a bad parameter

.parse_parity_none           
 lda #0                     \ load parity value
 beq parse_parity_set       \ jump always

.parse_parity_even
 lda #&18                   \ load parity value
 bne parse_parity_set       \ jump always

.parse_parity_odd
 lda #&08                   \ load parity value
 bne parse_parity_set       \ jump always

.parse_parity_mark
 lda #&28                   \ load parity value
 bne parse_parity_set       \ jump always

.parse_parity_space
 lda #&38                   \ load parity value
 bne parse_parity_set       \ jump always   (????)

.parse_parity_set
 sta parity                 \ set parity value
 inx                        \ increment pointer to strbuf
 lda strbuf,x               \ load next character
 cmp #','                   \ it must be a comma
 beq parse_databits         \ go and parse the word length
.parse_parity_error
 jmp bad_option_error       \ else throw an error

.parse_databits
 inx                        \ increment pointer to strbuf
 lda strbuf,x               \ load next character
 cmp #'5'                   \ compare to '5'
 bmi parse_parity_error     \ jump if smaller
 cmp #'9'                   \ compare to '8'
 bpl parse_parity_error     \ jump if larger
 sec                        \ set carry for subtraction
 sbc #'5'                   \ substract '5'
 sta databits               \ store the result
 inx                        \ increment pointer to strbuf
 lda strbuf,x               \ load next character
 cmp #','                   \ it must be a comma
 bne parse_parity_error     \ if not then throw an error

.parse_stopbits
 inx                        \ increment pointer to strbuf
 lda strbuf,x               \ load character
 cmp #'1'                   \ test for '1'
 beq parse_set_stopbit 
 cmp #'2'                   \ test for '2'
 beq parse_set_stopbit
 jmp bad_option_error       \ none of these options, so it's a bad parameter

.parse_set_stopbit
 and #&02                   \ just interested in bit 1
 asl a                      \ shift bit 1 into bit 2
 sta stopbits               \ set stop bits

 inx                        \ increment pointer to strbuf
 lda strbuf,x               \ load character
 cmp #&0D                   \ this should be the end of the string
 beq parse_end
 jmp bad_option_error       \ else throw an error

.parse_end
 rts                        \ return

.setserial_cmd              \ serial port A setup
 jsr skipspace1             \ read first character on command line
 jsr read_cli_param         \ read first parameter from command line
 cpx #0                     \ test if any parameters
 bne setserial_l1
 jsr printtext              \ print syntax:
 equb "Syntax: *SETSERIAL baud,par,data,stop",&0D, &EA
 rts
.setserial_l1
 ldx #&FF                   \ load pointer to strbuf
 jsr parse_serial_params    \ read serial parameters
 jsr serial_setup_a         \ setup serial port
 jmp call_claimed           \ end of command

.parse_net_params
 inx                        \ increment X (still pointing to the colon)
 ldy #0                     \ reset index
.parse_net_0
 lda protocols,y            \ load character from protocol (defined in wget.asm)
 sta netprt,y               \ store in workspace
 iny                        \ increment index
 cmp #&0D                   \ test for end of protol
 bne parse_net_0            \ jump if more characters follow
.parse_net_1
 lda strbuf,x               \ load next character
 sta netprt,y               \ store in workspace
 inx                        \ increment pointers
 beq parse_net_3            \ if no more characters then throw error
 iny
 cpy #32                    \ maximum length
 beq parse_net_3            \ if maximum then throw error
 cmp #' '                   \ test for space
 beq parse_net_2            \ consider a space as the last character
 cmp #&0D                   \ test for end of line
 bne parse_net_1            \ if not then go for next character
.parse_net_2 
 lda #&0D                   \ load string terminator
 sta netprt-1,y             \ close string (just in case the terminator was a space)
 lda #'9'                   \ store port number (9100) in workspace
 sta netprt,y
 iny
 lda #'1'
 sta netprt,y
 iny
 lda #'0'
 sta netprt,y
 iny
 sta netprt,y
 iny
 lda #&0D
 sta netprt,y
 rts                        \ return
.parse_net_3
 jmp bad_option_error       \ go to error routine
