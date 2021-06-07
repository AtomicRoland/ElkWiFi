\ TELNET command
\ Syntax:    *TELNET <host>[:port]
\ (c) Roland Leurs, June 2021


.telnet_cmd                 \ start wget command
 lda #PRESTEL               \ set character display mode
 sta telnet_mode            \ 0 = raw, 1 = prestel, 2 = ansi
 \ Start to build a parameter block in strbuf
 ldx #0                     \ init pointer
.telnet_l1
 lda protocols,x            \ load character of protocol (TCP)
 sta strbuf,x               \ store in strbuf
 inx                        \ increment pointer
 cmp #&0D                   \ test for end of string
 bne telnet_l1              \ jump if not end
 jsr skipspace1             \ forward Y pointer to first non-space character
 jsr read_param_loop        \ read host from command line (=read_cli_param but without resetting x)
 cpx #&04                   \ test if host given, x will be > 4
 bne telnet_port            \ continue as the destination host is on the command line
 jsr printtext              \ no destination, print a message
 equs "Usage: TELNET <host> [port]",&0D,&EA
 jmp call_claimed           \ end of command


\ Check is a port (:portnr) was specified
.telnet_port
 stx save_x                 \ save x register
.telnet_l2
 lda strbuf,x               \ load character
 cmp #':'                   \ compare with colon
 beq telnet_l3              \ jump if colon found
 dex                        \ else decrement index
 bpl telnet_l2              \ branch for previous character (we're reading backwards)
 ldx save_x                 \ restore x register
 inx                        \ increment pointer
 lda #'2'                   \ set default port
 sta strbuf,x               \ write to buffer
 inx                        \ increment pointer
 lda #'3'                   \ set default port
 sta strbuf,x               \ write to buffer
 inx                        \ increment pointer
.telnet_l3
 lda #&0D                   \ load string terminator
 sta strbuf,x               \ write to string buffer

.telnet_open_connection
 ldx #>strbuf               \ load address of parameter block
 ldy #<strbuf
 lda #&08                   \ load function number
 jsr wifidriver             \ open TCP connection to host

 ldx #>cipmode1             \ load high byte transfer mode 1
 ldy #<cipmode1             \ load low byte transfer mode 1
 lda #27                    \ load function number
 jsr wifidriver             \ call the driver to enable pass-through transfer mode)
 jsr send_command           \ start pass-through mode
 equs "AT+CIPSEND",&0D,&EA

\ Now we are in telnet mode. The loop will check if a character is
\ received for a short period of time. If there's one received then
\ store it into the paged RAM. If no character is received then
\ have a look at the paged RAM to check if there are characters to
\ print. If so, print them and return to receive routine. If there
\ are no characters to print then check if there is a key pressed and
\ send that key to the host.

.resume_cmd
 ldx #0                     \ initialize paged RAM
 stx pagereg
 stx read_ptr               \ initialize buffer read and write pointers
 stx read_ptr+1
 stx write_ptr
 stx write_ptr+1

.telnet_loop
 jsr read_byte              \ read a byte
 bcc telnet_prt             \ nothing received, branch to print routine
 ldx write_ptr+1            \ set paged RAM register
 stx pagereg
 ldx write_ptr              \ load write pointer
 sta pageram,x              \ write to buffer
 jsr telnet_inc_writeptr    \ increment write pointer
 jmp telnet_loop            \ jump to start of loop

.telnet_prt                 \ check if there's a character to print
 jsr telnet_cmp_ptrs        \ test if pointers are equal
 beq telnet_key             \ pointers are equal, branch to key scan routine
.telnet_pr_chr
 ldx read_ptr+1             \ set paged RAM read pointer
 stx pagereg
 ldx read_ptr               \ load offset
 lda telnet_mode            \ load telnet mode
 cmp #PRESTEL               \ is it prestel mode
 beq telnet_prestel         \ yes, jump to prestel print routine
 cmp #ANSI                  \ is it ansi mode
 bne telnet_print_raw       \ no, then just print the character
 jmp telnet_ansi            \ jump to ansi print routine
 lda pageram,x              \ all others are just printed
.telnet_print_raw
 jsr osasci
.telnet_print_incptr
 jsr telnet_inc_readptr     \ increment buffer read pointer
 jmp telnet_loop            \ jump to start of loop

.telnet_key
 lda #&81                   \ load OSBYTE function call nr to read keyboard buffer
 ldx #0                     \ buffer number for keyboard buffer
 ldy #0                     \ buffer number for keyboard buffer
 jsr osbyte
 cpy #&1B
 beq telnet_end
 bcs telnet_loop            \ jump to start of loop if buffer was empty
 txa                        \ transfer character value to A
 jsr send_byte              \ send to the host
 jmp telnet_loop            \ jump to start of loop

.telnet_end
 lda #&7C
 jsr osbyte
 jsr printtext
 equs "Disconnected",&0D,&EA
 jsr printer3               \ this disables pass through mode and disconnects from server
 jmp call_claimed

.telnet_prestel
 lda pageram,x              \ load the character
 cmp #&0A                   \ test newline character
 beq telnet_print_incptr    \ ignore it
 cmp #&1B                   \ is it an escape character
 bne telnet_print_raw       \ just print it
 jsr telnet_cmp_ptrs        \ is it the last character in the buffer
 beq telnet_loop            \ if so, then leave it for now because we don't have the control code yet
 jsr telnet_inc_readptr     \ else increment buffer read pointer
 inx                        \ increment pointer
 bne telnet_prestel_code    \ jump if no page wrap
 inc pagereg                \ otherwise increment register for next page
.telnet_prestel_code
 lda pageram,x              \ read the control code
 clc                        \ set carry for substraction
 adc #64                    \ sub 65 for the correct control code
 jsr oswrch                 \ print it
 jmp telnet_print_incptr    \ jump to increment read pointer and continue the loop

.telnet_color_tab
 equb 0, 1, 2, 3, 1, 2, 3, 1

.telnet_ansi
 lda pageram,x              \ load the character
 jsr osasci                 \ print it, for now....
 jmp telnet_loop            \ continue the loop


.printvars
 jsr printhex
 lda #' ':jsr oswrch
 lda read_ptr+1 : jsr printhex
 lda read_ptr : jsr printhex
  lda #' ':jsr oswrch
 lda write_ptr+1 : jsr printhex
 lda write_ptr : jsr printhex
 jmp osnewl

.telnet_cmp_ptrs
 lda read_ptr               \ compare read with write pointer
 cmp write_ptr
 bne telnet_cmp_end         \ pointers are not equal, so there's data in the buffer
 lda read_ptr+1
 cmp write_ptr+1
.telnet_cmp_end
 rts

.telnet_inc_readptr
 inc read_ptr
 bne telnet_incr_end
 inc read_ptr+1
.telnet_incr_end
 rts

.telnet_inc_writeptr
 inc write_ptr
 bne telnet_incw_end
 inc write_ptr+1
.telnet_incw_end
 rts

