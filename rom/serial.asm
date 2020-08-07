\ sideway rom for electron wifi board
\ (c) roland leurs, may 2020

\ serial driver
\ version 1.00 for 16c2552

uart_rhr = uart+0
uart_thr = uart+0
uart_dll = uart+0
uart_dlm = uart+1
uart_fcr = uart+2
uart_lcr = uart+3
uart_mcr = uart+4
uart_lsr = uart+5
uart_msr = uart+6

\ Initialize the UART to 115k2, 8n1
\ All registers are unchanged
.init_uart
 php
 lda uart_lcr   \ enable baudrate divisor
 ora #&80
 sta uart_lcr
 lda #&01       \ set divisor to 1. 115k2
 sta uart_dll
 lda #&00
 sta uart_dlm
 lda #&03       \ 8 bit, 1 stop, no parity
 sta uart_lcr
 pla
 lda #&01       \ Enable 16 byte fifo buffer
 sta uart_fcr
 rts
 
\ Send a byte to the ESP8266 module
\ On exit all registers are unchanged.
.send_byte
 pha
.sb1
 lda uart_lsr
 and #&20
 beq sb1
 pla
 sta uart_thr
 rts
 
\ Read a byte from the ESP8266 module
\ If a byte is received, the C-flag is 1 and A holds the received character
\ If no byte is received (a timeout occurred) the C-flag is 0 and A is undefined.
.read_byte
 lda time_out  \ time-out parameter
 sta timer
 sta timer+1
 sta timer+2
.rb1
 lda uart_lsr
 and #&01
 bne rb3
 dec timer
 bne rb1
 dec timer+1
 bne rb1
 dec timer+2
 bne rb1
 clc \ time out, no data received
 rts
.rb3
 lda uart_rhr
 sec \ data received
 rts
 
\ Disable ESP8266 module
\ This call is in the serial driver because the board uses DTR to enable (H) or
\ disable (L) the module.
.uart_wifi_off
 lda uart_mcr       \ load modem control register
 ora #&01           \ set DTR high
 sta uart_mcr       \ write back to modem control register
 rts                \ end of subroutine

\ Enable ESP8266 module
\ This call is in the serial driver because the board uses DTR to enable (H) or
\ disable (L) the module.
.uart_wifi_on
 lda uart_mcr       \ load modem control register
 and #&7E           \ set DTR low
 sta uart_mcr       \ write back to modem control register
 rts                \ end of subroutine

\ Reset the ESP8266 module
\ This call is in the serial driver because the board uses RTS to reset the module.
.uart_hw_reset
 lda uart_mcr       \ load modem control register
 ora #&02           \ set RTS high
 sta uart_mcr       \ write back to modem control register
 if __ELECTRON__
 lda #&13           \ wait for fly back
 jsr osbyte
 jsr osbyte
 else
 jsr oswait         \ wait for fly back
 jsr oswait    
 endif
 lda uart_mcr       \ load modem control register
 and #&7D           \ set DTR low
 sta uart_mcr       \ write back to modem control register
 rts                \ end of subroutine
 
\ Read response from device
\ This routine does not use subroutines to avoid the Electron ULA
\ stopping the CPU in mode 0 - 3.
.uart_read_response
 ldx #0             \ reset buffer pointer
 stx pagereg
.uart_read_response_l1
 ldy time_out       \ setup time-out timer
 sty timer
 sty timer+1
.uart_rb1
 lda uart_lsr
 and #&01
 bne uart_rb3
 dey                \ decrement timer
 bne uart_rb1
 dec timer
 bne uart_rb1
 dec timer+1
 bne uart_rb1            \ if not expired wait another cyclus
 beq uart_end_read  \ timer expired, no (more) data received, goto end of routine
.uart_rb3
 lda uart_rhr       \ read received data
 sta pageram,x      \ store in memory
 inx                \ increment memory pointer
 bne uart_read_response_l1
 inc pagereg
 bne uart_read_response_l1
.uart_end_read
 lda #&00
 sta error_nr
 rts                \ end routine

