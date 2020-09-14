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
 sta save_a                 \ save registers
 stx save_x
 sty save_y

 asl a                      \ multiply A by 2
 tax                        \ transfer to X register
 lda uptvectab,x            \ load low byte of function
 sta zp                     \ store in zero page
 lda uptvectab+1,x          \ load high byte of function
 sta zp+1                   \ store in zero page
 ldx save_x                 \ restore x register 
 jsr printerfunction        \ execute the printer function

.uptvector_end
 ldy save_y                 \ restore registers
 ldx save_x
 lda save_a
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

.printer0                   \ fetch character from buffer and print it
 clv                        \ clear overflow flag (we want to pull a byte from the buffer)
 jsr osremv                 \ read byte from the printer buffer
 bcs printer0_sleep         \ the buffer is empty, put printer driver to sleep
 tya                        \ transfer character to A
 jsr send_to_printer        \ print its value
 rts                        \ return 
 
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
 

.printer2                   \ vdu 2 received, ignored

.printer3                   \ vdu 3 received, ignored

.printer4                   \ not specified, ignored
 
.printer5                   \ printer change, ignored (for now)
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
 rts                        \ not implemented yet

.printer_serial_setup
 lda #1                     \ load printer type serial
 sta uptype                 \ store in memory
 rts

.printer_network_setup
 lda #2                     \ load printer type serial
 sta uptype                 \ store in memory
 rts

.printer_syntax 
 jsr printtext
 equs "Syntax: *PRINTER S:baud,par,data,stop",&0D
 equs "        *PRINTER N:hostname,port",&0D
 equs "        *PRINTER OFF",&0D,&EA
 rts

