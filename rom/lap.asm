\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Get a list of access points. This is a very basic version.....
\ Version 1.00

\ Syntax:       *LAP

.lap_cmd
 lda #8                     \ set time-out
 sta time_out
 lda #3                     \ Load driver call number
 jmp generic_cmd            \ And it's technically nothing else than a version command :-)


.lapopt_cmd
 jsr skipspace1             \ forward Y pointer to first non-space character
 jsr read_cli_param         \ read parameter (option value) from command line
 cpx #&00                   \ test if parameter given, x will be > 0
 bne lapopt_param           \ jump if there is a parameter 
 lda #'1'                   \ write default value to heap
 sta heap
 lda #'2'
 sta heap+1
 lda #'7'
 sta heap+2
 lda #&0D
 sta heap+3
 bne do_lapopt              \ branch always
.lapopt_param
 ldx #0                     \ reset heap pointer
 jsr copy_to_heap           \ copy parameter to head (parameter block)
.do_lapopt
 lda #2                     \ set time-out
 sta time_out
 ldx #>heap                 \ load pointer to parameter block
 ldy #<heap
 lda #25                    \ Load driver call number
 jmp generic_cmd            \ And it's technically nothing else than a version command :-)
