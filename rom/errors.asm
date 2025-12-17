\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Error handling
\ Version 1.00


\ On entry X points to the error message relative to the beginning of the error table
.error                      lda #&00                \ Break opcode
                            tay                     \ copy to Y-reg
                            sta errorspace          \ set in non-sideways memory
.error_loop                 lda error_table,x       \ load character from error string
                            cmp #&0D                \ test end-of-string
                            beq error_exec          \ if end, then go execute the error
                            sta errorspace+1,y      \ write to error message
                            inx                     \ increment source pointer
                            iny                     \ increment destination pointer
                            bne error_loop          \ copy next character
.error_exec                 lda #&00                \ terminate the error message string
                            sta errorspace+1,y
                            jmp errorspace          \ Lauch the error

.error_table                                        \ Table with error messages

.error_device_not_found     equs 110,"Device not found",&0D
.error_no_response          equs 111,"No response from device",&0D
.error_buffer_full          equs 112,"Buffer full",&0D
.error_buffer_empty         equs 113,"Buffer empty",&0D
.error_no_date_time         equs 114,"No date/time received",&0D
.error_no_version           equs 115,"No version received",&0D
.error_not_implemented      equs 116,"Not implemented",&0D
.error_bad_option           equs 117,"Unknown option",&0D
.error_bad_protocol         equs 118,"Unknown protocol",&0D
.error_http_status          equs 119,"HTTP error",&0D
.error_no_pagedram          equs 120,"No paged ram",&0D
.error_disabled             equs 121,"Wifi is disabled",&0D
.error_opencon              equs 122,"Connect error",&0D
.error_bad_crc              equs 123,"CRC error, aborted",&0D
.error_bad_param            equs 124,"Wrong parameter",&0D
IF (error_bad_param-error_table)>255
    ERROR "Last line of error table is greater than 255 bytes away from the start of the error table."
ENDIF

