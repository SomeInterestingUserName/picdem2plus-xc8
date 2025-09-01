# picdem2plus-xc8
PIC18 Assembly Source Code for the demo on the Microchip PICDEM2+ Development board

## Overview
This repository contains source code for the PICDEM2+ demo program, intended for the PIC18F452. I found the original source code from Microchip (originally written in 2002!) and migrated it to the modern XC8 assembler. The repo contains the following folders:
* `picdem2plus_orig`: The original PICDEM2+ 18F452 demo modernized as faithfully as possible.
* `picdem2plus_new`: An improved version of the program with bug fixes, improved serial printing, and, for the first time in 23 years, a brand-new demo for the (in my opinion) much-underutilized LEDs
  * There's also an easter egg that can be revealed by doing a certain action when the program starts...can you figure it out from the source code? :)

This project was based on source code from:
* The original PIC18F452 demo: http://ww1.microchip.com/downloads/en/DeviceDoc/Sample.zip ([Archive](https://web.archive.org/web/20200910155654/http://ww1.microchip.com/downloads/en/DeviceDoc/Sample.zip))
* An updated version for the PIC18F4520: https://ww1.microchip.com/downloads/aemDocuments/documents/OTH/ProductDocuments/CodeExamples/PICDEM2PlusRoHSlcd.zip ([Archive](https://web.archive.org/web/20240917192634/https://ww1.microchip.com/downloads/aemDocuments/documents/OTH/ProductDocuments/CodeExamples/PICDEM2PlusRoHSlcd.zip))

## Running the Demo
I doubt many people would still have one of these boards and the necessary tools to program it, but on the off chance you do, here's what you need:
1. The original red PICDEM2+ board. The green and black boards are newer revisions and are incompatible.
2. A 9V battery or a 9V DC barrel jack power supply (This board is power-hungry and your debugger might not be able to supply enough current)
3. MPLAB X IDE
4. Either a universal programmer or a compatible PIC debugger.
    1. If you really want to get era-appropriate, you'll need something like an MPLAB ICD3 that plugs into the RJ11-style debug connector.
5. (optional) A serial port or a USB-serial adapter set to 9600 baud
    1. RC6 is TX (from the PIC to your computer)
    2. RC7 is RX (from your computer to the PIC)

Once you have those:
1. Create a new MPLAB X project. You can name it whatever you like. Make sure to configure the hardware settings for your debugger, or leave it empty if you're using a universal programmer. Set the target device to PIC18F452.
2. After creating the project, right-click **Source Files** then select **Add Existing Item...** and add all three assembly files from one of the folders in this repo. You can either copy them into your project or simply let MPLAB X IDE link to them, it shouldn't matter which you select.
3. Build the project. It built successfully for me using MPLAB X IDE 6.20 and 6.25 on Debian, with the pic-as 3.0 assembler.
4. Once built, you can use the debugger to load the files for you, or drag the hex file from `dist/default/debug` (may also be `production` depending on build config) into your programmer of choice.
5. Power up and enjoy the demo

## Your Questions Answered
### Why though?
You're right to ask why one might embark on such an arduous and ultimately quite frivolous undertaking. The demo board is so old that the two newer versions meant to replace it have themselves been obsolete for years by now. And while amazingly still in active production, the 18F452 is a veritable dinosaur compared to modern offerings. But ultimately this project served three purposes:
1. Get the original PICDEM2+ demo flashed onto original hardware
2. Learn how to program in assembly on a new (to me) architecture
3. Learn how to reverse-engineer an existing assembly program and update it to modern tooling

### But still...why though?
Ok ok, you got me. I really just did it out of curiosity to get a taste of how embedded programming used to be (or as close as I could get on my modern system). I've concluded that I quite like my modern toolchains and debuggers, and I won't complain about them again (at least for now)

### How many times did bank switched memory cause a debugging headache?
Too many times to count. Until I realized all the variables fit in the access bank and I could do away with that altogether.
