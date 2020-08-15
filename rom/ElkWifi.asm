\ Sideway ROM for Electron Wifi board
\ (c) Roland Leurs, May 2020

\ Main service ROM
\ Version 1.00


include "electron.asm"

.atmheader          equs "elkwifi.rom",0,0,0,0,0
                    equw &1800                  \ during development we'll load at &1800
                    equw &1800
                    equw romend-romstart

\ Rom header
.romstart           equb 0                      \ It's not a language ROM
                    equb 0
                    equb 0
                    jmp service                 \ Jump to service entry point
                    equb &82                    \ ROM type byte: service rom
                    equb (copyright-romstart)   \ Offset to copyright string
                    equb &00                    \ version 0.0x
.romtitle           equs "Electron Wifi"
                    equb 0
.romversion         equs "0.12"                 \ Rom version string
.copyright          equb 0                      \ Copyright message
                    equs "(C)2020 Roland Leurs"
                    equb 0

\ Command table
.commands           equs "IFIW"                 \ Just a test

\ Service handling code, A=reason code, X=ROM ID, Y=data
.service            cmp #4                      \ is reason an unknown command?
                    beq command                 \ if so, go search for command
                    cmp #9                      \ is reason a cry for help?
                    beq help                    \ if so, show some help text
                    cmp #1                      \ is reason an autoboot call?
                    bne notboot                 \ if not then goto not boot
                    jmp autorun                 \ go to autorun (initialize)
.notboot            cmp #8                      \ unknown OSWORD call
                    bne notosword               \ if not then goto not osword
                    jmp osword65                \ jump to OSWORD handler
.notosword          rts                         \ other reason, not for me, carry on

\ This routine searches the service roms command table for the command on the command line. The
\ command may be abbreviated with a dot. If the command is not in the table then this routine
\ will exit with the registers restored.
\ This routine comes from the ATOM GDOS 1.5 sources. Credits go to Gerrit Hillebrand. 

.command            tya                         \ save X and Y registers, we don't save the A because
                    pha                         \ the exit value of A depends on the command.
                    txa
                    pha
                    ldx #&FF                    \ load index register, one byte before command table
                    cld                         \ clear decimal flag
.command_x4         ldy #0                      \ reset Y pointer to beginning of command line
                    jsr skipspace               \ forward Y pointer to first non-space character
                    dey                         \ set pointer to beginning of command
.command_x2         iny                         \ increment pointer
                    inx                         \ increment index
\ The search routine compares all the commands in the table with the command on the command line.
.command_x5         lda commandtable,x          \ load character from command table
                    bmi command_x1              \ jump if negative (i.e. end of command, high byte of start address)
                    cmp (line),y                \ compare with character on command line
                    beq command_x2              \ jump if equal
\ There was a character read that is not in the current command. Either it is abbreviated or it's
\ another command. In both cases, increment the X index to the end of the command in the table. X points
\ to the (possible) start address of the command.
                    dex                         \ decrement index
.command_x3         inx                         \ increment index
                    lda commandtable,x          \ read character
                    bpl command_x3              \ jump if not end of command
                    inx                         \ increment index
                    lda (line),y                \ read character from command line
                    cmp #'.'                    \ is it a dot (abbreviated command)?
                    bne command_x4              \ jump if not a dot
                    iny                         \ increment pointer (Y points now directy after the command)
                    dex                         \ decrement index
                    bcs command_x5              \ continue with the next command in the table. 
.command_x1         sta zp+1                    \ set in workspace
                    lda commandtable+1,x        \ load low byte of command start
                    sta zp                      \ set in workspace
                    jmp (zp)                    \ go and execute the command
.command_x6         pla                         \ restore registers
                    tax
                    pla
                    tay
                    lda #4                      \ restore reason code
                    rts                         \ end of service

\ Help routine. If there is no keyword then this only prints the version string and the keyword that
\ it responds to. When the keyword is WIFI then it will print a list of commands with a short description.
.help               tya                         \ save X and Y registers, we don't save the A because
                    pha                         \ the exit value of A depends on the command.
                    txa
                    pha
                    lda (line),y                \ read character from command line
                    cmp #&D                     \ is it end of line?
                    beq help_l2                 \ yes it is, print title and version
                    ldx #3                      \ load keyword length
.help_l1            lda (line),y                \ read next character from keyword
                    cmp commands,x              \ compare with my keyword
                    bne help_l3                 \ if not equal then it's not me
                    iny                         \ increment command pointer
                    dex                         \ decrement keyword pointer
                    bpl help_l1                 \ read next character
                    jsr print_help              \ it's me, do something
                    jmp call_claimed            \ claim call and end
\ There was no additional keyword on the command line, print title                    
.help_l2            jsr help_version            \ print title and version
                    jsr printtext               \ print keyword to respond
                    equb &D,&20,&20
                    equs "WIFI",&D,&EA
.help_l3            pla                         \ restore registers
                    tax
                    pla
                    tay
                    lda #9                      \ restore reason code
                    rts                         \ pass on call

\ This routine initializes the rom and the hardware. It is the response to reason code &01 since reason
\ code &03 might be claimed by another higher priority rom. To avoid my banner being printed before the operating
\ system banner, this is suppressed and replace by my own banner.
.autorun            tya                         \ save X and Y registers, we don't save the A because
                    pha                         \ the exit value of A depends on the command.
                    txa
                    pha
                    lda #&D7                    \ Turn off default banner
                    ldx #0
                    stx pagereg                 \ reset page register to 0
                    stx mux_status              \ disable multiplexing
                    ldy #&7F
                    jsr osbyte
                    jsr printtext               \ print the following text
                    equs "Acorn Electron WiFi",&EA
                    ldy #&FF                    \ get last reset type
                    ldx #&00
                    lda #&FD
                    jsr osbyte
                    cpx #0                      \ test for soft reset
                    beq autorun_l1
                    lda #7                      \ ring the bell on power on and hard reset
                    jsr oswrch
.autorun_l1         jsr print_logo              \ print the logo if wifi is enabled
                    jsr printtext               \ perform new line
                    equb &D,&D,&EA
                    pla                         \ restore registers
                    tax
                    pla
                    tay
                    lda #1                      \ restore reason code
                    rts                         \ end of routine

\ Command table

.commandtable       equs "WGET"
                    equb >wget_cmd, <wget_cmd
                    equs "WIFI" 
                    equb >wifi_cmd, <wifi_cmd 
                    equs "VERSION"
                    equb >version_cmd, <version_cmd
                    equs "LAPOPT"
                    equb >lapopt_cmd, <lapopt_cmd
                    equs "LAP"
                    equb >lap_cmd, <lap_cmd
                    equs "IFCFG"
                    equb >ifcfg_cmd, <ifcfg_cmd
                    equs "DATE"
                    equb >date_cmd, <date_cmd
                    equs "TIME"
                    equb >time_cmd, <time_cmd
                    equs "PRD"
                    equb >pdump_cmd, <pdump_cmd
                    equs "JOIN"
                    equb >join_cmd, <join_cmd
                    equs "LEAVE"
                    equb >leave_cmd, <leave_cmd
                    equs "MODE"
                    equb >mode_cmd, <mode_cmd
                    equs "UPDATE"
                    equb >update_cmd, <update_cmd
                    equb >command_x6, <command_x6
                    

\ This routine prints the version and title string for the *HELP command
.help_version       ldx #0                      \ load pointer
.help_vl1           lda romtitle,x              \ load character
                    bne help_vl2
                    lda #&20                    \ replace &00 character by a space
.help_vl2           jsr osasci                  \ print the character
                    inx                         \ increment pointer
                    cpx #(copyright-romtitle)   \ test end of title
                    bne help_vl1                \ if not, get another character
                    rts                         \ return

\ This routine prints the help text for WIFI
.print_help         jsr help_version            \ print title and version
                    jsr printtext               \ print this text
                    equb &0D
                    \ 40 "----- This string is 40 characters -----"
                    equs " DATE      Print current date",&0D
                    equs " IFCFG     Print IP and MAC address",&0D
                    equs " JOIN      Join a network",&0D
                    equs " LAP       List access points",&0D
                    equs " LAPOPT    Set LAP options",&0D
                    equs " LEAVE     Disconnect from network",&0D   
                    equs " MODE      Set device mode",&0D
                    equs " PRD       Paged Ram Dump",&0D
                    equs " TIME      Print current time",&0D
                    equs " UPDATE    Install ElkWifi ROM update",&0D
                    equs " VERSION   Print firmware version",&0D
                    equs " WGET      Get a file from a webserver",&0D
                    equs " WIFI      WiFi controle ON|OFF|HR|SR",&0D
                    nop
.print_help_end     rts 

\ OSWORD &65 is a direct call to the WIFI driver so user applications can use
\ the driver as well. OSWORD is always called with the call number at &EF and
\ the X and Y registers in &F0 and &F1. The X and Y should point to an address
\ where the parameters are stored.
\ All the registers might be modified after OSWORD &65 is called.
.osword65           lda &EF                     \ load OSWORD number
                    cmp #&65                    \ compare with &65
                    beq osword65_l1             \ jump if it's my call
                    lda #8                      \ it is not mine, so continu with unmodified A
                    rts
.osword65_l1        tya                         \ save X and Y registers, we don't save the A because
                    pha                         \ the exit value of A depends on the command.
                    txa
                    pha
                    ldy #0                      \ reset the index register
                    lda (&F0),y                 \ load the A value
                    pha                         \ save on stack
                    iny                         \ increment index
                    lda (&F0),y                 \ load the X value
                    tax                         \ transfer to X register
                    iny                         \ increment index
                    lda (&F0),y                 \ load the Y value
                    tay                         \ transfer to Y register
                    pla                         \ restore A (= function number)
                    jsr wifidriver              \ execute the wifi function
                    jmp call_claimed            \ return from OSWORD call

include "routines.asm"
include "errors.asm"
include "serial.asm"
include "driver.asm"
include "version.asm"
include "time.asm"
include "lap.asm"
include "ifcfg.asm"
include "wificmd.asm"
include "pdump.asm"
include "join.asm"
include "mode.asm"
include "wget.asm"
include "update.asm"

equs "This is the end!"

align &100  
.flashsrc
incbin "flash.bin"

skipto &C000
.romend             

SAVE "elkwifi.rom", atmheader, romend
SAVE "bbcwifi.rom", romstart, romend
