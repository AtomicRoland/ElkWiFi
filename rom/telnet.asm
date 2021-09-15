\ TELNET command
\ Syntax:    *TELNET <host>[:port]
\ (c) Roland Leurs, June 2021


.telnet_cmd                 \ start wget command
 lda #ANSI                  \ set character display mode
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
 equs "Usage: TELNET <host>[:port]",&0D,&EA
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

 lda telnet_mode            \ test if negotiation is needed
 cmp #ANSI                  \ we only negotiate on ANSI connections
 bne resume_cmd             \ jump if not ANSI mode

 jsr telnet_ansi_neg        \ do negotiation
 
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
 stx quelen                 \ initialize queue length

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
 lda telnet_mode            \ load telnet mode
 cmp #PRESTEL               \ is it prestel mode
 beq telnet_prestel         \ yes, jump to prestel print routine
 cmp #ANSI                  \ is it ansi mode
 bne telnet_print_raw       \ no, then just print the character
 jmp telnet_ansi            \ jump to ansi print routine
 jsr telnet_read_char       \ all others are just printed, read the character to print
.telnet_print_raw
 jsr osasci
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
 equs "Disconnecting",&EA
 jsr printer3               \ this disables pass through mode and disconnects from server
 jsr printtext
 equb &7F,&7F,&7F,'e','d',&0D,&EA
 jmp call_claimed

.telnet_prestel
 jsr telnet_read_char       \ load the character
 cmp #&0A                   \ test newline character
 beq telnet_loop            \ ignore it
 cmp #&1B                   \ is it an escape character
 beq telnet_set_quelen      \ yes, then set the queue length
 ldx quelen                 \ test if we're in an escape sequence
 beq telnet_print_raw       \ no, jump to print the character
 ldx #0                     \ clear queue length
 stx quelen
 clc                        \ we're in an escape sequence, clear carry for addition
 adc #64                    \ add 64 for the correct control code
 bne telnet_print_raw       \ print the control character

.telnet_set_quelen
 ldx #1                     \ yes, it's an escape character, set queue length
 stx quelen
 jmp telnet_loop            \ restart loop


.telnet_color_tab
 equb 0, 1, 2, 3, 1, 2, 3, 1

.telnet_ansi
 lda pageram,x              \ load the character
 jsr osasci                 \ print it, for now....
 jmp telnet_loop            \ continue the loop


.printvars
 lda quelen
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

.telnet_read_char
 ldx read_ptr+1             \ set paged RAM read pointer
 stx pagereg
 ldx read_ptr               \ load offset
 lda pageram,x
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

.telnet_ansi_neg
 jsr wait_a_second
 ldx #0
.telnet_ansi_neg_l1
 lda optiontab,x
 jsr send_byte
 inx
 cpx #(optiontabend-optiontab)
 bne telnet_ansi_neg_l1
 rts

\ Pretent to be an Apple OS X client ;-)
.optiontab
equb &ff,&fa,&1f,&00,&b5,&00,&3e,&ff,&f0,&ff,&fa,&20  
equb &00,&39,&36,&30,&30,&2c,&39,&36,&30,&30,&ff,&f0,&ff,&fc,&23,&ff  \ .9600,9600....#.
equb &fa,&27,&00,&00,&44,&49,&53,&50,&4c,&41,&59,&01,&2f,&70,&72,&69  \ .'..DISPLAY./pri
equb &76,&61,&74,&65,&2f,&74,&6d,&70,&2f,&63,&6f,&6d,&2e,&61,&70,&70  \ vate/tmp/com.app
equb &6c,&65,&2e,&6c,&61,&75,&6e,&63,&68,&64,&2e,&57,&41,&6b,&51,&4d  \ le.launchd.WAkQM
equb &73,&4e,&33,&4e,&37,&2f,&6f,&72,&67,&2e,&6d,&61,&63,&6f,&73,&66  \ sN3N7/org.macosf
equb &6f,&72,&67,&65,&2e,&78,&71,&75,&61,&72,&74,&7a,&3a,&30,&00,&55  \ orge.xquartz:0.U
equb &53,&45,&52,&01,&72,&6f,&6c,&61,&6e,&64,&ff,&f0,&ff,&fa,&18,&00  \ SER.roland......
equb &58,&54,&45,&52,&4d,&2d,&32,&35,&36,&43,&4f,&4c,&4f,&52,&ff,&f0  \ XTERM-256COLOR..
.optiontabend