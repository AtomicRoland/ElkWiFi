\ MODE command, used to set the Wifi mode to STATION, ACCESSPOINT or BOTH.

\ Syntax:       *MODE <1 | 2 | 3>

.mode_cmd 			        \ start command from here
 jsr skipspace1             \ forward Y pointer to first non-space character
 jsr read_cli_param         \ read ssid from command line
 cpx #&00                   \ test if ssid given, x will be > 0
 bne mode_init_heap         \ continue as the ssid is on the command line
 jsr printtext              \ no ssid, print a message
 equs "Usage: MODE <1..3>",&0D
 equs "MODE 1 -> STATION",&0D
 equs "MODE 2 -> ACCESS POINT",&0D
 equs "MODE 3 -> BOTH",&0D,&EA
 jmp call_claimed           \ end of command

.mode_init_heap
 ldx #0                     \ reset heap pointer
 jsr copy_to_heap           \ copy the parameter to the heap

 lda heap                   \ check for query (param = ?)
 cmp #'?'
 bne set_mode
 lda #0                     \ user asks for mode
 sta heap                   \ clear parameters
.set_mode
 ldx #>heap                 \ load address of parameter block
 ldy #<heap                   
 lda #2                     \ set time out
 sta time_out
 lda #&07                   \ load driver command
 jmp generic_cmd            \ execute the command

