\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Get ESP8266 firmware version
\ Version 1.00

\ Syntax:       *VERSION

.version_cmd
  \ Print ROM version
  ldx #0            \ Load index
.version_l1
  lda romtitle,x
  bne version_l1a
  lda #' '
.version_l1a
  jsr osasci
  inx
  cpx #(commands-romtitle)
  bne version_l1
  jsr osnewl

  \ Get ESP firemware version
  lda #2            \ load driver command

.generic_cmd
  jsr wifidriver
  jsr reset_buffer
  lda pageram
  beq no_device
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

