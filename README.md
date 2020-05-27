# NortstarAdvantageUtilities
This repository contains a set of utilities to transfer files and floppy disk images between a PC and a Northstar Advantage computer. Additionally utilities are provided to make a boot image and to use soft sectored media by using an Arduino Sketch.

## History
Last year I started to restore my Northstar Advantage computer which I had kept all the years. After getting all working again I wanted to save the contents of my old disk to my PC, but I noticed that there are no really easy to use instructions or utilities to transfer files between the Advantage and a modern PC. 
Based on the work of Mike Douglas I then made Northstar Advantage specific routines for image and file transfer. Since hard sectored media are are really hard to get and some of my old floppy disks stopped working, I wrote an Arduino Sketch to emulated hard sectored media.
Combined with two utilities that you can load over the serial line to the Advantage you can format a disk (hard or soft sectored media) and create a boot image. With this tools everybody should be able to bring (new) software to his Northstar Advantage Computer.
