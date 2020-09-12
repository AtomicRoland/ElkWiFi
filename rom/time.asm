\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Get time and date from server
\ Version 1.00

\ Syntax:       *TIME
\               *DATE

\ Do not move this data block. It must be just before 
\ the .date_time label!
.timestr    equs "TIME="
.datestr    equs "DATE="
 
.date_time_host
equs "TCP",&0d
equs "www.acornelectron.nl",&0d
equs "80",&0d,&00
.date_time_httpget
equs "GET /wifi/time.php HTTP/1.1",&0d,&0a
equs "HOST: www.acornelectron.nl",&0d,&0a,&0d,&0a
 
.date_time
 lda #8                         \ open tcp connection to server
 ldx #>date_time_host
 ldy #<date_time_host
 jsr wifidriver

 \ set pointer to http get command
 lda #<date_time_httpget
 sta data_counter+0
 lda #>date_time_httpget
 sta data_counter+1
 \ set data length
 lda #<(date_time-date_time_httpget)
 sta data_counter+2
 lda #>(date_time-date_time_httpget)
 sta data_counter+3
 lda #0
 sta data_counter+4
 ldx #data_counter              \ load index to parameters
 lda #13                        \ send http get command
 jmp wifidriver

.time_cmd                       \ Time command
 jsr date_time                  \ Get time and date string from server
 \ process the response from server
 jsr reset_buffer               \ reset buffer register and pointer
 lda #<timestr                  \ load address of string to search
 sta needle                     \ and store it in workspace
 lda #>timestr
 sta needle+1
.time_find
 lda #5
 sta size
 jsr fnd
 bcc date_time_error
 jsr print_string               \ print the string from the response and end
 jmp call_claimed               \ claim the call and end routine

.date_cmd                       \ Date command
 jsr date_time                  \ Get time and date string from server
 \ process the response from server
 jsr reset_buffer               \ reset buffer register and pointer
 lda #<datestr                  \ load address of string to search
 sta needle                     \ and store it in workspace
 lda #>datestr
 sta needle+1
 lda #5
 sta size
 jsr fnd
 bcc date_time_error
 lda #&20                       \ introducing millennium bug :-)
 jsr printhex
 jsr print_string               \ print the string from the response and end
 jmp call_claimed               \ claim the call and end routine

.date_time_error  
 ldx #(error_no_date_time-error_table)
 jmp error

