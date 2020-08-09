\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Get interface configuration. This is a very basic version.....
\ Version 1.00

\ Syntax:       *IFCFG

.ifcfg_cmd
 lda #18                    \ Load driver call number
 jmp generic_cmd            \ And it's technically nothing else than a version command :-)
