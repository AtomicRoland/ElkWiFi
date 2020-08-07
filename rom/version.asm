\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Get ESP8266 firmware version
\ Version 1.00

.version_cmd
  lda #2            \ set timeout to short value
  sta time_out
  lda #2            \ load driver command

.generic_cmd
  jsr wifidriver
  jsr reset_buffer
  lda pageram
  beq no_device
.version_l1
  jsr search0a      \ skips the first string, this is generally the given command
.version_l2
  jsr read_buffer
  jsr oswrch
  lda datalen+1     \ compare data pointer with data length
  cmp pagereg
  bne version_l2
  cpx datalen
  bne version_l2
  
.version_end
  jmp call_claimed
  
.no_device
 ldx #(error_no_response-error_table)
 jmp error

