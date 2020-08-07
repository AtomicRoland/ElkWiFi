\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Get interface configuration. This is a very basic version.....
\ Version 1.00


.ifcfg_cmd
 lda #2                     \ set time out
 sta time_out
 lda #18                    \ Load driver call number
 jmp generic_cmd            \ And it's technically nothing else than a version command :-)
