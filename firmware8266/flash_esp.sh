#!/bin/bash
esptool.py --port /dev/ttyUSB0 write_flash -fm qio 0x00000 v1.3.0.2_AT_Firmware.bin
