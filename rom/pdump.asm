; PDUMP - dumps the contents of the paged ram
; This commant accepts one optional parameter which is the start address of the 
; dump. This start address is the address within the page so the high byte
; is the page number and the low byte is the offset within the page. Don't confuse
; this with the real memory addresses of the Electron/Atom.

; Syntax:   *PRD [address] [banknr]

.pdump_cmd
 jsr save_bank_nr       ; save current bank number (in serial.asm)
 jsr skipspace1         ; forward Y pointer to first non-space character
 jsr read_cli_param     ; read parameter (start address) from command line
 cpx #&00               ; test if parameter given, x will be > 0
 bne pdump_param        ; jump if there is a parameter 
 lda #0                 ; set paged ram to page 0
 sta load_addr          ; save the index to page ram
 sta load_addr+1
 beq pdump_start        ; jump always

.pdump_param            
 ldx #load_addr         ; load zp address where the parameter value will be stored
 jsr string2hex         ; convert the string to a 16 bit address

 jsr skipspace1         ; forward Y pointer to first non-space character
 jsr read_cli_param     ; read the second parameter (bank number)
 cpx #&00               ; test if there is a second parameter
 beq pdump_start        ; jump if no bank number given
 ldx #zp                ; load zp address where the parameter value will be stored
 jsr string2hex         ; convert the parameter to a 16 bit value
 lda zp                 ; load lower byte
 jsr set_bank_nr        ; set new bank number (in serial.asm)

.pdump_start
 \ lda uart_mcr : jsr printhex : jsr osnewl
 lda load_addr          ; load the offset in paged ram
 and #&F8               ; align to 0 or 8 offset
 sta load_addr          ; store load address
 tay                    ; transfer to index register
 lda load_addr+1        ; load page number
 sta pagereg            ; write it to page register

.pdump_l1
 lda pagereg            ; load the page number
 jsr printhex           ; print it
 lda #':'               ; print a colon
 jsr oswrch
 tya                    ; transfer the ram-pointer to Accu
 pha                    ; save the value
 jsr printhex           ; print pointer value
 lda #' '               ; print two spaces
 jsr oswrch
 jsr oswrch
 ldx #8                 ; load counter
.pdump_l2               
 lda pageram,y          ; load data byte
 jsr printhex           ; print it
 lda #' '               ; print a space
 jsr oswrch
 iny                    ; increment pointer
 dex                    ; decrement counter
 bne pdump_l2           ; if not complete line (8 bytes) then do next byte
 pla                    ; get pointer value back
 tay                    ; write to ram-pointer
 ldx #8                 ; re-load counter
.pdump_l3
 lda pageram,y          ; load data byte
 bmi pdump_dot          ; if negative, print a dot
 cmp #&20               ; check for non printable value below 20
 bmi pdump_dot          ; print a dot
 cmp #&7F               ; check for backspace
 beq pdump_dot          ; print a dot
 jsr oswrch             ; it's a printable character, print it
.pdump_l4
 iny                    ; increment pointer
 dex                    ; decrement counter
 bne pdump_l3           ; if not complete line (8 bytes) then do next byte
 jsr osnewl             ; print new line
 jsr check_esc          ; test if escape is pressed
 bcs pdump_end          ; if escape is pressed then end routine
 cpy #0                 ; check if full page is displayed
 bne pdump_l1           ; not full page, continue
 inc pagereg            ; increment the page register
 bne pdump_l1           ; jump if not last page

.pdump_end
 jsr restore_bank_nr    ; restore bank number (in serial.asm)
 jmp call_claimed       ; claim the call and end routine

.pdump_dot
 lda #'.'               ; print a dot
 jsr oswrch
 jmp pdump_l4           ; continue
