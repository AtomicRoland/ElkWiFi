\ Flash routine to reprogram the EEPROM.
\ (c) 2020 Roland Leurs
\ Version 1.0 14-08-2020
\
\ This code will be included in the EEPROM but is copied to the main memory before it is executed. You can copy it
\ by executing the WiFi driver function &FE where the Y register contains the high byte of the data to be "burned"
\ into the EEPROM and the X register contains the bank number within the EEPROM. Always the full 16kB will be "burned".
\
\ Bank 0:   &0000 - &3FFF       mfa = 1     bank = 0
\ Bank 1:   &4000 - &7FFF       mfa = 1     bank = 1
\ Bank 2:   &8000 - &BFFF       mfa = 0     bank = 0
\ Bank 3:   &C000 - &FFFF       mfa = 0     bank = 1
\ 
\ After the programming has finished the Electron will be hard reset because one of the ROMs will have changed and
\ the operating system needs to be reinitialized. Luckily, a reboot on the Electron does not take as much time as
\ rebooting a PC ;-)

\ Workspace
include "electron.asm"
mfatable  = zp+8                \ 4 bytes
banktable = zp+12               \ 4 bytes
src       = zp+16               \ 2 bytes
dst       = zp+18               \ 2 bytes

\ UART registers
uart_thr = uart+8
uart_dll = uart+8
uart_dlm = uart+9
uart_afr = uart+10
uart_lcr = uart+11
uart_mcr = uart+12

            org &1F00
\ Start with saving the X and Y registers
.flash      stx save_x          \ save bank number in the EEPROM
            sty save_y          \ save start address of data
            sei                 \ no more interrupts from here

\ Start with setting up the UART A-port for controlling the MFA pin (A15 of the EEPROM)
            lda uart_lcr        \ enable MFR register
            ora #&80
            sta uart_lcr
            lda #&01            \ set divisor to 1. 115k2
            sta uart_dll
            lda #&00
            sta uart_dlm
            sta uart_afr        \ set MFA to output
            lda #&03            \ 8 bit, 1 stop, no parity
            sta uart_lcr

            lda #'P'            \ print the P(rogram)
            jsr print
            lda #&20         \ set source address in zero page
            sta src+1
            lda #&00
            sta src
            sta dst             \ set destination address in zero page
            lda #&80
            sta dst+1
            ldy #0              \ reset pointer
.prgloop1   jsr program         \ program the next byte
            iny                 \ increment pointer
            bne prgloop1        \ jump if 256 byte block not finished
            lda #'*'            \ print a * as progress indicator
            jsr oswrch
            inc src+1           \ increment source pointer (only MSB)
            inc dst+1           \ increment destination pointer (only MSB)
            lda dst+1           \ load destination pointer
            cmp #&C0            \ test if complete bank is programmed
            bne prgloop1        \ if not then continue with next block
            rts

.program    lda #&AA            \ Initialize the Byte-Program sequence
            jsr write5555
            lda #&55
            jsr write2AAA
            sta uart_thr
            lda #&A0
            jsr write5555
            ldx #&00            \ load sideway bank number
            stx uart_mcr        \ write to UART (this sets A15 of the EEPROM)
            ldx #&0F
            stx &FE05
            ldx #1              \ reload bank number in X
            stx &FE05           \ write to ULA
            lda (src),y         \ load source data
            sta (dst),y         \ write to destination
            jsr wait            \ wait for programming to complete
            rts                 \ return to calling routine

            
\ Prepare the erase operation for a sector in bank X. After returning from this subroutine
\ immediatly write to the sector address.
.prepare_erase
            lda #&AA            \ initialize the Sector-Erase command sequence
            jsr write5555
            lda #&55
            jsr write2AAA
            lda #&80
            jsr write5555
            lda #&AA
            jsr write5555
            lda #&55
            jsr write2AAA
            ldx #&00            \ load sideway bank number
            stx uart_mcr        \ write to UART (this sets A15 of the EEPROM)
            ldx #&0F
            stx &FE05
            ldx #1              \ reload bank number in X
            stx &FE05           \ write to ULA
            lda #&30            \ start the erase operation
            sta uart_thr
            rts                 \ ready with preparation

\ Wait until an operation has finished. I use the "toggle bit" method; this means that during the
\ erase or program operation bit 6 will be toggled at every read cycle.
.wait       lda &8000           \ load data
            and #&40            \ clear all bits except bit 6
.waitloop   sta zp+7            \ store in zero page
            lda &8000           \ load data
            and #&40            \ clear all bits except bit 6
            cmp zp+7            \ compare with previous read
            bne waitloop        \ continue with next wait cycle if they are not equal
.waitend    rts                 \ return to calling routine

\ Write a value to &5555 of the EEPROM (not the 6502 address!)
.write5555  ldx #8              \ &5555 is in bank 1
            stx uart_mcr        \ write to UART (this sets A15 of the EEPROM)
            ldx #&0F
            stx &FE05
            ldx #&01            \ load sideway bank number
            stx &FE05           \ write to ULA
            sta &9555           \ write to the right address (this is the 6502 address in SWR space)
            rts                 \ return to calling routine

\ Write a value to &2AAA of the EEPROM (not the 6502 address!)
.write2AAA  ldx #8              \ &2AAA is in bank 0
            stx uart_mcr        \ write to UART (this sets A15 of the EEPROM)
            ldx #&0F
            stx &FE05
            ldx #&00            \ load sideway bank number
            stx &FE05           \ write to ULA
            sta &AAAA           \ write to the right address (this is the 6502 address in SWR space)
            rts                 \ return to calling routine

\ Print the character in A, followed with a colon and a space.
.print      jsr oswrch          \ print the character in A
            lda #':'            \ load a colon
            jsr oswrch          \ print it
            lda #' '            \ load a space
            jmp oswrch          \ print it and return

.printhex           pha                     \ save accu
                    lsr a                   \ shift high nibble to low
                    lsr a
                    lsr a
                    lsr a
                    jsr printhex_l1         \ print nibble
                    pla                     \ restore value
 .printhex_l1       and #&0F                \ remove high nibble
                    cmp #&0A                \ test for hex digit
                    bcc printhex_l2         \ if not then continue
                    adc #6                  \ add 6 for hex letter
 .printhex_l2       adc #&30                \ add &30 for ascii value
                    jsr osasci              \ print the digit and return
                    rts


.flash_end

SAVE "program.bin", flash, flash_end
