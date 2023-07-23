\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Check for update and install update
\ Version 1.00

\ Syntax:       *UPDATE

\ Do not move this data block. It must be just before 
\ the .date_time label!
.updatestr    equs "VER="
.crcstr       equs "CRC="
 
.update_host
equs "TCP",&0d
equs "www.acornelectron.nl",&0d
equs "80",&0d,&00
.update_httpget
equs "GET /wifi/elkwifi-latest.bin HTTP/1.1",&0d,&0a
equs "HOST: www.acornelectron.nl",&0d,&0a,&0d,&0a
.update_wget
equs "*WGET -X HTTP://ACORNELECTRON.NL/wifi/elkwifi-release.txt",&0D


.downloadupdate
 lda #8                         \ open tcp connection to server
 ldx #>update_host
 ldy #<update_host
 jsr wifidriver

 \ set pointer to http get command
 lda #<update_httpget
 sta data_counter+0
 lda #>update_httpget
 sta data_counter+1
 \ set data length
 lda #<(downloadupdate-update_httpget)
 sta data_counter+2
 lda #>(downloadupdate-update_httpget)
 sta data_counter+3
 lda #0
 sta data_counter+4
 ldx #data_counter              \ load index to parameters
 lda #13                        \ send http get command
 jmp wifidriver

 .version_httpget
equs "GET /wifi/elkwifi-version.txt HTTP/1.1",&0d,&0a
equs "HOST: www.acornelectron.nl",&0d,&0a,&0d,&0a
 
.checkupdate
 lda #8                         \ open tcp connection to server
 ldx #>update_host
 ldy #<update_host
 jsr wifidriver

 \ set pointer to http get command
 lda #<version_httpget
 sta data_counter+0
 lda #>version_httpget
 sta data_counter+1
 \ set data length
 lda #<(checkupdate-version_httpget)
 sta data_counter+2
 lda #>(checkupdate-version_httpget)
 sta data_counter+3
 lda #0
 sta data_counter+4
 ldx #data_counter              \ load index to parameters
 lda #13                        \ send http get command
 jmp wifidriver

.update_cmd                     \ Update command
 lda #0                         \ clear time zone flag
 sta tflag
 jsr skipspace1                 \ forward Y pointer to first non-space character
 jsr read_cli_param             \ read first parameter from command line
 cpx #&00                       \ test if any parameter given, x will be > 0
 beq update_start               \ continue if there are no parameters

 lda strbuf                     \ read first character of the parameter
 cmp #'-'                       \ check for a dash
 bne update_start               \ if not then start with the update
 lda strbuf+1                   \ read option
 ora #&20                       \ convert lower case
 cmp #'r'                       \ is it an r  (for Release notes)
 beq update_relnotes            \ yes, show the release notes
 cmp #'t'                       \ update with time zone set
 beq update_tz
 ldx #(error_bad_option-error_table)
 jmp error                      \ unrecognized option, throw an error

.update_relnotes
 jsr update_show_relnotes       \ show the release notes
 jmp call_claimed               \ end the command

.update_tz                      \
 lda #1                         \ set time zone update flag
 sta tflag

.update_start
 jsr checkupdate                \ Get latest version number
 \ process the response from server
 jsr reset_buffer               \ reset buffer register and pointer
 lda #<updatestr                \ load address of string to search
 sta needle                     \ and store it in workspace
 lda #>updatestr
 sta needle+1
 lda #4
 sta size
 jsr fnd
 bcc update_error

 ldy #0                         \ load pointer to compare latest version with current version
 lda tflag                      \ load time zone flag
 bne update_found               \ if set then always install the update, even if it's the current version
.update_compare
 jsr read_buffer                \ read character from received version
 cmp romversion,y               \ compare with current version string
 bne update_found               \ the strings don't match, so there is an update
 iny                            \ increment pointer
 cpy #4                         \ end of string
 bne update_compare             \ if not then compare the next character
 jsr printtext                  \ print message
 equs "You have the latest ROM version",&0D,&EA
 jmp update_end                 \ go to end routine

.update_error  
 ldx #(error_no_version-error_table)
 jmp error

.update_cancelled
 jsr printtext
 equb &0D
 equs "Update cancelled",&0D,&EA
 jmp update_end                 \ go to end routine

.update_found
 stx crc                        \ save X register (data pointer)
 jsr printtext                  \ print message
 equs "There is an update available.", &0D
 equs "Do you want to install it (y/R/N)? ",&EA
 jsr osrdch                     \ read character from keyboard
 pha                            \ save the character
 jsr osasci                     \ print it
 pla                            \ restore it
 cmp #'y'                       \ compare to lower case Y
 beq update_y
 ora #&20                       \ convert lower case
 cmp #'r'                       \ check for viewing release notes
 bne update_cancelled           \ not R, then cancel the update
 jsr osnewl                     \ it looks better on a new line
 jsr update_show_relnotes       \ show release notes
 jmp update_start               \ and ask again if the update must be installed

\ Store received CRC
.update_y
 ldx crc                        \ restore data pointer
 lda #<crcstr                   \ load address of string to search
 sta needle                     \ and store it in workspace
 lda #>crcstr
 sta needle+1
 lda #4
 sta size
 jsr fnd
 bcs update_y2
 jmp update_error
.update_y2
 jsr update_store_crc

 jsr printtext
 equb &0D
 equs "Downloading update",&0D,&EA
 lda #14                        \ close the connection before opening it again
 jsr wifidriver
 jsr downloadupdate             \ download the updated ROM image
 stx datalen                    \ store end of data block
 lda pagereg
 sta datalen+1

 
 lda #&00                       \ set load address to &2000
 sta load_addr
 lda #&20
 sta load_addr+1

\ Start processing the received data
 jsr reset_buffer           \ reset pointer to recieve buffer (PAM)
 jsr wget_search_ipd        \ search IPD string
 bcc update_crc_check       \ end if no IPD string found 
 jsr wget_read_ipd          \ read IPD (= number of bytes in datablok)
 jsr wget_http_status       \ check for HTTP statuscode 200
 jsr wget_search_crlf       \ search for newline

\ Copy the file contents to the main memory
.update_crd_loop
 jsr wget_read_http_data    \ read received data block
 jsr wget_test_end_of_data  \ test if this was the last block
 bcc update_crc_check
 jsr wget_search_ipd        \ search for next IPD
 bcc update_crc_check       \ jump if no more blocks found
 jsr wget_read_ipd          \ read the block length
 jmp update_crd_loop        \ read this block

.update_crc_check           \ do a crc check here!
 jsr printtext              \ print message
 equs "Calculating crc16",&0D,&EA
 jsr crc16                  \ calculate crc of the downloaded file
 lda crc                    \ compare the two CRC values
 cmp servercrc
 bne update_crc_error
 lda crc+1
 cmp servercrc+1
 bne update_crc_error

 \ The update is downloaded and the CRC is correct. Now set the current
 \ time zone in the ROM data and set the UART type flag
 lda uart_type              \ load current UART type
 sta &5FFE                  \ store in ROM data
 lda default_tz             \ load default time zone
 sta &5FFF                  \ store in ROM data
 lda tflag                  \ check time zone flag
 beq update_program         \ don't touch the time zone setting
 jsr GetUtcOff              \ load the current set time zone (utc offset)
 sty &5FFF                  \ store in ROM data

.update_program
 lda #&FE                   \ load driver function number
 ldx #&02                   \ load rom bank number in EEPROM
 ldy #&20                   \ load start address of new code
 jmp wifidriver             \ jump to the flash code; we won't come back here....

.update_end
 lda #14                    \ load close command code
 jsr wifidriver             \ close connection to server
 jmp call_claimed           \ CRC not implemented yet

.update_store_crc
 ldy #0                     \ reset pointer for copying the CRC to string buffer
.update_store_l1
 jsr read_buffer            \ read character from buffer
 sta strbuf,y               \ store in string buffer
 iny                        \ increment pointer
 cpy #4                     \ four characters copied?
 bne update_store_l1        \ no, then repeat loop
 lda #&0D                   \ terminate the string
 sta strbuf,y
 ldy #0                     \ reset pointer
 ldx #servercrc             \ address to store the received crc
 jsr string2hex             \ convert received CRC to hex value
 rts                        \ return to main routine

.update_crc_error
 lda #'R'                   \ print letter R(eveived)
 jsr oswrch
 lda #':'
 jsr oswrch
 lda servercrc+1            \ print server CRC
 jsr printhex
 lda servercrc
 jsr printhex
 jsr printtext              \ print text
 equb " C:", &EA
 lda crc+1                  \ print calculated CRC
 jsr printhex
 lda crc
 jsr printhex
 jsr osnewl                 \ print line feed
 ldx #(error_bad_crc-error_table)
 jmp error

.update_show_relnotes
 lda #14                    \ disconnect from server
 jsr wifidriver
 ldx #<update_wget          \ load pointer to command string
 ldy #>update_wget
 jmp oscli                  \ pass the command to the CLI and return to calling routine


