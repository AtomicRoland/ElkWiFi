\ WGET command
\ Syntax:    *WGET [-T] [-A] [-P] <url> [address]
\ Option:    -T        optional    print the downloaded file directly on the screen
\            -A        optional    the file has an ATM header
\            -P        optional    the file has an Atom-in-PC header
\            url       required    the url of the file, including http(s)://
\            address   optional    load address of the file
\ The address will override the load address in the ATM header (if any). It will be ignored with the -T parameters since that option
\ does not store any contents in memory. If the file has no ATM header the address is required.
\ 
\ (c) Roland Leurs, July 2020

                newln = heap + &F7      \ 1 byte
                clptr = heap + &F8      \ 1 byte
                index = heap + &F9      \ 1 byte
                tflag = heap + &FA      \ 1 byte
                aflag = heap + &FB      \ 1 byte
                pflag = heap + &FC      \ 1 byte
                proto = heap + &FD      \ 1 byte
                laddr = heap + &FE      \ 2 bytes

.wget_cmd                   \ start wget command
 lda #0                     \ initialize flags and address
 sta tflag
 sta aflag
 sta pflag
 sta proto                  \ default no ssl (i.e. http)
 sta laddr
 sta laddr+1
 lda #&0D                   \ set new line character
 sta newln                  \ can be overwritten by -U flag

.wget_l1
 jsr skipspace1             \ forward Y pointer to first non-space character
 jsr read_cli_param         \ read first parameter from command line
 cpx #&00                   \ test if any parameter given, x will be > 0
 bne wget_read_params       \ continue if one parameter is on the command line
 jsr printtext              \ no parameter, print a message
 equs "Usage: WGET [-T] [-A] [-P] <url> [address]",&0D,&EA
 jmp call_claimed           \ end of command

.wget_read_params
 lda strbuf                 \ read first character of the parameter
 cmp #'-'                   \ check for a dash
 bne wget_read_uri          \ it's not a dash so we consider it the url
 lda strbuf+1               \ read character of option
 ora #&20                   \ convert to lowercase
 cmp #'t'                   \ check for T (text file)
 beq wget_option_t          \ jump if T
 cmp #'a'                   \ check for A (ATM header)
 beq wget_option_a          \ jump if A
 cmp #'u'                   \ check for U (unix text file)
 beq wget_option_u          \ jump if U
 cmp #'p'                   \ check for P (Atom-in-PC header)
 beq wget_option_p          \ jump if P
 ldx #(error_bad_option-error_table)
 jmp error                  \ unrecognized option, throw an error

.wget_option_u              
 lda #&0A                   \ load alternative new line character
 sta newln                  \ write to workspace
.wget_option_t              
 lda #1                     \ set flag to 1
 sta tflag
 bne wget_l1                \ jump always

.wget_option_a
 lda #1                     \ set flag to 1
 sta aflag 
 bne wget_l1                \ jump always

.wget_option_p
 lda #1                     \ set flag to 1
 sta pflag
 bne wget_l1                \ jump always

.wget_read_uri              \ the parameter is not an option switch, treat it like a url
 sty clptr                  \ save command line pointer
 lda strbuf                 \ very primitive check for http(s)
 ora #&20                   \ convert to lower case
 cmp #'h'                   \ check for 'H'
 beq wget_read_uri_l1       \ jmp if an 'H'
.wget_protocol_error
 ldx #(error_bad_protocol-error_table)
 jmp error                  \ unsupported protocol, throw an error

.wget_read_uri_l1
 ldx #4                     \ preset my pointer
.wget_read_uri_l1a
 lda strbuf,x               \ check if 5th character is either an S or :
 cmp #':'                   \ check for ':'
 beq wget_read_uri_l3       \ it's a :, go check for the two slashes
 ora #&20                   \ convert to lower case
 cmp #'s'                   \ check for 's'
 beq wget_read_uri_l2       \ it's a s, set protocol to https and go check for two slashes
 bne wget_protocol_error    \ looks like an unsupported protocol to me

\ Set protocol in heap
.wget_read_uri_l2
 lda #4                     \ set ssl/https flag
 sta proto
 inx                        \ increment pointer
 bne wget_read_uri_l1a      \ jump always
.wget_read_uri_l3
 inx                        \ increment pointer
 lda strbuf,x               \ load character
 cmp #'/'                   \ check for first slash
 bne wget_protocol_error    \ jump if not slash
 inx                        \ increment pointer
 lda strbuf,x               \ load character
 cmp #'/'                   \ check for second slash
 bne wget_protocol_error    \ jump if not slash
 ldy #0                     \ reset pointer
 stx index                  \ save pointer to string buffer
 ldx proto                  \ load index to protocol table
.wget_read_uri_l4
 lda protocols,x            \ load character
 sta heap,y                 \ write to heap
 inx                        \ increment index
 iny                        \ increment pointer
 cmp #&0D                   \ test for end of string
 bne wget_read_uri_l4

 \ Copy the hostname to the start of the string buffer 
 ldy #0                     \ reset pointer
 ldx index                  \ restore pointer to string buffer
 inx                        \ increment pointer to start of hostname
.wget_read_uri_l4a
 lda strbuf,x               \ load character
 cmp #' '                   \ check for space
 beq wget_read_uri_l5       \ if it's space, jump to end of hostname copy
 cmp #':'                   \ check for colon
 beq wget_read_uri_l5       \ if it's colon, jump to end of hostname copy
 cmp #'/'                   \ check for slash
 beq wget_read_uri_l5       \ if it's colon, jump to end of hostname copy
 cmp #&0D                   \ check of end-of-input
 beq wget_read_uri_l5       \ if it's the end, jump to end of hostname copy
 sta strbuf,y               \ store the character in the string buffer
 iny                        \ increment pointers
 inx
 bne wget_read_uri_l4a      \ jump for next character
.wget_read_uri_l5
 pha                        \ save the character
 lda #&0D                   \ load end-of-string
 sta strbuf,y               \ terminate the string
 stx index                  \ save pointer to string buffer
 ldx #4                     \ load pointer to heap (just behind the procol string)
 jsr copy_to_heap           \ copy the hostname to the heap
 stx save_y                 \ save heap index
 ldx index                  \ restore string buffer pointer
 pla                        \ get character back
 cmp #':'                   \ test for colon
 bne wget_read_uri_l8       \ jump if no colon (meaning there is no port specified)

\ Copy the port number from the string buffer to the heap
 ldy save_y                 \ restore heap index
.wget_read_uri_l6
 inx                        \ increment pointer
 lda strbuf,x               \ load character of port
 cmp #' '                   \ test for end of port number, either space, slash or CR
 beq wget_read_uri_l7
 cmp #'/'
 beq wget_read_uri_l7
 cmp #&0D
 beq wget_read_uri_l7
 sta heap,y                 \ write to heap
 iny                        \ increment pointer
 bne wget_read_uri_l6       \ jump if there are more characters
.wget_read_uri_l7
 stx index                  \ save pointer to string buffer (start of filespec)
 lda #&0D                   \ terminate port number
 sta heap,y
 bne wget_open_connection   \ jump always

\ Copy the default port numbers to the heap 
.wget_read_uri_l8
 ldx proto                  \ load index to protocol table
 ldy save_y                 \ restore heap index
.wget_read_uri_l9
 lda ports,x                \ load character
 sta heap,y                 \ write to heap
 inx                        \ increment index
 iny                        \ increment pointer
 cmp #&0D                   \ test for end of string
 bne wget_read_uri_l9       \ jump if string not copied yet

\ Now the first three parameters are on the heap:
\ protocol, hostname and port number
\ We can now fire the CPstaRT command
.wget_open_connection
 lda proto                  \ load protocol
 beq wget_open_l1           \ jump if tcp
 lda #26                    \ load Wifi command
 jsr wifidriver             \ Init SSL Buffer

.wget_open_l1
 ldx #>heap                 \ load heap address into registers x and y
 ldy #<heap
 lda #8                     \ send "open" command 
 jsr wifidriver
 lda pageram+&B             \ check for OK response (Normal response is: CONNECT crlf crlf OK crlf crlf)
 cmp #'O'
 bne wget_open_err          \ It's not OK, so throw an error
 lda pageram+&C             \ check second character, just to be sure
 cmp #'K'
 beq wget_build_get         \ It's OK, continue
.wget_open_err
 jsr reset_buffer           \ reset buffer pointer to print error message from device
 jsr print_string           \ print error string
 ldx #(error_opencon-error_table)
 jmp error

.wget_build_get
\ Build the GET command
 ldy #0                     \ reset pointer to heap
 ldx #0                     \ reset index
.wget_get_l1
 lda getcmd,x               \ load character from GET command
 sta heap,y                 \ write to heap
 inx
 iny
 cpx #5                     \ test for end of string
 bne wget_get_l1

\ Copy file spec to heap
 ldx index                  \ restore the index to string buffer (filespec)
 lda strbuf,x               \ check if there is no filespec, eg http://stardot.org.uk
 cmp #&0D                   \ is hostname terminated with CR
 beq wget_get_l3a           \ if yes then don't copy the filespec
 inx                        \ increment pointer to first character of filespec
.wget_get_l2
 lda strbuf,x               \ load character
 sta heap,y                 \ write to heap
 inx                        \ increment buffer index
 iny                        \ increment heap pointer
 cmp #' '                   \ test for end of filespec
 beq wget_get_l3
 cmp #&0D                   
 beq wget_get_l3
 bne wget_get_l2            \ if not end of filespec then jump for next character
.wget_get_l3
 dey                        \ decrement heap pointer to overwrite the CR
 stx index                  \ save string buffer index
.wget_get_l3a
 ldx #0                     \ reset index
.wget_get_l4
 lda http11,x               \ load character from http header
 sta heap,y                 \ write to heap
 iny                        \ increment heap pointer
 inx                        \ increment buffer index
 cpx #17                    \ compare to string length
 bne wget_get_l4            \ jump if characters left

\ Copy host to heap
 ldx #0                     \ reset index
.wget_get_l5
 lda strbuf,x               \ load character from hostname (it was copied to the beginning of string buffer)
 sta heap,y                 \ write to heap
 iny                        \ increment heap pointer
 inx                        \ increment buffer index
 cmp #&0D                   \ test for end of hostname
 bne wget_get_l5            \ jump if characaters left

\ Copy rest of http header to heap
 dey                        \ decrement heap pointer to overwrite the CR
 ldx #0                     \ reset index
.wget_get_l6
 lda user_agent,x           \ load character
 sta heap,y                 \ write to heap
 iny                        \ increment heap pointer
 inx                        \ increment buffer index
 cmp #&00                   \ test for end of header
 bne wget_get_l6            \ jump if characaters left

\ Now read the load address
 sty save_y                 \ save the header length
 ldx index                  \ restore index to string buffer
 ldy clptr                  \ restore pointer on command line
 jsr skipspace1             \ read next character
 jsr read_cli_param
 cpx #0                     \ test if no parameter
 beq wget_send_l1           \ jump if no address was given
 ldx #zp                    \ load zero page address where parameter will be stored
 jsr string2hex             \ convert to hexadecimal value
 lda zp                     \ copy to my workspace
 sta laddr
 lda zp+1
 sta laddr+1
 lda laddr

\ Set parameters for CIPSEND command
.wget_send_l1
 ldx #data_counter          \ load pointer to zeropage
 lda #<heap                 \ set start of heap in zeropage
 sta &00,x
 lda #>heap
 sta &01,x
 lda save_y                 \ load header length
 sta &02,x                  \ store in zeropage
 lda #&00
 sta &03,x
 sta &04,x
 lda #13                    \ load driver command
 jsr wifidriver             \ send the header

\ Process received data
.wget_copy_received_data
 jsr reset_buffer           \ reset pointer to recieve buffer (PAM)
 jsr wget_search_ipd        \ search IPD string
 bcc wget_crd_end           \ end if no IPD string found 
 jsr wget_read_ipd          \ read IPD (= number of bytes in datablok)
 jsr wget_http_status       \ check for HTTP statuscode 200
 jsr wget_search_crlf       \ search for newline

 \ Check the header flags -A (ATM) and -P (Atom-in-PC or APC); the first has presendence when both are given.
 lda aflag                  \ test if ATM header option given
 bne wget_atm_header        \ jump if there's no -A flag
 lda pflag                  \ test if APC header option given
 beq wget_set_load_addr     \ skip reading the header if no APC header (pflag = 0)
 jsr wget_read_apc_header   \ read the APC header
 jmp wget_set_load_addr     \ jump always

.wget_atm_header
 jsr wget_read_atm_header   \ read the ATM header

.wget_set_load_addr
 lda laddr                  \ check if there is a load address by now
 ora laddr+1
 bne wget_set_load_addr_l1  \ yes, there is a load address so jump
 jsr wget_set_default_load  \ otherwise set the default load address (PAGE on Electron, ?#12 on Atom)
.wget_set_load_addr_l1
 lda laddr                  \ copy load address to zero page
 sta load_addr
 lda laddr+1
 sta load_addr+1

.wget_crd_loop
 lda tflag                  \ check for T-flag (if set, dump data to screen)
 bne wget_dump_data
 jsr wget_read_http_data    \ read received data block
 jmp wget_crd_l1            \ jump for next block
.wget_dump_data
 jsr wget_dump_http_data    \ print received data block
.wget_crd_l1
 jsr wget_test_end_of_data  \ test if this was the last block
 bcc wget_crd_end
 jsr wget_search_ipd        \ search for next IPD
 bcc wget_crd_end           \ jump if no more blocks found
 jsr wget_read_ipd          \ read the block length
 jmp wget_crd_loop          \ read this block
.wget_crd_end
 
\ Close connection
.wget_close
 lda #14                    \ load close command code
 jsr wifidriver             \ close connection to server
 jmp call_claimed           \ end of command

.protocols
 equs "TCP",&0D
 equs "SSL",&0D

.ports
 equs "80",&0D,&0D
 equs "443",&0D

.getcmd
 equs "GET /"
.http11
 equs " HTTP/1.1",&0D,&0A
 equs "HOST: "
.user_agent
 equb &0D,&0A
 equs "User-Agent: Elk WiFi WGET"
 equb &0D,&0A,&0D,&0A,&00


.ipd_needle equb "+IPD,"
.wget_search_ipd
 ldy #4                     \ load pointer 
.sipd0
 lda ipd_needle,y           \ load character from search string (= needle)
 sta heap,y                 \ store in workspace
 dey                        \ decrement pointer
 bpl sipd0                  \ jump if characters follow
 lda #5                     \ load needle length
.wget_search
 sta size                   \ store in workspace
 ldy #0                     \ reset pointer
.sipd1
 jsr wget_test_end_of_data  \ check for end of data
 bcc sipd5                  \ jump if no more data
 jsr read_buffer            \ read character from input buffer
 pha                        \ save it on stack
 jsr dec_blocksize          \ decrement block size
 pla                        \ restore character
 cmp heap,y                 \ compare with character in needle
 bne sipd3                  \ jump if not equal
\ CHARACTER MATCH
 iny                        \ character matches, increment pointer 
 cpy size                   \ test for end of needle
 bne sipd4                  \ not the end, continue for next character
 sec                        \ set carry for needle found
 rts                        \ return to calling routine
.sipd3
; CHARACTER DOES NOT MATCH, RESET POINTER
 ldy #0                     \ character does not match, reset pointer
.sipd4
 jsr wget_test_end_of_data  \ test if any data follows
 bcs sipd1                  \ jump if there is more data
.sipd5
 rts                        \ else return with carry cleared, i.e. needle not found

.crlf equb &0D,&0A,&0D,&0A
.wget_search_crlf
 ldy #3                     \ initialize pointer
.scrlf1
 lda crlf,y                 \ load character from search string (= needle)
 sta heap,y                 \ write to workspace
 dey                        \ decrement pointer
 bpl scrlf1                 \ jump if more characters to copy
 lda #4                     \ load needle length
 bne wget_search            \ jumps always

.wget_read_ipd
 lda #0                     \ reset block size
 sta blocksize
 sta blocksize+1
.read_ipd_loop
 jsr read_buffer            \ read character from input buffer
 cmp #':'                   \ test for end of IPD string
 beq read_ipd_end           \ jump if end of IPD string
 sec                        \ set carry for substraction
 sbc #'0'                   \ convert to hex value
 jsr mul10                  \ multiply the IPD value by 10 and add the last value read
 jmp read_ipd_loop          \ repeat for next character
.read_ipd_end
 lda blocksize+1            \ load blocksize+1
 ora blocksize              \ ora with blocksize
 rts                        \ return with Z flag indicating the IPD value (zero or non-zero)


.mul10 \ MULTIPLY VALUE OF blocksize BY 10 AND ADD A
 pha
 asl blocksize
 lda blocksize
 rol blocksize+1
 ldy blocksize+1
 asl blocksize
 rol blocksize+1
 asl blocksize
 rol blocksize+1 
 clc
 adc blocksize
 sta blocksize
 tya
 adc blocksize+1
 sta blocksize+1
 clc
 pla
 adc blocksize
 sta blocksize
 lda blocksize+1
 adc #0
 sta blocksize+1
 rts

.wget_read_atm_header
 ldy #21                    \ load header length
.hdr1
 jsr dec_blocksize          \ decrement block size
 jsr read_buffer            \ read byte from input buffer
 sta heap,y                 \ write to workspace
 dey                        \ decrement pointer
 bpl hdr1                   \ jump if more bytes follow
 lda laddr                  \ test if there was an address on the command line
 ora laddr+1                \ that has presedence over the ATM load address
 bne hdr2                   \ jump if load address was specified
 lda heap+5                 \ set load address from heap
 sta laddr                  \ please mind that the ATM header is read backwards so
 lda heap+4                 \ low nibble is in a higher address than 
 sta laddr+1                \ the high nibble
.hdr2
 rts                        \ return from subroutine

.wget_read_apc_header
 ldy #16                    \ load header length
.hdr3
 jsr dec_blocksize          \ decrement block size
 jsr read_buffer            \ read byte from input buffer
 sta heap,y                 \ write to workspace
 dey                        \ decrement pointer
 bpl hdr3                   \ jump if more bytes follow
 lda laddr                  \ test if there was an address on the command line
 ora laddr+1                \ that has presedence over the APC load address
 bne hdr4                   \ jump if load address was specified
 lda heap+16                \ set load address from heap
 sta laddr                  \ please mind that the APC header is read backwards so
 lda heap+15                \ low nibble is in a higher address than 
 sta laddr+1                \ the high nibble
.hdr4
 rts                        \ return from subroutine


\ READ HTTP DATA UNTIL blocksize IS 0
\ DATA IS WRITTEN TO LOAD ADDRESS
.wget_read_http_data
 ldy #0                     \ clear index
 jsr wget_test_end_of_data  \ test for end of data
 bcc read_http_end          \ jump if end of data is reached
 jsr read_buffer            \ read byte from input buffer
 sta (load_addr),y          \ store in memory
 inc load_addr              \ increment load address
 bne rhd1
 inc load_addr+1
.rhd1
 jsr dec_blocksize          \ decrement block size
 bne wget_read_http_data    \ jump if more bytes to read
.read_http_end  
 rts                        \ return from subroutine

\ READ HTTP DATA UNTIL blocksize IS 0
\ Data is printed to screen.
.wget_dump_http_data
 jsr wget_test_end_of_data  \ test for end of data
 bcc read_http_end          \ jump if end of data is reached
 jsr read_buffer            \ read byte from input buffer
 bmi wget_dump_http_data_l1 \ if bit 7 is set then don't print it
 cmp newln                  \ compare to new line character
 beq wget_dump_newline      \ jump if new line character
 cmp #' '                   \ check for space
 bmi wget_dump_http_data_l1 \ don't print control codes
 jsr oswrch                 \ print the character
.wget_dump_http_data_l1
 jsr dec_blocksize          \ decrement block size
 bne wget_dump_http_data    \ jump if more bytes to read
 rts                        \ return from subroutine
.wget_dump_newline
 jsr osnewl                 \ move cursor to next line
 jmp wget_dump_http_data_l1 \ continue

.dec_blocksize
 sec
 lda blocksize
 sbc #1
 sta blocksize
 cmp #&FF
 bne DBS1
 lda blocksize+1
 sbc #1
 sta blocksize+1
.DBS1 \ CHECK IF blocksize IS 0
 lda blocksize
 ora blocksize+1
 rts

.wget_test_end_of_data
 cpx datalen                \ compare pam index with data length LSB
 bne not_end_of_data        \ jump if not equal
 lda datalen+1              \ load MSB data length
 cmp pagereg                \ compare with pam register
 bne not_end_of_data        \ jump if not equal
 clc                        \ end of data, clear carry
 rts                        \ return with c=0 (no more data)
.not_end_of_data
 sec                        \ there is still data, set carry
 rts                        \ return with c=1 (data available)

.wget_set_default_load
 pha                        \ save accu
if __ELECTRON__
 txa                        \ save x and y register also
 pha
 tya
 pha
 lda #&83                   \ perform OSBYTE &83: return current OSHWM
 jsr osbyte
 stx laddr                  \ save low byte
 sty laddr+1                \ save high byte
 pla                        \ restore x and y registers
 tay
 pla
 tax
else
 lda #&00                   \ low byte is always zero on the Atom
 sta laddr
 lda &12                    \ load high byte from zero page (?18)
 sta laddr+1
endif
 pla                        \ restore accu
 rts

.wget_http_status
 jsr wget_test_end_of_data  \ Read next character...
 bcc wget_http_status_end   \ ... as long as there is data
 jsr dec_blocksize
 jsr read_buffer            \ ... read the next byte
 cmp #' '                   \ check for space
 bne wget_http_status
 stx index                  \ save the buffer pointer
 jsr dec_blocksize
 jsr read_buffer            \ read the http status code (3 digits)
 sta heap                   \ store in heap
 jsr dec_blocksize
 jsr read_buffer
 sta heap+1
 jsr dec_blocksize
 jsr read_buffer
 sta heap+2
 lda heap                   \ now check for code 200
 cmp #'2'
 bne wget_http_status_err   \ if not 2 then jump to error
 lda #'0'                   \ load '0'
 cmp heap+1                 \ check second digit
 bne wget_http_status_err   \ jump if not '0'
 cmp heap+2                 \ check third digit
 bne wget_http_status_err   \ jump if not '0'
.wget_http_status_end
 rts                        \ end subroutine

.wget_http_status_err
 ldx index                  \ restore pointer to http status code
 jsr print_string           \ print the status code + message
 ldx #(error_http_status-error_table)
 jmp error                  \ throw an error
