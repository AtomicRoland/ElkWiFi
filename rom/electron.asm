\ Electron Wifi Sideway ROM
\ Settings, definitions and constants

\ (C)Roland Leurs 2020
\ Version 1.00 May 2020

            __ELECTRON__ = 1
            __ATOM__ = 0

			uart = &FCF0            \ Base address for the 16C2552 UART B-port

            pagereg = &FCFF
            pageram = &FD00
            errorspace = &100       \ Some volatile memory area for generating error messages
            heap    = &900          \ Some volatile memory area for tempory storage
			strbuf  = &A00          \ Some volatile memory area for string buffer

            osrdch = &FFE0
            oswrch = &FFEE
            osasci = &FFE3
            osbyte = &FFF4
            osnewl = &FFE7
            line = &F2              \ address for command line pointer
            zp = &A8                \ workspace            

			timer = zp+2
			time_out = zp+5
			data_counter = zp+6
            blocksize = zp+6
            load_addr = zp+8
			buffer_ptr = zp+9       \ buffer_ptr and data_pointer must be adjescent!
			data_pointer = zp+11    \ a.k.a. data length
            size = zp+11            \ indeed, same as data_pointer
            needle = zp+12          \ may overlap with data_pointer
			save_a = zp+14          \ only used in driver, outside driver is may be used for "local" work
			save_y = zp+15          \ only used in driver, outside driver is may be used for "local" work
			save_x = zp+16          \ only used in driver, outside driver is may be used for "local" work
            pr24pad = zp+17
            error_nr = zp+18
            nomon = zp+19
            datalen = zp+20
			
			paramblok = save_y
			
			mux_status  = zp+22
			mux_channel = zp+23     \ need 5 bytes!
			

ORG &8000-22         ; it's a sideway ROM service and it containts an ATM header
    
