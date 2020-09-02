\ sideway rom for electron wifi board
\ (c) roland leurs, may 2020

\ serial driver
\ version 1.00 for 16c2552

uart_rhr = uart+0
uart_thr = uart+0
uart_dll = uart+0
uart_dlm = uart+1
uart_fcr = uart+2
uart_afr = uart+2
uart_lcr = uart+3
uart_mcr = uart+4
uart_lsr = uart+5
uart_msr = uart+6

bank_save = save_a

\ Initialize the UART to 115k2, 8n1
\ Page RAM bank 0 is selected
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
 sta uart_afr   \ set MFB to output
 lda #&03       \ 8 bit, 1 stop, no parity
 sta uart_lcr
 pla
 lda #&01       \ Enable 16 byte fifo buffer
 sta uart_fcr
 lda uart_mcr   \ load current modem control register
 and #&F7       \ set bit 3 to 0
 sta uart_mcr   \ write back to modem conrol and activate bank 0
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
 
\ Disable ESP8266 module
\ This call is in the serial driver because the board uses DTR to enable (H) or
\ disable (L) the module.
.uart_wifi_off
 lda uart_mcr       \ load modem control register
 ora #&01           \ set DTR high
 sta uart_mcr       \ write back to modem control register
 sta uart_lsr       \ write to LSR to disable the UART reset (value don't care; handled by the CPLD!)
 rts                \ end of subroutine

\ Enable ESP8266 module
\ This call is in the serial driver because the board uses DTR to enable (H) or
\ disable (L) the module.
.uart_wifi_on
 lda uart_mcr       \ load modem control register
 and #&7E           \ set DTR low
 sta uart_mcr       \ write back to modem control register
 sta uart_msr       \ write to MSR to disable the UART reset (value don't care; handled by the CPLD!)
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

\ To avoid unnecessary waiting this routine first waits for the initial respons with
\ a long time-out and after the data stream has started it will wait with a short 
\ time-out.
.uart_read_response
 sei                        \ disable interrupts
 ldx #0                     \ reset buffer pointer
 stx pagereg
 ldy time_out               \ initialize timer
 sty timer                  \ the timer addresses must not be in the Electron's main
 sty timer+1                \ memory. So I picked the last bytes of the paged RAM since
 sty timer+2                \ this timer will only be used before the data transfer starts.
.uart_wait_for_data
 lda uart_lsr               \ test data present
 and #&01
 bne uart_read_start        \ jump if data received
 
\ Decrement long timer
 dec timer                  \ decrement timer
 bne uart_wait_for_data
 dec timer+1
 bne uart_wait_for_data     \ if not expired wait another cyclus
 dec timer+2
 bne uart_wait_for_data     \ if not expired wait another cyclus
 beq uart_read_end          

\ Data stream has started. The time-out is here counted by the Y register. The next byte should arrive
\ after 80 microseconds. This loop will be long enough to cover this time about 40 times.
.uart_read_start
 ldy #0                     \ load (very) short timer
 lda uart_rhr               \ read received data
 sta pageram,x              \ store in memory
 inx                        \ increment memory pointer
 bne uart_read_l1
 inc pagereg                \ increment page register
 bne uart_read_l1           \ jump if not end of ram reached
 jmp buffer_full            \ throw error
.uart_read_l1       
 dey                        \ decrement short timer 
 beq uart_read_end          \ jump if transfer has ended
 lda uart_lsr               \ load status byte
 and #&01                   \ test if data received
 bne uart_read_start        \ read byte if received
 beq uart_read_l1           \ else decrement timer
.uart_read_end
 lda &F4                    \ clear all pending interrupts
 ora #&70
 sta &FE05
 cli                        \ enable interrupts
 rts                        \ no data received, end routine

\ Alternative routine to get the data from a webserver. While the uart_read_response is suitable
\ for reading data that comes in one block, this routine is written for data coming in multiple
\ blocks like driver call 13 (cipsend). That function can produce a few bursts of data and that
\ makes uart_read_response unsuitable.
\ This function uses a long time-out until the first + sign is received. This indicates the first
\ +IPD: marker and thus the start of the main data transfer. From that point on, the receiving routine
\ uses the short time out counter.
.uart_get_response
 \ sei                        \ disable interrupts
 ldx #0                     \ reset buffer pointer
 stx pagereg
.uart_get_resp_l1
 ldy time_out               \ initialize timer
 sty timer                  \ the timer addresses must not be in the Electron's main
 sty timer+1                \ memory. So I picked the last bytes of the paged RAM since
 sty timer+2                \ this timer will only be used before the data transfer starts.
.uart_gr_wait
 lda uart_lsr               \ test data present
 and #&01
 bne uart_gr_read_data      \ jump if data received
 
\ Decrement long timer
 dec timer                  \ decrement timer
 bne uart_gr_wait
 dec timer+1
 bne uart_gr_wait           \ if not expired wait another cyclus
 dec timer+2
 bne uart_gr_wait           \ if not expired wait another cyclus
 beq uart_read_end          

.uart_gr_read_data
 lda uart_rhr               \ load received data
 cmp #'+'                   \ is it a plus (start of +IPD)?
 beq uart_gr_read_l1        \ yes, then jump
 sta pageram,x              \ store in memory
 inx
 bne uart_get_resp_l1       \ jump if not page crossing
 inc pagereg                \ increment page register
 bne uart_get_resp_l1       \ jump if not end of ram reached
 jmp buffer_full            \ throw error


\ Data stream has started. The time-out is here counted by the Y register. The next byte should arrive
\ after 80 microseconds. This loop will be long enough to cover this time about 40 times.
.uart_gr_read_start
 lda uart_rhr               \ read received data
.uart_gr_read_l1
 ldy #0                     \ load (very) short timer
 sta pageram,x              \ store in memory
 inx                        \ increment memory pointer
 bne uart_gr_read_l3
 inc pagereg                \ increment page register
 bne uart_gr_read_l3        \ jump if not end of ram reached
 jmp buffer_full            \ throw error
.uart_gr_read_l2       
 dey                        \ decrement short timer 
 beq uart_read_end          \ jump if transfer has ended
.uart_gr_read_l3
 lda uart_lsr               \ load status byte
 and #&01                   \ test if data received
 bne uart_gr_read_start     \ read byte if received
 beq uart_gr_read_l2        \ else decrement timer

\ Save bank number
\ Saves the current 64K bank number of the paged RAM
.save_bank_nr
 pha                \ save A register
 lda uart_mcr       \ load current value
 sta bank_save      \ save in memory
 pla                \ restore A register
 rts                \ end subroutines

\ Restore bank number
\ Restores the saved bank number of the paged RAM
.restore_bank_nr
 pha                \ save A register
 lda bank_save      \ load saved value
 sta uart_mcr       \ write to uart
 pla                \ restore A register
 rts                \ end subroutines

\ Set bank number
\ Sets the bank number to the value of the lsb of A
.set_bank_nr
 pha                \ save A register
 pha                \ save A register
 lda uart_mcr       \ load mcr
 and #&F7           \ clear bit 3
 sta uart_mcr       \ write back to mcr
 pla                \ restore A
 and #&01           \ mask bit 0
 clc                \ clear carry for shifting
 asl a              \ shift four times right
 asl a
 asl a
 ora uart_mcr       \ 'or' the A with the current value of the mcr
 sta uart_mcr       \ set the new value
 pla                \ restore A
 rts                \ end of routine

\ Alternative bank number set routine, shorter and faster
.set_bank_0         \ set it to 0
 lda uart_mcr       \ load current value
 and #&F7           \ clear bit 3 (MFB)
 sta uart_mcr       \ write it back
 rts                \ end of routine

\ Alternative bank number set routine, shorter and faster
.set_bank_1         \ set it to 1
 lda uart_mcr       \ load current value
 ora #&08           \ clear bit 3 (MFB)
 sta uart_mcr       \ write it back
 rts                \ end of routine

\ Even more faster, write A to MCR
.set_bank_a
 sta uart_mcr       \ write value to MCR
 rts

\ Test if wifi is disabled
\ This will return with Z=1 if wifi is disabled and Z=0 if wifi is enabled
.test_wifi_ena
 lda uart_mcr       \ load status
 and #&01           \ test lowest bit (DTR)
 rts                \ return

