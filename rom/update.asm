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
equs "www.acornatom.nl",&0d
equs "80",&0d,&00
.update_httpget
equs "GET /atomwifi/elkwifi-latest.bin HTTP/1.1",&0d,&0a
equs "HOST: www.acornatom.nl",&0d,&0a,&0d,&0a

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
equs "GET /atomwifi/elkwifi-version.txt HTTP/1.1",&0d,&0a
equs "HOST: www.acornatom.nl",&0d,&0a,&0d,&0a
 
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

.update_cmd                     \ Time command
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
 jsr printtext                  \ print message
 equs "There is an update available.", &0D
 equs "Do you want to install it (y/N)? ",&EA
 jsr osrdch                     \ read character from keyboard
 cmp #'y'                       \ compare to lower case Y
 bne update_cancelled

\ Store received CRC
 lda #<crcstr                   \ load address of string to search
 sta needle                     \ and store it in workspace
 lda #>crcstr
 sta needle+1
 lda #4
 sta size
 jsr fnd
 bcc update_error
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

 jsr printtext
 equs "OK",&0D,&EA
 jmp call_claimed

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
 ldx #(error_bad_crc-error_table)
 jmp error

