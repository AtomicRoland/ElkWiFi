\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Get ESP8266 firmware version
\ Version 1.00

\ Syntax:       *PING <hostname or IP>

.ping_cmd
 jsr skipspace1             \ forward Y pointer to first non-space character
 jsr read_cli_param         \ read host from command line
 cpx #&00                   \ test if host given, x will be > 0
 bne ping_start             \ continue as the destination host is on the command line
 jsr printtext              \ no destination, print a message
 equs "Usage: *PING <hostname or IP>",&0D,&EA
 jmp call_claimed           \ end of command

.ping_start
 ldx #5                     \ Number of pings to do
 stx size                   \ store in workspace
 ldx #32                    \ quite long time out
 stx time_out    
.ping_loop
 ldx #>strbuf               \ load pointer to hostname or IP
 ldy #<strbuf
 lda #28                    \ load driver function number for PING
 jsr wifidriver             \ do the ping

 \ Process the response
 jsr set_bank_0
 jsr reset_buffer
 lda pageram                \ load the first character of the response
 cmp #'+'                   \ is it a plus sign?
 bne ping_error             \ no, then jump for error (dns or network failure)
 lda pageram+1              \ load first character of response time
 cmp #'t'                   \ if is a 't' (timeout)
 beq ping_time_out          \ jump for timeout
 jsr printtext              \ print message
 equs "Received response in ",&EA
 ldy #1                     \ load pointer
.ping_print_ms
 lda pageram,y              \ load character
 cmp #&0D                   \ test for end of string
 beq ping_ms                \ jump if end
 sta save_y                 \ save the pointer
 jsr oswrch                 \ print it
 lda save_y                 \ restore the pointer
 iny                        \ increment pointer
 bpl ping_print_ms          \ go for next character
.ping_ms
 jsr printtext              \ print text
 equs " ms",&0D,&EA
.ping_wait
 ldx #50                    \ wait a second
 stx zp                     \ store in workspace
.ping_wait_loop
 lda #19                    \ load osbyte call number for fly back
 jsr osbyte
 dec zp                     \ decrement counter
 bne ping_wait_loop

 dec size                   \ decrement counter
 bne ping_loop              \ go for the next if not all done
 jmp call_claimed           \ end of command

.ping_error
 jsr printtext              \ print error message
 equs "Host error (dns or network)",&0D,&EA
 jmp ping_wait

.ping_time_out
 jsr printtext              \ pring timeout message
 equs "No response received from host",&0D,&EA
 jmp ping_wait
