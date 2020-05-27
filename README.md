# Northstar Advantage Utilities
This repository contains a set of utilities to transfer files and floppy disk images between a PC and a Northstar Advantage computer. Additionally utilities are provided to make a boot image and to use soft sectored media by using an Arduino Sketch.

## History
Last year I started to restore my Northstar Advantage computer which I had kept all the years. After getting all working again I wanted to save the contents of my old disk to my PC but I noticed that there are no really easy to use instructions or utilities to transfer files between the Advantage and a modern PC. 
Based on the work by Mike Douglas I then made Northstar Advantage specific routines for image and file transfer. Since hard sectored media are are really hard to get today and some of my old floppy disks stopped working I wrote an Arduino Sketch to emulated hard sectored media.
Combined with two utilities which you can load over the serial line to the Advantage you can format a disk (hard or soft sectored media) and create a boot image. With this tools everybody should be able to bring (new) software to his Northstar Advantage Computer.

This repository contains a directory for each of the tools. Each of the directories contains all necessary files as well as a PDF with detailed instructions how to use them. The files are in most cases the source code and generated files (HEX, PRN and COM files).

## Image transfer
The howto contains detailed instructions for connecting the Advantage to a PC over the serial line and how to transfer files and images. This directory contains Northstar Advantage the specific versions of image transfer utilities **ADV2PC.COM** and **PC2ADV.COM**. These programs are based on the FLOP2PC.COM and PC2FLOP.COM routines by Mike Douglas. But because ADV2PC.COM and PC2ADV.COM are using CP/M BIOS calls to read and write disks you need a working CP/M system to use them. The transfer utilities use the standard NSI format so that you can use all images which are available for the Advantage over the internet. 

## PCGET / PCPUT
The **PCGET.COM** and **PCPUT.COM** utilities are also Northstar Advantage specific versions of Mike Douglas programs. You can uses them to transfer single files of any file format. 

## BOOT2ADV
If you have no running CP/M system but suitable formated hard sectored media you can use **BOOT2ADV.COM** to create a CP/M boot disk. This directory contains a small loader programm that you can type into the Mini Monitor of the Advantage. This loader program transfers and starts the boot image creation program.

## FORM2ADV
If you don't have a formated disk as starting point you can load **FORM2ADV.COM** to load the Northstar Advantage formatter program over the serial line. Again you start with typing in the small loader program.

## SectorPulseGenerator
All utilities so far work on a standard Nothstar Advantage computer. But since it is difficult to get hard sectored media you find in this directory an Arduino program and instructions how to read and write soft sectored media on a hard sectored system like the Northstar Advantage. **SectorPulseGenerator.ino** can be used to generate the necessary hard sector pulses to use soft sectored media. Only a few easy modifications to the floppy disk cable are necessary. The howto describes how to modify an IBM floppy disk cable in order to keep all modifications reversible.

## Images 
This directory contains some example images that you can load with PC2ADV.COM. Here you find the image **DemoDiagnostic 2.0.0AQH.NSI** of the Demo/Diagnostic disk which came with each Advantage computer. Then you find **GrafikInterface.NSI** which contains an addtional CP/M layer to make the grafic capabilities of the Advantage better usable. This interface I wrote in the 80th as well as an Invader clone that you can find in the **Invader.NSI** image. As far as I know there were never commercial games published for the Northstar Advantage.   

May 2020
Holger Linning
