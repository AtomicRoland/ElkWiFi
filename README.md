# Introduction

This project is a WiFi interface module for the Acorn Electron. It's a cartridge that fits into a Plus-1 socket. The cartridge contains a ROM for the necessary drivers and utility commands. There's also 128 kB paged RAM available for buffering and storing incoming data. The WiFi is handled by the famous ESP8266 module. This is controlled by a dual UART 16C2552.

# WARNINGS

## 1. Security
The Acorn Electron is in no way a secure device, nor is the software for the WiFi module. When using the commands or driver, usernames and passwords may be kept in memory.

## 2. Baud rate changes may brick the ESP8266
The default transmission speed for the ESP8266 is 115,200 baud. The Electron can handle data transfers at this speed. Do not try to change this speed because the ESP8266 might accept your command but does not always perform it correctly. You might end up with a module that communicates at an unknown serial speed. The only remedy to fix that is to flash the device (or replace it, after all, they cost only about £1.00).

# COMPATIBILITY

This cartridge is tested with an Acorn Electron and a standard Acorn Plus-1 expansion module. It is also tested with an Acorn Plus-1 and a Pres Plus-1 ROM. Both configurations work perfectly.

*Known issues:*
 * With a Pres AP6 ROM in a Plus-1 there is a slight corruption on the screen after a hard reset. The cartridge still works as expected.
 * The CPLD is configured to detect whether it is installed in a BBC Master computer. The software is written without using  Electron specific hardware and functions so it is expected to work in a BBC Master. However, this is not tested yet.
 * Neither is any compatibility tested with a disc system, the Tube and Econet interface. They probably won’t work correctly together.
 * This board clashes also with the AP5 extension for the Electron as both boards drive (part of) page &FC and page &FD.

# Useful commands

DATE			display date
IFCFG	  	display network information
JOIN			connect to a wireless network
LAP			  get a list of access points
LAPOPT		set options for lap command
LEAVE	  	disconnect from current network
MODE		  select operating mode
PRD			  dump contents of paged ram
REWIND		reset UEF pointer
TIME			display current time
UPDATE		check for updates
VERSION	  display firmware information
WGET		  retrieve a file from the Internet
WICFS		  Activate WiCFS
WIFI			interface control


# Support

More information can be found in the manual in the doc directory. Please post your questions, remarks, compliments etc on the StarDot forum at https://stardot.org.uk/forums.
