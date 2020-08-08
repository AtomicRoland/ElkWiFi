\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Error handling
\ Version 1.00


\ On entry X points to the error message relative to the beginning of the error table
.error                      lda #&00                \ Break opcode
                            tay                     \ copy to Y-reg
                            sta errorspace          \ set in non-sideways memory
                            lda #&00                \ Error number
                            sta errorspace+1
.error_loop                 lda error_table,x       \ load character from error string
                            cmp #&0D                \ test end-of-string
                            beq error_exec          \ if end, then go execute the error
                            sta errorspace+2,y      \ write to error message
                            inx                     \ increment source pointer
                            iny                     \ increment destination pointer
                            bne error_loop          \ copy next character
.error_exec                 lda #&00                \ terminate the error message string
                            sta errorspace+2,y
                            jmp errorspace          \ Lauch the error

.error_table                                        \ Table with error messages

.error_device_not_found     equs "Device not found",&0D
.error_no_response          equs "No response from device",&0D
.error_buffer_full          equs "Buffer full",&0D
.error_buffer_empty         equs "Buffer empty",&0D
.error_no_date_time         equs "No date/time received",&0D
.error_not_implemented      equs "Not implemented",&0D
.error_bad_option           equs "Unrecognized option",&0D
.error_bad_protocol         equs "Unsupported protocol",&0D
.error_http_status          equs "HTTP error",&0D
.error_no_pagedram          equs "No paged ram found",&0D
.error_disabled             equs "Wifi is disabled",&0D
