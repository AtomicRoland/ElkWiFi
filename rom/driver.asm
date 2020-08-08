\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Main service ROM
\ Version 1.00

\ Please note that some functions or routines are not quite logical
\ but they are implemented to keep driver compatibility with the 
\ Atom wifi driver.

.wifidriver
 \ entries are.
 \ 00 init                12 cipstatus
 \ 01 reset               13 cipsend
 \ 02 gmr                 14 cipclose
 \ 03 cwlap               15 cipserver
 \ 04 cwjap               16 cipsto
 \ 05 cwqap               17 ciobaud
 \ 06 cwsap               18 cifsr
 \ 07 cwmode              19 ciupdate
 \ 08 cipstart            20 ipd
 \ 09 cpmux               21 csyswdtenable
 \ 10 cwlif               22 csyswdtdisable
 \ 11 setbuffer           23 getmuxchannel
 \ 24 disable/enable
 \ 25 cwlapopt
 \ 26 sslbufsize



 sta save_a                 \ save registers
 stx save_x
 sty save_y
 cmp #24                    \ check for enable/disable command
 beq wifi_init_uart         \ this is always allowed
 cmp #&FF
 beq drivertest
 jsr test_wifi_ena          \ test is wifi is enables (in serial.asm)
 beq wifi_init_uart         \ jump if wifi is enabled
 ldx #(error_disabled-error_table)
 jmp error                  \ throw page ram error
.wifi_init_uart
 jsr init_uart              \ initialize the uart
 jsr send_command           \ send ECHO OFF to ESP device
 equs "ATE0",&0D
 jsr read_response          \ wait for echo off to complete
 jsr test_paged_ram         \ check for paged ram
 beq ram_ok                 \ jump if ram found
 ldx #(error_no_pagedram-error_table)
 jmp error                  \ throw page ram error
.ram_ok
 jsr clear_buffer           \ initialize the receive buffer in paged ram
 lda save_a                 \ load driver function number
 cmp #&FF                   \ driver test call
 beq drivertest
 and #&1F                   \ calculate jump address
 asl a
 tax
 lda entry_table,x
 sta zp
 lda entry_table+1,x
 sta zp+1
 jmp (zp)                   \ execute driver function
 
.drivertest
 jsr printtext
 equs "Wifi driver test call",&0D
 equs "Registers: ", &EA
 lda save_a
 jsr printhex
 lda #' '
 jsr oswrch
 lda save_x
 jsr printhex
 lda #' '
 jsr oswrch
 lda save_y
 jsr printhex
 lda #' '
 jsr oswrch
 jmp osnewl

.entry_table
 equw init
 equw reset
 equw gmr
 equw cwlap
 equw cwjap
 equw cwqap
 equw cwsap
 equw cwmode
 equw cipstart
 equw cipmux
 equw cwlif
 equw set_buffer
 equw cipstatus
 equw cipsend
 equw cipclose
 equw cipserver
 equw cipsto
 equw ciobaud
 equw cifsr
 equw ciupdate
 equw ipd
 equw csyswdtenable
 equw csyswdtdisable
 equw mux_get_channel
 equw disable_enable
 equw cwlapopt
 equw sslbufsize
 equw reserved
 equw reserved
 equw reserved
 equw reserved
 equw reserved
 equw reserved
 
 \ send a byte to the wifi controller
 \ when terminated with &00 then don't finish command
 \ when terminated with &0D then finish with &0A code
.send_command
 pla
 sta zp
 pla
 sta zp+1
.sc0
 ldy #0
 inc zp
 bne sc1
 inc zp+1
.sc1
 lda (zp),y
 beq sc3
 jsr send_byte
 cmp #13
 bne sc0
.sc2
 lda #10
 jsr send_byte
.sc3
 inc zp
 bne sc4
 inc zp+1
.sc4
 jmp (zp)

 
.read_response
; just for debugging and emulation in BeebEm
; jsr printtext
; equs "Reading answer from ESP",&0D
; nop
; rts
 jsr uart_read_response
 jmp restore_env
 
.init \ init serial port and esp device
 jsr send_command
 equs "AT+RST",&0D
 jmp read_response
 
.reset \ reset esp8266
 jsr uart_hw_reset
 jmp read_response
 
.gmr \ get firmware version
 jsr send_command
 equs "AT+GMR",&0D
 jmp read_response
 
.cwlap \ list access points
 jsr send_command
 equs "AT+CWLAP",&0D
 jmp read_response

 \ Set options for CWLAP. In this driver version only two fixed options are available:
 \ x = 127 -> show all fields
 \ x = 7 -> only show encryption type, ssid and signal strenght
 \ Always sort by strongest signal
 \ Todo: make x variable and add y option for order
.cwlapopt                   \ options for list access points
 jsr send_command
 equs "AT+CWLAPOPT=1,",&00
 jsr send_param
 jsr send_crlf
 jmp read_response
  
.cwjap \ join access point
 \ x = hi byte param block, y=low byte param block
 jsr send_command
 equs "AT+CWJAP",&00
 ldy #0
 lda (paramblok),y
 beq cwjap_query
 lda #'='
 jsr send_byte
 jsr send_param_quoted
 lda #','
 jsr send_byte
 jsr send_param_quoted
 jmp cwjap_query_l1
.cwjap_query
 lda #'?'
 jsr send_byte
.cwjap_query_l1
 jsr send_crlf
 jmp read_response
 
.cwqap \ quit access point
 jsr send_command
 equs "AT+CWQAP",&0D
 jmp read_response
 
.cwsap \ set parameters of access point
.cifsr \ get ip address
 jsr send_command
 equs "AT+CIFSR",&0D
 jmp read_response
 
.cwmode \ wifi mode
 jsr send_command
 equs "AT+CWMODE",&00
 ldy #0
 lda (paramblok),y
 beq cwjap_query
 lda #'='
 jsr send_byte
 bne last_param
 
.cipstart \ set up tcp or udp connection
 \ x = hi byte param block, y=low byte param block
 jsr send_command
 equs "AT+CIPSTART",&00
 ldy #0
 lda (paramblok),y
 beq cwjap_query
 lda #'='
 jsr send_byte
 lda mux_status
 beq cipstart_connect
 jsr send_param
 lda #','
 jsr send_byte
.cipstart_connect
 jsr send_param_quoted
 lda #','
 jsr send_byte
 jsr send_param_quoted 
 lda #','
 jsr send_byte
.last_param
 jsr send_param
 jsr send_crlf
 jmp read_response
 
.cipmux \ tcp/udp connections
 jsr cipmux_close_all
 jsr send_command
 equs "AT+CIPMUX",&00
 ldy #0
 lda (paramblok),y
 bne cipmux1
 jmp cwjap_query
.cipmux1
 and #&01
 sta mux_status
 lda #'='
 jsr send_byte
 jmp last_param
 
.cipmux_close_all
 pha
 ldx #4
.cipmux_close_l1
 jsr send_command
 equs "AT+CIPCLOSE=",&00
 txa
 clc
 adc #'0'
 jsr send_byte
 jsr send_crlf
 lda #&00
 sta mux_channel,x
 dex
 bpl cipmux_close_l1
 pla
 rts
 
.mux_get_channel
 lda #&00
 sta error_nr
 jsr restore_env
 lda mux_status
 beq no_mux
 ldy #4
.mux_get_loop
 lda mux_channel,y
 beq av_channel
 dey
 bpl mux_get_loop
 sec
 rts
.no_mux
 ldy #&ff
 clc
 rts
.av_channel
 lda #&2a
 sta mux_channel,y
 sec
 rts
 
.cwlif \ check joined devices ip
.cipstatus \ tcp/ip connection status
 jsr send_command
 equs "AT+CIPSTATUS",&0D
 jmp read_response
 
.cipsend \ send tcp/ip data
 ldx save_x
 \ x points to zero page address with control block.
 \ two bytes start address of data
 \ two bytes length
 lda &0000,x
 sta data_pointer
 lda &0001,x
 sta data_pointer+1
 lda &0002,x
 sta data_counter
 lda &0003,x
 sta data_counter+1
 lda &0004,x
 sta data_counter+2
 jsr send_command
 equs "AT+CIPSEND=",&00
 jsr prdec24
 lda #&0D
 jsr send_byte
 lda #&0A
 jsr send_byte
 jsr wait
.send_mem_buffer
 ldy #0
.smb1
 lda (data_pointer),y
 jsr send_byte
 inc data_pointer
 bne smb2
 inc data_pointer+1
 .smb2
 jsr dec_data_counter
 bne smb1
 jmp read_response
 
.cipclose \ close tcp/ip connection
 jsr send_command
 equs "AT+CIPCLOSE",&00
 lda mux_status
 bne close_channel
 jsr send_crlf
 jmp read_response
.close_channel
 ldy #0
 lda (paramblok),y
 sec
 sbc #'0'
 tax
 lda #0
 sta mux_channel,x
 lda #'='
 jsr send_byte
 jmp last_param
 
.cipserver \set as server
.cipsto \ set the server time out
.ciobaud \ set baud rate
 jsr send_command
 equs "AT+CIOBAUD?",&0D
 jmp read_response
 
.ciupdate \ firmware update from cloud
 jmp not_implemented
.ipd \ received data
 jsr send_command
 equs "ipd,",&0D,&0A
 jmp read_response
 
.csyswdtenable \ enable watchdog timer
 jsr send_command
 equs "AT+CSYSWDTENABLE",&0D
 jmp read_response
 
.csyswdtdisable \ disable watchdog timer
 jsr send_command
 equs "AT+CSYSWDTDISABLE",&0D
 jmp read_response

.reserved
.not_implemented
 lda nomon
 bne error2
 ldx #(error_not_implemented-error_table)
 jmp error
.error2
 lda #2
 sta error_nr
 rts
 
.buffer_full
 lda nomon
 bne error4
 ldx #(error_buffer_full-error_table)
 jmp error
.error4
 lda #4
 sta error_nr
 rts
 

\ Initialize the data buffer, by resetting the paged ram register to 0. This
\ call does not clear the buffer and will mostly be called after a command
\ is executed and the response is processed.
.reset_buffer
 ldx #&00
 stx pagereg
 rts

\ Initialize the data buffer, by resetting the paged ram register to 0
\ and clearing the first page. After a command is executed and if the first
\ byte is 0 then there was no response from the ESP8266. This call is intended
\ before a command is executed.
.clear_buffer
 jsr reset_buffer
 txa
.irb_l1
 sta pageram,x
 inx
 bne irb_l1
 rts

\ Reads a character from the paged ram buffer at position X
\ returns the character in A and the X register points 
\ to the next data byte.
.read_buffer
 lda pageram,x
 php
.read_buffer_inc
 inx
 bne read_buffer_end
 jsr inc_page_reg
.read_buffer_end
 plp
 rts

\ Writes a character to the paged ram buffer at position X
\ returns with X pointing to the next byte
.write_buffer
 php
 sta pageram,x
 jmp read_buffer_inc

\ Sends a CRLF to the ESP8266
.send_crlf
 lda #&0D
 jsr send_byte
 lda #&0A
 jmp send_byte
 
\ Sends a parameter surrounded with quotes to the ESP8266. It first sends
\ a quote character, followed by the parameter (e.g. protocol or address) and
\ terminates with another quote character.
.send_param_quoted
 lda #'"'
 jsr send_byte
 jsr send_param
 lda #'"'
 jmp send_byte
 
\ Sends a parameter string to the ESP8266. De parameter address is stored in the
\ address paramblok with an offset of Y.
.send_param
 lda (paramblok),y
 beq end_param
 cmp #&0D
 beq end_param
 jsr send_byte
 iny
 bne send_param
.end_param
 iny
 rts
 
\ Decrements the 24 bit data pointer. On the Electron most transfers will be smaller than
\ 64 KB but it is possible to send up to 4 MB per transfer.
.dec_data_counter
 sec
 lda data_counter
 sbc #1
 sta data_counter
 lda data_counter+1
 sbc #0
 sta data_counter+1
 lda data_counter+2
 sbc #0
 sta data_counter+2
 ora data_counter+1
 ora data_counter
 rts
 
 \ print hex value in ascii digits
 \ code from mdfs.net - j.g.harston
.prdec24
 lda data_counter+0
 pha
 lda data_counter+1
 pha
 lda data_counter+2
 pha
 ldy #21
 lda #0
 sta pr24pad
.prdec24lp1
 ldx #&ff
 sec
.prdec24lp2
 lda data_counter+0
 sbc prdec24tens+0,y
 sta data_counter+0
 lda data_counter+1
 sbc prdec24tens+1,y
 sta data_counter+1
 lda data_counter+2
 sbc prdec24tens+2,y
 sta data_counter+2
 inx
 bcs prdec24lp2
 lda data_counter+0
 adc prdec24tens+0,y
 sta data_counter+0
 lda data_counter+1
 adc prdec24tens+1,y
 sta data_counter+1
 lda data_counter+2
 adc prdec24tens+2,y
 sta data_counter+2
 txa
 bne prdec24digit
 lda pr24pad
 bne prdec24print
 beq prdec24next
.prdec24digit
 ldx #'0'
 stx pr24pad
 ora #'0'
 .prdec24print
 jsr send_byte
 .prdec24next
 dey
 dey
 dey
 bpl prdec24lp1
 pla
 sta data_counter+2
 pla
 sta data_counter+1
 pla
 sta data_counter+0
 rts
.prdec24tens
   EQUW 1       :EQUB 1 DIV 65536
   EQUW 10      :EQUB 10 DIV 65536
   EQUW 100     :EQUB 100 DIV 65536
   EQUW 1000    :EQUB 1000 DIV 65536
   EQUW 10000   :EQUB 10000 DIV 65536
   EQUW 100000 MOD 65535    :EQUB 100000 DIV 65536
   EQUW 1000000 MOD 65535   :EQUB 1000000 DIV 65536
   EQUW 10000000 MOD 65535  :EQUB 10000000 DIV 65536

 \ test if buffer empty
 \ on return. zero flag = 0 -> buffer not empty
 \            zero flag = 1 -> buffer empty

 \ TODO: how is this managed with paged ram????

\.fetch_buffer_status
\ lda store_vec
\ cmp #store_sam%256
\ beq gbs_sam
\ lda #0
\ cmp buffer_ptr
\ bne gbs_full
\ lda buffer_start
\ cmp buffer_ptr+1
\ bne gbs_full
\ lda #0
\ rts
\.gbs_full
\ lda #&80
\ rts
\.gbs_sam
\ lda sam_status
\ eor #&ff
\ and #&80
\ rts
   
\ The following functions are not needed on the Electron
.restore_env
.set_buffer
 stx datalen            \ save end of data
 ldx pagereg      
 stx datalen+1
 ldx datalen            \ restore x register
rts

\ Increments the paged ram register and sets the (X) pointer to the beginning of the page. 
\ If the end of paged ram has been reached then the page register will roll over from &FF
\ to &00 and the Z flag is set. The pageregister and X will not be updated and the routine
\ returns with Z=1. The calling routine can test this flag for the end of buffer.
.inc_page_reg
 ldx pagereg            \ load page register
 inx                    \ increment the value
 beq buffer_end         \ if it becomes zero then the end of the buffer (paged ram) is reached
 stx pagereg            \ write back to page register (i.e. select next page)
 ldx #0                 \ reset y register
 cpx #1                 \ clears Z-flag
.buffer_end
 rts                    \ return to store routine
 
\ Disable or enable the ESP8266 device
\ On entry: X = 0: disable
\           x = 1: enable
.disable_enable
 ldx save_x
 beq disable_enable_l1
 jmp uart_wifi_on
.disable_enable_l1
 jmp uart_wifi_off

\ Set SSL Buffer size to 4096 bytes
.sslbufsize
 jsr send_command
 equs "AT+CIPSSLSIZE=4096",&0D
 jmp read_response

