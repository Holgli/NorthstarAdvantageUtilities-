# Northstar Advantage Utilities
This repository contains a set of utilities to transfer files and floppy disk images between a PC and a Northstar Advantage computer. Additionally utilities are provided to make a boot image and to use soft sectored media by using an Arduino Sketch.

## History
Last year I started to restore my Northstar Advantage computer which I had kept all the years. After getting all working again I wanted to save the contents of my old disk to my PC, but I noticed that there are no really easy to use instructions or utilities to transfer files between the Advantage and a modern PC. 
Based on the work of Mike Douglas I then made Northstar Advantage specific routines for image and file transfer. Since hard sectored media are are really hard to get and some of my old floppy disks stopped working, I wrote an Arduino Sketch to emulated hard sectored media.
Combined with two utilities that you can load over the serial line to the Advantage you can format a disk (hard or soft sectored media) and create a boot image. With this tools everybody should be able to bring (new) software to his Northstar Advantage Computer.

The repository contains a directory for each of the tools. Each of the directories contains all necessary files as well as a PDF with detailded instructions how to use them. This are in most cases the Assembler Source, the HEX and PRN File and the generated COM file.

## Image transfer
The howto contains detailed instructions for connecting the Advantage to a PC over the serial line and how to transfer files and images. This directory contains Northstar Advantage specific versions image transfer utilities **ADV2PC.COM** and **PC2ADV.COM**. These programs are based on the FLOP2PC.COM and PC2FLOP.COM routines of Mike Douglas. But because they are using CP/M BIOS calls you need a working CP/M system to use them. The transfer utilities use the standard NSI format so that you can use the images which are available over the internet. 

## PCGET / PCPUT
The **PCGET.COM** and **PCPUT.COM** utilities are also Northstar Advantage specific versions of Mike Douglas programs. You can uses them to transfer single files of any file format. 

## BOOT2ADV
If you have no running CP/M system but a suitable formated hard sectored media you can use **BOOT2ADV.COM** to create a CP/M boot disk. This directory contains a small loader programm that you can type into the Mini Monitor of the Advantage. This loader program transfers and starts the boot image creation program.

## FORM2ADV
If you don't have a formated disk as starting point you can load **FORM2ADV.COM** to load the Northstar Advantage formatter program over the serial line. Again you start with typing in the small loader program.

## SectorPulseGenerator
All utilities so far work on a standard Nothstar computer. But since it is difficult to get hard sectored media you find in this directory an Arduino program and instructions how to read and write soft sectored media on a hard sectored system like the Northstar Advanatge. **SectorPulsGenerator.ino** can be used to generate the necessary hard sector pulses to use soft sectored media. Only a few easy modifications to the floppy disk cable arr necessary. The how-to describes how to modify an IBM floppy disk cable in order to keep all medifications reversible.

## Images 
This directory contains some example images that you can load with PC2ADV.COM. Here you find the image **DemoDiagnostic 2.0.0AQH.NSI** of the Demo/Diagnostic disk which came with each Advantage computer. Then you find a  

