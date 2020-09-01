\ Electron Wifi Sideway ROM
\ Settings, definitions and constants

\ (C)Roland Leurs 2020
\ Version 1.00 May 2020

            __ELECTRON__ = 1
            __ATOM__ = 0

			uart = &FC30            \ Base address for the 16C2552 UART B-port

            pagereg = &FCFF
            pageram = &FD00
			timer = &100            \ Count down timer, 3 bytes
			time_out = timer + 4    \ Time-out setting, 1 byte

            errorspace = &100       \ Some volatile memory area for generating error messages
            heap      = &900        \ Some volatile memory area for tempory storage
			strbuf    = &A00        \ Some volatile memory area for string buffer
            flashcode = &900        \ may overlap with heap and string buffer

            osrdch = &FFE0
            oswrch = &FFEE
            osasci = &FFE3
            osbyte = &FFF4
            osnewl = &FFE7
            line = &F2              \ address for command line pointer
            zp = &B0                \ workspace            

			save_a = zp+2           \ only used in driver, outside driver is may be used for "local" work
			save_y = zp+3           \ only used in driver, outside driver is may be used for "local" work
			save_x = zp+4           \ only used in driver, outside driver is may be used for "local" work
            pr24pad = zp+5
			paramblok = save_y

			data_counter = zp+6
            blocksize = zp+6
            load_addr = zp+8

			buffer_ptr = zp+9       \ buffer_ptr and data_pointer must be adjescent!
			data_pointer = zp+11    \ a.k.a. data length
            size = zp+11            \ indeed, same as data_pointer
            needle = zp+12          \ may overlap with data_pointer, 2 bytes
            datalen = zp+13         \ data length counter, 2 bytes
            crc = zp+15             \ calculated crc, 2 bytes
            servercrc = zp+17       \ received crc, 2 bytes
						
			mux_status  = &90
			mux_channel = &91     \ need 5 bytes!
			

ORG &8000-22         ; it's a sideway ROM service and it containts an ATM header
    
