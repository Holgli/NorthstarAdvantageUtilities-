;******************************************************************************
;
;  
;  Boot2Adv - Transfer disk image from PC to a NortStar Advantage using
;             a SIO board in port 1 or 2 after this program has been loaded
;             to memory by using the Mini Monitor of the Advantage (see
;             LOADER.ASM). 
;
;       This program is a PC2Flop-like program. It borrows much of the 
;       ideas and the code of these programs written by Mikle Douglas. 
;
;       - use BIOS code of Northstar Graphics CP/M
;       - reuse code of PC2Adv.ASM as much as possible
;       - write raw data of double sided double density disk in drive A or B
;         (512 bytes per sector, 10 sectors per track, 70 tracks). 
;       - use SIO board in port 1 or port 2 for the transfer of a disk image 
;         using the XMODEM protocol. The disk image is the linear sequence 
;         of the 512 byte sectors from track 0, sector 0 through 
;         track 69, sector 9
;
;       This program only runs standalone. Use MLAOD.COM to create BOOT2ADV.COM.
;
;       Written by Holger Linning
;
;       Rev      Date       Desc
;       1.0     01/23/20    Original 
;
;  based on:
;
;
;  PC2Flop - Transfer disk image from PC to floppy over serial port
;            using the IMSAI SIO-2 serial board and the North Star
;            single density floppy controller.
;
;       This program writes a North Star single density disk from a disk image
;       transmitted from a PC. The image is transmitted through a serial port
;       using the XMODEM checksum protocol. The image is written directly to
;       the floppy in raw format (256 bytes per sector, 10 sectors per track,
;       35 tracks). The disk image is the linear sequence of 256 byte sectors
;       from track 0, sector 0 through track 34 sector 9.
;
;       This program runs standalone at 0x100 or under CP/M.
;
;       Written by Mike Douglas
;
;       Rev      Date       Desc
;       1.0     09/22/19    Original
;
;*****************************************************************************


TRUE    equ     0ffffh          ;define value of true 
FALSE   equ     NOT TRUE        ;define value of false 

;*****************************************************************************
;
;  Switch for running under Advantage emulator ADE or not 
;   
;     see: North Star Advantage Z80 Computer Emulator (ADE) 
;          Jack Strangio
;          http://www.itelsoft.com.au/north_star_advantage_emulator.html
;
;  The emulator can be used for testing and debugging this program. If
;  runnuing under ADE set the directive to TRUE.
;
;*****************************************************************************

ADE     equ     FALSE           ;TRUE = ADE, FALSE = real Machine


;*****************************************************************************
; Disk information equates

NUMTRK  equ     70              ;number of tracks
NUMSEC  equ     40              ;number of sectors per track (logical CPM sectors)
SECLEN  equ     128             ;sector length (logical CPM sectors)
MINDRV  equ     0               ;first drive number
MAXDRV  equ     1               ;max drive number 

TRKLEN  equ     (NUMSEC*SECLEN) ;length of track in bytes

; BIOS jump table entry points
BIOSEntry  equ  0ed00h          ;start od BIOS
BOOT    equ     00h             ;Cold start 
WBOOT   equ     BOOT+3          ;Warm boot
CONST   equ     BOOT+6          ;Console status
CONIN   equ     BOOT+9          ;Console input
CONOUT  equ     BOOT+12         ;Console output
LIST    equ     BOOT+15         ;Printer output
PUNCH   equ     BOOT+18         ;Paper tape punch output
READER  equ     BOOT+21         ;Paper tape reader input
HOME    equ     BOOT+24         ;Move disc head to track 0
SELDSK  equ     BOOT+27         ;Select disc drive
SETTRK  equ     BOOT+30         ;Set track number
SETSEC  equ     BOOT+33         ;Set sector number
SETDMA  equ     BOOT+36         ;Set DMA address
READ    equ     BOOT+39         ;Read a sector
WRITE   equ     BOOT+42         ;Write a sector

; XMODEM equates
        IF      NOT ADE
SOH     equ     001h
EOT     equ     004h
ACK     equ     006h
NAK     equ     015h
        ENDIF

        IF      ADE
DUMMY   equ     0ffh
SOH     equ     DUMMY           ;use dummy values for XMODEM            
EOT     equ     DUMMY           
ACK     equ     DUMMY
NAK     equ     DUMMY
        ENDIF

PKTLEN  equ     128             ;128 byte xmodem packet length
XMTRIES equ     10              ;number of xmodem retries

; character equates
CR      equ     13              ;ascii for carriage return
LF      equ     10              ;ascii for line feed
DEL     equ     7Fh             ;ascii DEL
BS      equ     08h             ;ascii backspace
CTRLC   equ     03              ;ascii for control-c
CRSHOME equ     1eh             ;cursor home
CLRSCR  equ     0fh             ;clear screen


BIAS    equ     0c000h          ;Start of ram after boot 
START   equ     00080h          ;load address of program (+0c00h)

        IF NOT ADE              ;loading over serial only on real machine

;-----------------------------------------------------------------------------
;  Prepare start of Boot2Adv
;  Boot2Adv has been loaded to 0c080H before, loader program was typed in
;  at 0c000h. 
;  If using ADE this programm can run under CP/M.
;-----------------------------------------------------------------------------
        org     START   

        ;map memory
        mvi     a,1 
        out     0a0h            ; page 1 to A0 
        mvi     a,2               
        out     0a1h            ; page 2 to A1
        mvi     a,3               
        out     0a2h            ; page 3 to A2

        ;move program to first memory page
        lxi     d,init          ;DE = destination of copy 
        lxi     h,init + BIAS   ;HL = start of copy
        lxi     b,BiosDataEnd - init ;count of bytes
        dw      0b0edh          ;LDIR = copy memory

        ;clear parity erros
        mvi     a,2
        out     060h            ;clear parity errors, disable interrupts 
        
        jmp     init;           ;jump to start address 00100h

        ;fill space
        ds      init - $ + START

        ENDIF
        
        org     0100h   

        IF ADE                  ;clear memory to simulate boot
        xra     a
        lxi     h,BiosDataEnd+1
	lxi     d,BiosDataEnd+2
	lxi     b,0ffffh - BiosDataEnd+3
	mov     m,a
        dw      0b0edh          ;LDIR
        ENDIF

;-----------------------------------------------------------------------------
;  Initialize for transfer
;-----------------------------------------------------------------------------
init    lxi     sp,ourStk       ;initialize stack pointer
        call    restoreBios     ;restore BIOS

        call    setDrvN         ;set drive names 
        call    sizeRam         ;determine amount of RAM available
        mvi     a,MINDRV        ;a=default drive
        sta     drvNum          ;need for pgmExit

        IF      ADE
        lxi     h,0000h
        shld    helpVal         ;init help var for debugging
        ENDIF


;  Display welcome message, then get the drive number and port number
;    to use for the transfer from the operator.

        lxi     h,mWelcom       ;display welcome message
        call    dispMsg

; getDrv - get drive letter from the user.

getDrv  lxi     h,mDrive        ;display drive number prompt
        call    dispMsg
        call    rcvCon          ;get byte from the console
        ori     20h             ;upper case letters to lower case
        cpi     'x'             ;exit requested?
        jz      pgmExit         ;yes
        lxi     h,baseDrv       ;ascii 1st drive - baseDrv = 0
        sub     m
        jm      getDrv          ;error, entry was < first drive
        cpi     MAXDRV-MINDRV+1 ;validate <= max drive
        jnc     getDrv          ;invalid, prompt again
        adi     MINDRV          ;restore offset of 1st drive (if any)
        sta     drvNum          ;save the drive number to use

        call    dRestor         ;restore to track 0 (selects drive)

; getPort - get serial port number 1-2 from the user.

getPort lxi     h,mPort         ;display transfer port prompt
        call    dispMsg
        call    rcvCon          ;get byte from the console
        ori     20h             ;upper to lower case, nums not affected
        cpi     'x'             ;exit requested?
        jz      pgmExit         ;yes
        sui     '1'             ;'1' to 0
        cpi     2               ;validate input was '1' or '2'
        jnc     getPort         ;invalid, prompt again
        sta     xfrPort         ;save the port to use

        call    initPort        ;initialize serial port 

; Prompt the user to insert the disk to write, initialize, then start
;   sending NAK to start the XMODEM reception.

        lxi     h,mStart        ;display start file transfer prompt
        call    dispMsg
        
        xra     a               ;init track counter
        sta     curTrk          ;start with track 0
        
        inr     a               ;init xmodem block number to one
        sta     blkNum

        mvi     a,NAK           ;send starting nak after purging input data
        call    purgSio         

;-----------------------------------------------------------------------------
;  mainLp - Receive as many packets as will fit into RAM and then write
;      tracks to disk. Repeat until entire disk is written. 
;-----------------------------------------------------------------------------
mainLp  lxi     h,mRecv         ;display "Receiving"    
        call    dispMsg
        
        call    initBf          ;init buffering 
        
        call    bufPkts         ;buffer as many packets as possible

        lhld    rcvPtr          ;hl=start of last packet received
        xchg                    ;de=start of last packet received
        lxi     h,trkBuf        ;hl=start of track buffer
        call    cmpDeHl         ;compare last packet start - trkBuf
        jc      allDone         ;nothing received but an EOT

        lxi     h,mWrite        ;display "Writing"      
        call    dispMsg

; trkLoop - write tracks until all disk tracks have been written or all
;    the tracks in the buffer have been written.

trkLoop call    wrtTrak         ;write a track

        lda     wrtTrk          ;increment written tracks in buffer 
        inr     a
        sta     wrtTrk  

        call    setNTrk         ;set next track (return in a)

        cpi     NUMTRK          ;done all tracks?
        jz      allDone         ;yes
        
        call    getEndB         ;hl=end of written tracks in buffer
        xchg                    ;de=next track pointer
        lhld    rcvPtr          ;hl=start of last packet received
        call    cmpDeHl         ;compare end of buffer - rcvPtr

        jc      trkLoop         ;another track is present

        lda     eotFlag         ;see if EOT terminated the reception
        cpi     EOT     
        jz      allDone         ;if so, probably a single side disk
        mvi     a,ACK           ;ACK the last packet or EOT
        call    sndByte
        jmp     mainLp          ;go receive more packets

; allDone - The disk is completely written. ACK the final packet (or EOT),
;     display the "transfer complete" message and start the program over.

allDone mvi     a,ACK           ;ACK the final packet or EOT
        call    sndByte
        lxi     h,mDone         ;hl->done message
        call    dispMsg
        jmp     getDrv          ;start over asking for drive num

;-----------------------------------------------------------------------------
; bufPkts - Receive XMODEM packets until we fill all the track buffer
;   space available. Reception starts at the address pointed to by
;   rcvPtr. Reception is stopped when the last packet exactly
;   fills the end of the last track spot in RAM. rcvPtr is
;   updated on exit to point to the start of the last packet received.
;   The disk write routines use this pointer to know where data ends and
;   then update rcvPtr to start to where to begin receiving new packets.
;-----------------------------------------------------------------------------
bufPkts lhld    rcvPtr
        call    rcvPkt          ;receive a packet (Pointer to buffer in HL) 

        push    h
        call    dispPgs         ;show progress
        pop     h

        xchg                    ;de=current xmodem receive pointer
        sta     eotFlag         ;save status returned (may be EOT)
        cpi     EOT             ;EOT received?
        jz      bufDone         ;yes, buffering is done
        lhld    bufEnd          ;hl=end of buffering space
        call    cmpDeHl         ;compare current-end    
        jnc     bufDone         ;past or at end, buffering is done
        mvi     a,ACK           ;otherwise, ACK the packet
        call    sndByte
        xchg                    ;put xmodem rcv pointer back in HL
        jmp     bufPkts         ;buffer some more

; bufDone - no more room for packets. Update rcvPtr to point to the 
;   start of the last packet received so the disk write routines know
;   where data ends.

bufDone shld    rcvPtr          ;save use by write tracks
        ret

;-----------------------------------------------------------------------------
; rcvPkt - receive an xmodem format 128 byte packet. HL points to the 128 byte
;    buffer to receive. HL is updated by 128 bytes after each succuessful
;    reception of a new 128 byte packet.
;-----------------------------------------------------------------------------

nakPkt  pop     h               ;get HL back
        mvi     a,NAK
        call    purgSio         ;purge receive for 1s then transmit NAK

;wait for SOH or EOT

rcvPkt  
        IF ADE                     ;fill buffer with dummy values
        push    h               ;save pointer
        lhld    helpVal;        ;load help value
        inx     h               ;increment to produce new value
        mov     a,l             ;use lower byte fo fill buffere
        shld    helpVal         ;save new helpVal
        pop     h               ;get pointer back
        mvi     b,PKTLEN        
dmmyLp  mov     m,a
        inx     h
        dcr     b    
        jnz     dmmyLp
        shld    rcvPtr          ;update pointer
        xra     a                  ;return a zero
        ret
        ENDIF
        
        push    h               ;save HL for retries
waitSoh call    chkQuit         ;check for user abort
        mvi     a,3             ;3 second timeout for soh
        call    rcvByte         ;receive character with timeout
        jz      nakPkt          ;timeout
        cpi     SOH             ;SOH received?
        jz      haveSoh
        cpi     EOT             ;EOT to say we're done?
        jnz     waitSoh         ;no, keep looking for SOH
        pop     h               ;undo the entry push
        ret                     ;return with EOT

;  Have SOH, receive block number and not block number

haveSoh mvi     a,1             ;one second timeout once inside a packet
        call    rcvByte         ;get the block number
        jz      nakPkt          ;timeout, NAK and start over
        sta     rcvBlk          ;save the received block number
        mvi     a,1             ;one second timeout
        call    rcvByte         ;get not block number
        jz      nakPkt          ;timeout, NAK and start over
        sta     rcvNBlk         ;save not block number

;  Receive the 128 byte block

        mvi     e,0             ;init checksum
        mvi     d,pktLen        ;d is byte counter
pktLoop mvi     a,1             ;one second timeout
        call    rcvByte         ;get next data byte
        jz      nakPkt          ;timeout
        mov     m,a             ;store the character
        inx     h               ;point to next byte
        add     e               ;update the checksum
        mov     e,a
        dcr     d               ;decrement bytes remaining
        jnz     pktLoop

;  Verify the checksum

        mvi     a,1             ;one second timeout
        call    rcvByte         ;get the checksum
        jz      nakPkt          ;timeout
        cmp     e               ;checksum match?
        jnz     nakPkt          ;no, packet error

;  Checksum good. Verify block numbers

        lda     rcvNBlk         ;verify rcvBlk = not (rcvNBlk)
        cma                     ;A should = block number now
        mov     b,a             ;save in b
        lda     rcvBlk
        cmp     b               ;compare rcvBlk = not(rcvNBlk)?
        jnz     nakPkt          ;no, error
        lda     blkNum          ;compare rcvBlk = expected blkNum
        cmp     b
        jnz     nakPkt          ;nak if not the same (also nak's re-send)
        inr     a               ;increment expected block number
        sta     blkNum
        pop     b               ;get HL off stack, but don't clobber HL
        xra     a               ;return a zero
        shld    rcvPtr          ;point to next block
        ret

;-----------------------------------------------------------------------------
; wrtTrak - write NUMSEC sectors to the current track in trkBuf
;   as pointed to by trkPtr. After the track is written, trkPtr is updated
;   by the length of a track to point to the next track buffer. 
;-----------------------------------------------------------------------------
wrtTrak lxi     h,mCRLF         ;new line for next blocks       
        call    dispMsg

        call    initT           ;init track writing 
        call    dSeek           ;seek to the track

; wrtLoop - write a full track starting sector 0

wrtLoop call    chkQuit         ;check for ctrl-c
        call    setSect         ;set desired sector 
        call    dWrite          ;write the sector
        call    dispPgs         ;show progress
        call    setNSec         ;set next sector 
        call    setOffs         ;set new offset in buffer
        lda     wrtSec
        dcr     a
        sta     wrtSec          ;decrement sectors to write
        jnz     wrtLoop         ;loop until all sectors written
        ret

;-----------------------------------------------------------------------------
; dispMsg - display the null-terminated message passed in hl on the
;    console device. Clobbers c, hl
;-----------------------------------------------------------------------------
dispMsg mov     a,m             ;get the next message byte
        ora     a               ;null terminates
        rz
        
        mov     c,a             ;CONOUT wants character in c
        mvi     e,CONOUT
        call    BIOS
        inx     h               ;move to next byte
        jmp     dispMsg

;-----------------------------------------------------------------------------
; dispPgs - display progress
;    Clobbers c
;-----------------------------------------------------------------------------
dispPgs mvi     c,'.'           ;CONOUT wants character in c
        mvi     e,CONOUT
        call    BIOS
        ret     

;-----------------------------------------------------------------------------
; rcvCon - Receive a character from the console device, echo it, then
;   wait for a CR. Exits program if Ctrl-c typed. Returns with invalid
;   character (null) if BS or DEL pressed after 1st character
;   Returns character in a, clobbers c.
;-----------------------------------------------------------------------------
rcvCon  mvi     e,CONIN
        call    BIOS            ;check for input

        ani     7fh
        cpi     CTRLC           ;abort requested?
        jz      pgmExit         ;yes

        cpi     CR              ;return pressed?
        rz                      ;yes, don't echo it

        mov     c,a             ;CONOUT needs character in c
        mvi     e,CONOUT
        call    BIOS            ;echo it

; Wait for CR, then return 1st character typed
rcvCr   mvi     e,CONIN
        call    BIOS            ;check for input

        ani     7fh
        cpi     CTRLC           ;abort requested?
        jz      pgmExit         ;yes

        cpi     DEL             ;delete
        rz                      ;yes, return DEL character

        cpi     BS              ;backspace?
        rz                      ;yes, return BS character
        cpi     CR              ;return pressed?

        jnz     rcvCr           ;no, keep waiting
        mov     a,c             ;return 1st character typed
        ret

;-----------------------------------------------------------------------------
; purgSio - Wait for 1 second of idle time on receive line, then transmit the
;       character passed in A (usually ACK or NAK). Clobbers b
;-----------------------------------------------------------------------------
purgSio push    a
purge   mvi     a,1             ;1 second timeout
        call    rcvByte         ;wait for 1 second without activity

        IF NOT ADE              ;wait only on real machine
        jnz     purge
        ENDIF

        pop     a               ;get back the character to send
                                ;fall through to sndByte
;-----------------------------------------------------------------------------
; sndByte - send the byte in a through the specified transfer port. 
;     Clobbers b. (assuming serOut clobbers only a).
;-----------------------------------------------------------------------------
sndByte mov     b,a             ;b=byte to transmit
        lda     xfrPort         ;a=port to use for transfer
        jmp     serOut          ;send the character

;-----------------------------------------------------------------------------
; rcvByte - Receive a byte from the specified transfer port. A wait timeout
;     in seconds is specified in a. If a timeout occurs, zero is returned in
;     a and the zero flag is true. Otherwise, the character is returned in a 
;     (could be zero) and the zero flag is false. ONESEC must be set based on
;     processor speed and the number of cycles in the serIn call + 59.
;     Clobbers a, b and c.
;-----------------------------------------------------------------------------
rcvByte push    d               ;save d, e
        mov     d,a             ;save timeout in d

initSec lxi     b,ONESEC        ;bc=cycles through this loop for 1s
rcvWait lda     xfrPort         ;(13) a=port to use for transfer
        call    serIn           ;(17+42) look for a byte
        jnz     haveChr         ;(10) byte received
        dcx     b               ;(5) otherwise, decrement timer
        mov     a,b             ;(5) one second expire?
        ora     c               ;(4)
        jnz     rcvWait         ;(10) no, keep waiting

; one second timeout has occured. Decrement the seconds counter.

        dcr     d               ;decrement seconds counter
        jnz     initSec         ;initialize for another 1 second count
haveChr pop     d               ;restore d, e
        ret

;--------------------------------------------------------------
; chkQuit - check for the user to request abort (ctrl-c). If
;    a character is present on the console port, read it and
;    see if ctrl-c. Clobbers A
;--------------------------------------------------------------
chkQuit mvi     e,CONST
        call    BIOS            ;check for console input
        cpi     00h             ;0 = no character
        rz
        
        ani     7fh
        cpi     CTRLC           ;abort requested?
        rnz                     ;no

; Ctrl-C typed while program is running. Return to drive prompt.

        lxi     sp,ourStk       ;initialize stack pointer
        jmp     getDrv          ;start over asking for drive num

;--------------------------------------------------------------
; pgmExit - Exit 
;--------------------------------------------------------------

; If drive was used, prompt user to insert disk

pgmExit lda     drvNum          ;boot drive used?
        sui     MINDRV
        jnz     noDisk          ;not 1, disk prompt not needed
        
        lxi     h,mBoot         ;display "insert boot disk"     
        call    dispMsg
        call    rcvCon          ;wait for a character
        
noDisk  lxi     h,mExit         ;display "exiting" message
        call    dispMsg
        
        lxi     h,BIOSEntry
        mvi     d,00h
        mvi     e,BOOT
        dad     d
        pchl                    ;boot

;--------------------------------------------------------------
; Change drive prompt message to show drive
; letters instead of drive numbers and change baseDrv to convert
; an 'A' to the base drive number (MINDRV).
;--------------------------------------------------------------

setDrvN mvi     a,'A'           ;'A' in drive message instead of number
        sta     mDrvMin
        adi     MAXDRV-MINDRV   ;max drive letter
        sta     mDrvMax
        mvi     a,'a'           ;ascii 1st drive - baseDrv = 0
        sta     baseDrv
        ret

;------------------------------------------------------------------
; sizeRam - determine how much RAM we have for buffering tracks.
;   Sets the bufEnd variable which points to end address of 
;   the last possible track buffer + 1
;------------------------------------------------------------------
sizeRam lxi     h,BIOSEntry     ;BIOS entry is end of usable memory

ramEnd  xchg                    ;de=end of RAM + 1
        mvi     a,-((TRKLEN SHR 8) + 1) AND 0ffh
        cmp     d               ;force de < (10000h - TRKLEN)
        jnc     topOk
        mov     d,a             ;limit max address
topOk   lxi     h,trkBuf        ;hl=start of track buffer
        lxi     b,TRKLEN        ;bc=length of track in bytes

; Loop increasing hl by TRKLEN until hl > end of RAM.

bfEndLp dad     b               ;hl=hl+track length
        call    cmpHlDe         ;compare hl-de
        jc      bfEndLp         ;still more room, keep going

; Subtrack one track length from hl, this will be the end address + 1 of
;   the the last track buffer that will fit in RAM

        lxi     b,-TRKLEN       ;subtract one track length
        dad     b               ;hl = end address of last track + 1
        shld    bufEnd          ;save as bufEnd
        ret

;--------------------------------------------------------------------
; cmHlDe - compare HL-DE. Carry set if HL<DE, carry clear if HL>=DE
;--------------------------------------------------------------------
cmpHlDe mov     a,l             ;compare HL-DE, do lsbs first
        sub     e
        mov     a,h             ;do msbs
        sbb     d
        ret                     ;carry set HL<DE, clear HL>=DE

;--------------------------------------------------------------------
; cmDeHl - compare DE-HL. Carry set if DE<HL, carry clear if DE>=HL
;--------------------------------------------------------------------
cmpDeHl mov     a,e             ;compare DE-HL, do lsbs first
        sub     l
        mov     a,d             ;do msbs
        sbb     h
        ret                     ;carry set DE<HL, clear DE>=HL

;--------------------------------------------------------------------
; subHlDe - HL=HL-DE
;--------------------------------------------------------------------
subHlDe mov     a,l             ;subtract HL-DE, do lsbs first
        sub     e
        mov     l,a             ;lsb result in l
        mov     a,h             ;do msbs
        sbb     d
        mov     h,a             ;msb result in h        
        ret
;-----------------------------------------------------------------------------
;   Data Area
;-----------------------------------------------------------------------------
mWelcom db      cr,lf,lf
        db      '===== PC to Northstar Advantage Boot Image Transfer v1.0 ====='
        db      cr,lf,lf        
        db      'This program writes a North Star Advantage floppy disk from'
        db      cr,lf
        db      'a boot image received through a serial port via XMODEM.',0

mDrive  db      cr,lf,lf,'Insert formatted floppy and specify destination drive ('
mDrvMin db      'x-'
mDrvMax db      'x) or X to exit: ',0

mPort   db      cr,lf,lf
        db      'Specify the port of the SIO card to use for the image ',cr,lf
        db      'transfer (1-2) or X to exit: ',0

mStart  db      cr,lf,lf
        db      'Start XMODEM send of boot image now...',0

mDone   db      cr,lf,lf,'Creation of new disk successful!',cr,lf,0

mExit   db      cr,lf,lf,'Exiting...',cr,lf,0

mBoot   db      cr,lf,lf
        db      'Insert boot disk into drive A, then press Return...',0

mRecv   db      cr,lf,lf
        db      'Receiving image data from PC (dot = XMODEM packet)',cr,lf,lf,0

mWrite  db      cr,lf,lf
        db      'Writing buffer to floppy disk (line = track, dot = sector)',cr,lf,0

mCRLF   db      cr,lf, 0

;****************************************************************************
;
;  Hardware specific console and serial I/O routines. 
;     The following four routines must be written to provide a common
;     interface to the hardware on which this program is running. The
;     port number specified for serIn and serOut matches the port number
;     input from the operator via the port menu.
;
;****************************************************************************

; 8251 UART Equates

SIOACR  equ     51h             ;control, SIO Board in slot 1
SIOADR  equ     50h             ;data, SIO Board in slot 1
SIOBDA  equ     58h             ;baud, SIO Board in slot 1

SIOBCR  equ     41h             ;control, SIO Board in slot 2
SIOBDR  equ     40h             ;data, SIO Board in slot 2
SIOBDB  equ     48h             ;baud, SIO Board in slot 2

SIORDA  equ     02h             ;read data available flag
SIOTRE  equ     01h             ;transmit register empty flag

BDRT    equ     126             ;set Baud rate of 9600 Baud, 16*CLK

; The rcvByte subroutine above times a one second timeout with a code
;    loop that calls the hardware specific serIn routine below. ONESEC
;    must be set based on processor speed and the number of cycles in 
;    the serIn call + 59 cycles for the rcvByte code. 

ONESEC  equ     39604           ;rcvByte loop count for 1 second (4mhz)

;----------------------------------------------------------------------------
; Init serial port
;-----------------------------------------------------------------------------

initPort lda    xfrPort         ;a=port to use for transfer
        ora     a
        jnz     init2           ;2nd serial port

init1   mvi     a,BDRT
        out     SIOBDA          ;set Baud rate
        
        mvi     a,080h          ;USART commands to reset
        out     SIOACR
        out     SIOACR
        mvi     a,040h          
        out     SIOACR          ;reset

        mvi     a,0ceh          ;2 stop bits, no parity, 8 data bits, 16*CLK 
        out     SIOACR          ;set mode
        mvi     a,037h          ;CMD: RTS, ER, RXF, DTR, TXEN
        out     SIOACR          ;give command 
        
        in      SIOADR          ;clear possible garbage
        in      SIOADR

        ret

init2   mvi     a,BDRT
        out     SIOBDB          ;set Baud rate
        
        mvi     a,080h          ;USART commands to reset
        out     SIOBCR
        out     SIOBCR
        mvi     a,040h          
        out     SIOBCR          ;reset

        mvi     a,0ceh          ;2 stop bits, no parity, 8 data bits, 16*CLK 
        out     SIOBCR          ;set mode
        mvi     a,037h          ;CMD: RTS, ER, RXF, DTR, TXEN
        out     SIOBCR          ;give command 
        
        in      SIOBDR          ;clear possible garbage
        in      SIOBDR

        ret

;----------------------------------------------------------------------------
; Hardware specific I/O
; serIn - input character from port specified in a
;       0 = first serial port
;       1 = second serial port
;    inputs: a = port to read from
;    outputs: z true if no character present
;             z false if character returned in a
; 42 cycles including return when no character present
;-----------------------------------------------------------------------------
serIn   ora     a               ;(4) port 0 or 1?
        jnz     s2InB           ;(10) port 1, 2nd serial port

; Input from 1st serial port

s2InA   in      SIOACR          ;(10+1) see if a new character is present
        
        IF      ADE
        mvi     a,SIORDA        ;character always available if ADE
        ENDIF
        
        ani     SIORDA          ;(7)
        rz                      ;(10) no character, return zero status
        in      SIOADR          ;return character and non-zero status

        IF      ADE
        mvi     a,DUMMY         ;use just dummy character 
        ENDIF

        ret     
        
; Input from 2nd serial port

s2InB   in      SIOBCR          ;(10+1) see if a new character is present
        
        IF      ADE
        mvi     a,SIORDA        ;character always available if ADE
        ENDIF
        
        ani     SIORDA          ;(7)
        rz                      ;(10) no character, return zero status
        in      SIOBDR          ;return character and non-zero status

        IF      ADE
        mvi     a,DUMMY         ;use just dummy character 
        ENDIF

        ret             

;-----------------------------------------------------------------------------
; Hardware specific I/O
; serOut - output character to port specified in a
;       0 = console serial port
;       1 = second serial port
;    inputs: a = port to transmit through
;            b = character to send
;-----------------------------------------------------------------------------
serOut  ora     a               ;port 0 or 1 ?
        jnz     s2OutB          ;second serial port

; Send character through console serial port

S2OutA  in      SIOACR          ;wait for OK to transmit
        ani     SIOTRE
        jz      S2OutA
        mov     a,b             ;a=character to transmit
        out     SIOADR          ;send it
        ret

; Send character through second serial port

s2OutB  in      SIOBCR          ;wait for OK to transmit
        ani     SIOTRE
        jz      s2OutB
        mov     a,b             ;a=character to transmit
        out     SIOBDR          ;send it
        ret

;****************************************************************************
;
; BIOS related routines
;
;****************************************************************************

;***Subroutine**************************************
;
; BIOS -  perform the BIOS calls based on parameter 
; in register E to make calls independent of memory 
; layout (CP/M Vers. 2.2 Rev A / CP/M Vers. 2.2 Rev 1.2.0) 
;
; input parameters for BIOS calls in A, C or BC
; output parameters for BIOS calls in A
; offset of BIOS function in E
; preserves HL
;
;***************************************************

BIOS    push    h               ;save HL
        call    jmpBIOS         ;call BIOS function
        pop     h               ;restore HL
        ret

jmpBIOS lxi     h,BIOSEntry     ;start of BIOS in HL
        mvi     d,00h
        dad     d               ;offset for BIOS call in E
        pchl                    ;jump to BIOS routine

;***Subroutine**************************************
; initBf - init vars for buffer 
;***************************************************

initBf: lxi     h,trkBuf        ;buffer start
        shld    trkPtr          ;reset pointer
        shld    rcvPtr
        xra     a
        sta     wrtTrk          ;init count of written tracks
        ret

;***Subroutine**************************************
; initT - init vars for writing track 
;***************************************************

initT:  xra     a
        sta     curSec          ;start at sector 0
        mvi     a,NUMSEC        ;init count of sectors to write
        sta     wrtSec         
        call    getEndB         ;get start of buffer in HL
        shld    trkPtr          ;pointer to free buffer
        ret

;***Subroutine******************************
; setNTrk - set next track number
;*******************************************

setNTrk:lda     curTrk          ;current track accessed
        inr     a               ;move to next track 
        sta     curTrk          ;new current track
        ret                     

;***Subroutine**************************************
; dWrite - Write sector on current track to buffer at prt.
;***************************************************

dWrite: lhld    trkPtr          ;pointer in buffer
        mov     b,h             ;set dma address in BC
        mov     c,l             
        mvi     e,SETDMA
        call    BIOS            ;set dma address
        mvi     c,01h           ;write must be immediate 
        mvi     e,WRITE          
        call    BIOS            ;write track
        ret                     
        
;***Subroutine*************************
; dRestor - Restore to track 0
; On Exit:
;   curTrk = 0 
;**************************************

dRestor: call   setDrv          ;select drive
        xra     a
        sta     curTrk          ;current track = 0
        mvi     e,HOME          
        call    BIOS            ;move head to track 0
        ret                     

;***Subroutine**************************************
; dSeek - set drive and track
;***************************************************

dSeek:  lda     curTrk          ;load track number
        mvi     b,00h           ;set track number in BC
        mov     c,a             
        mvi     e,SETTRK          
        call    BIOS            ;set track
        ret                     
        
;***Subroutine********************************
; setDrv - Select drive.
;*********************************************

setDrv: lda     drvNum
        mvi     b,00h
        mov     c,a             ;set drive number in c
        mvi     e,SELDSK          
        call    BIOS            ;set drive
        ret                     
        
;***Subroutine******************************
; setNSec - set next sector number
;*******************************************

setNSec:lda     curSec          ;last sector accessed
        inr     a               ;move to next sector 
        sta     curSec          ;new current sector
        ret                     

;***Subroutine******************************
; setSect - set current sector.
;*******************************************

setSect:lda     curSec          ;current sector
        mvi     b,00h
        mov     c,a             ;set sector number in BC
        mvi     e,SETSEC          
        call    BIOS            ;set sector
        ret

;***Subroutine******************************
; setOffs - set offset for current track and 
;           sector in buffer.
;*******************************************

setOffs:lxi     h,TRKLEN        ;track length
        xchg                    ;track length in DE
        lxi     h,trkBuf        ;buffer start

        lda     wrtTrk          ;tracks already written
        cpi     00h
        jz      cmpSOfS         ;compute sector offset in track

addTr:  dad     d               ;HL = HL + DE
        dcr     a                       
        jnz     addTr           ;on zero: HL = BufferStart + written tracks * TRKLEN 

;translate sector to find correct buffer position
cmpSOfS push    h               ;HL start address of track in buffer
        lda     curSec          ;number of logical sector to write
        lxi     h,trslate       ;load start of translation table to HL
        mvi     d,00h
        mov     e,a             ;load current logical sector to DE
        dad     d               ;add to get address of number of physical sector
        mov     a,m             ;load physical sector number to a
        pop     h
        
        stc
        cmc                     ;clear carry
        rar
        mov     d,a             ;D=sector >> 1
        rar                     ;put lsbit into msbit   
        ani     80h
        mov     e,a             ;DE = 128 * sector
        dad     d               ;HL = BufferStart + written tracks * TRKLEN + 128 * sector
        shld    trkPtr          ;new pointer
        ret

;***Subroutine******************************
; getEndB - get end of so far written buffer 
; and return address in HL
;*******************************************

getEndB:lxi     h,TRKLEN        ;track length
        xchg                    ;track length in DE
        lxi     h,trkBuf        ;buffer start

        lda     wrtTrk          ;tracks already written
        cpi     00h
        rz      
        
addTrB: dad     d               ;HL = HL + DE
        dcr     a                       
        jnz     addTrB          ;on zero: HL = BufferStart + written tracks * TRKLEN 
        ret

;***Subroutine******************************
; restoreBios - copy BIOS back to the 
; original position
;*******************************************

restoreBios:
        lxi     d,BIOSEntry     ;DE = destination of copy
        lxi     h,BiosDataStart ;HL = start of copy
        lxi     b,BiosDataEnd - BiosDataStart ;count of bytes
        dw      0b0edh          ;LDIR = copy memory
        ret

;**************************************************************************
; 
;  Data area
;
;**************************************************************************
; sector translation table
trslate db                       0, 1, 2, 3 
        db                      20,21,22,23
        db                       4, 5, 6, 7
        db                      24,25,26,27
        db                       8, 9,10,11
        db                      28,29,30,31
        db                      12,13,14,15
        db                      32,33,34,35
        db                      16,17,18,19
        db                      36,37,38,39

; disk variables

drvNum  ds      1               ;drive number to use
curTrk  ds      1               ;current track number drive is on
trkPtr  ds      2               ;pointer into trkBuf at sector boundaries
wrtTrk  ds      1               ;count of tracks already written
wrtSec  ds      1               ;count of sectors already written
curSec  ds      1               ;current logical sector on track
bufEnd  ds      2               ;end address + 1 of last track spot in RAM
helpVal ds      2               ;dummy value
        
; xmodem variables

xfrPort ds      1               ;pseudo port for file transfer
blkNum  ds      1               ;current xmodem block number
rcvBlk  ds      1               ;block number received
rcvNBlk ds      1               ;"not" block number received
rcvPtr  ds      2               ;pointer for start of XMODEM send

; misc variables

baseDrv    ds   1               ;ascii 1st drive - baseDrv = 0
eotFlag    ds   1               ;set to EOT if EOT terminated reception
           ds   512             ;stack space

ourStk  equ     $
        ds      PKTLEN          ;space for pre-pended unsent data
        
        org     1000h           ;buffer
trkBuf  equ     $

BiosDataStart:
        db      0c3h, 0d9h, 0fah, 0c3h, 05ch, 0f6h, 0c3h, 003h, 0f4h, 0c3h, 006h, 0f4h, 0c3h, 076h, 0f2h, 0c3h
        db      00ch, 0f4h, 0c3h, 00fh, 0f4h, 0c3h, 012h, 0f4h, 0c3h, 05fh, 0f2h, 0c3h, 0dfh, 0f0h, 0c3h, 062h
        db      0f2h, 0c3h, 068h, 0f2h, 0c3h, 06dh, 0f2h, 0c3h, 07eh, 0f2h, 0c3h, 08ch, 0f2h, 0c3h, 015h, 0f4h
        db      0c3h, 073h, 0f2h, 0c3h, 044h, 0f0h, 0c9h, 000h, 000h, 0c3h, 039h, 0edh, 0edh, 073h, 07ah, 0fdh
        db      031h, 0b0h, 0fdh, 0f5h, 0e5h, 0d5h, 03eh, 005h, 0cbh, 079h, 0cah, 012h, 0eeh, 079h, 0e6h, 007h
        db      04fh, 0feh, 003h, 038h, 003h, 017h, 0e6h, 0c0h, 0f6h, 080h, 06fh, 03ah, 0f6h, 0f3h, 0a5h, 028h
        db      011h, 01eh, 028h, 078h, 087h, 087h, 087h, 087h, 0b2h, 057h, 0cbh, 018h, 030h, 01ah, 0cbh, 0f5h
        db      018h, 016h, 01eh, 014h, 03eh, 022h, 090h, 030h, 005h, 0c6h, 023h, 047h, 0cbh, 0f5h, 07dh, 0e6h
        db      040h, 0b0h, 00fh, 00fh, 0e6h, 0f0h, 082h, 057h, 07ah, 032h, 078h, 0fdh, 07bh, 0b8h, 030h, 002h
        db      0cbh, 0edh, 07dh, 032h, 074h, 0fdh, 0f3h, 0edh, 05bh, 012h, 0f6h, 0cdh, 0f8h, 0eeh, 03ah, 0cah
        db      0f3h, 0e6h, 07fh, 020h, 0f6h, 0c5h, 0cdh, 087h, 0efh, 03ah, 074h, 0fdh, 0d3h, 081h, 0c1h, 0e1h
        db      07dh, 0b7h, 020h, 009h, 0dbh, 0e0h, 0e6h, 010h, 03eh, 006h, 0c2h, 00eh, 0eeh, 0e5h, 0c5h, 021h
        db      0c3h, 0f3h, 006h, 000h, 009h, 022h, 0c8h, 0f3h, 07eh, 0eeh, 059h, 0e5h, 0cch, 0f0h, 0efh, 0e1h
        db      0f1h, 0cdh, 0f9h, 0efh, 03ah, 074h, 0fdh, 0d3h, 081h, 0cdh, 0deh, 0efh, 0c1h, 0e1h, 0b7h, 0c5h
        db      0e5h, 0c4h, 05ch, 0efh, 0b8h, 0f5h, 0dbh, 0e0h, 0e6h, 048h, 020h, 00dh, 0cdh, 01ch, 0efh, 0f1h
        db      020h, 0efh, 00dh, 0fah, 0ach, 0eeh, 0c3h, 025h, 0eeh, 0cdh, 0a6h, 0efh, 0f1h, 03ch, 018h, 0e1h
        db      0c1h, 004h, 03ah, 078h, 0fdh, 03ch, 032h, 078h, 0fdh, 0f1h, 03dh, 0f5h, 020h, 0d1h, 0edh, 053h
        db      012h, 0f6h, 031h, 0aeh, 0fdh, 0f5h, 0ebh, 0cdh, 03ch, 0f0h, 0ebh, 0dbh, 082h, 0f1h, 0c1h, 0b7h
        db      0edh, 07bh, 07ah, 0fdh, 0c9h, 0c5h, 021h, 023h, 000h, 0cdh, 004h, 0efh, 03ah, 0cfh, 0f3h, 0e6h
        db      0f7h, 0d3h, 0f8h, 0d3h, 082h, 021h, 009h, 000h, 0cdh, 004h, 0efh, 03ah, 0cfh, 0f3h, 0d3h, 0f8h
        db      0c1h, 00dh, 021h, 06eh, 0eeh, 020h, 003h, 021h, 08eh, 0eeh, 0e3h, 0cdh, 069h, 0efh, 0dbh, 081h
        db      0feh, 0fbh, 0c2h, 082h, 0efh, 03ah, 078h, 0fdh, 047h, 0dbh, 080h, 0b8h, 032h, 079h, 0fdh, 001h
        db      000h, 000h, 0c8h, 0feh, 0fbh, 0c8h, 02ah, 0c8h, 0f3h, 036h, 059h, 0c3h, 0a7h, 0eeh, 0dbh, 080h
        db      077h, 0a9h, 007h, 04fh, 0cdh, 0deh, 0eeh, 0dbh, 080h, 023h, 077h, 023h, 0a9h, 007h, 04fh, 010h
        db      0edh, 0dbh, 080h, 0a9h, 0dbh, 082h, 0cah, 000h, 0eeh, 03eh, 002h, 0c3h, 00eh, 0eeh, 0dbh, 080h
        db      0beh, 020h, 014h, 0a9h, 007h, 04fh, 0cdh, 0deh, 0eeh, 0dbh, 080h, 023h, 0beh, 020h, 008h, 0a9h
        db      007h, 04fh, 023h, 010h, 0e9h, 018h, 0dah, 03eh, 003h, 0c3h, 00eh, 0eeh, 001h, 000h, 022h, 0d3h
        db      083h, 0afh, 0d3h, 080h, 0cdh, 0deh, 0eeh, 010h, 0f8h, 03eh, 0fbh, 0d3h, 080h, 0e3h, 0e3h, 03ah
        db      078h, 0fdh, 0d3h, 080h, 0e1h, 07eh, 023h, 0d3h, 080h, 0a9h, 007h, 04fh, 0cdh, 0deh, 0eeh, 07eh
        db      0d3h, 080h, 023h, 0a9h, 007h, 04fh, 010h, 0edh, 079h, 0d3h, 080h, 0c3h, 000h, 0eeh, 0dbh, 0e0h
        db      0e6h, 000h, 0c8h, 0dbh, 000h, 012h, 013h, 0c9h, 0f5h, 0d5h, 0edh, 05bh, 012h, 0f6h, 0cdh, 0deh
        db      0eeh, 0edh, 053h, 012h, 0f6h, 0d1h, 0f1h, 0c9h, 0edh, 053h, 012h, 0f6h, 0c3h, 008h, 0fbh, 0edh
        db      05bh, 012h, 0f6h, 0c9h, 001h, 0ffh, 0ffh, 0dbh, 0e0h, 0e6h, 000h, 0cah, 017h, 0efh, 009h, 0d2h
        db      01bh, 0efh, 0dbh, 000h, 012h, 013h, 0b7h, 009h, 0dah, 007h, 0efh, 0c9h, 021h, 098h, 001h, 0dbh
        db      0e0h, 0e6h, 040h, 0c0h, 0dbh, 0e0h, 0e6h, 000h, 0cah, 034h, 0efh, 0dbh, 0e0h, 0e6h, 040h, 0c0h
        db      0dbh, 000h, 012h, 013h, 0dbh, 0e0h, 0e6h, 040h, 0c0h, 02bh, 07ch, 0b5h, 0c2h, 01fh, 0efh, 032h
        db      0c3h, 0f3h, 03eh, 004h, 0c3h, 00eh, 0eeh, 021h, 0efh, 004h, 0cdh, 0deh, 0eeh, 0dbh, 0e0h, 0e6h
        db      040h, 0c8h, 02bh, 07ch, 0b5h, 020h, 0f3h, 018h, 0e6h, 0cdh, 01ch, 0efh, 0cdh, 0f8h, 0eeh, 0cdh
        db      047h, 0efh, 0cdh, 0d3h, 0efh, 03ch, 0e6h, 00fh, 0c9h, 001h, 0e0h, 035h, 0edh, 070h, 0f8h, 0dbh
        db      0e0h, 0e6h, 000h, 0cah, 07dh, 0efh, 0edh, 070h, 0f8h, 0dbh, 000h, 012h, 013h, 0edh, 070h, 0f8h
        db      010h, 0eah, 03eh, 001h, 0c3h, 00eh, 0eeh, 0cdh, 0a6h, 0efh, 0feh, 00eh, 0c0h, 0afh, 032h, 0c3h
        db      0f3h, 0cdh, 0ach, 0efh, 006h, 064h, 0e5h, 0c5h, 0cdh, 0f8h, 0eeh, 021h, 096h, 001h, 0cdh, 004h
        db      0efh, 0c1h, 010h, 0f3h, 0e1h, 0c9h, 0cdh, 0b1h, 0efh, 0feh, 00eh, 0c8h, 026h, 005h, 0cdh, 0b3h
        db      0efh, 026h, 000h, 0cdh, 0deh, 0eeh, 03ah, 0cfh, 0f3h, 06fh, 0e6h, 0f8h, 0b4h, 067h, 0bdh, 028h
        db      012h, 0dbh, 0d0h, 06fh, 07ch, 0d3h, 0f8h, 032h, 0cfh, 0f3h, 0cdh, 0deh, 0eeh, 0dbh, 0d0h, 0adh
        db      0f2h, 0cah, 0efh, 02eh, 080h, 0dbh, 0d0h, 0e6h, 00fh, 0bdh, 0c8h, 06fh, 018h, 0f7h, 021h, 0c3h
        db      0f3h, 07eh, 071h, 0b9h, 0c8h, 006h, 00ch, 0cdh, 096h, 0efh, 0cdh, 059h, 0efh, 0c8h, 018h, 0fah
        db      0e5h, 0cdh, 0deh, 0efh, 0cdh, 01ch, 0efh, 0e1h, 0afh, 047h, 096h, 070h, 0c8h, 02eh, 020h, 067h
        db      0f2h, 00dh, 0f0h, 02fh, 03ch, 067h, 0dbh, 0e0h, 0e6h, 020h, 0c0h, 02eh, 000h, 03ah, 074h, 0fdh
        db      0e6h, 0cfh, 0b5h, 06fh, 07dh, 0d3h, 081h, 0f6h, 010h, 0d3h, 081h, 0eeh, 010h, 0d3h, 081h, 03ah
        db      0f8h, 0f3h, 0a5h, 0e6h, 00fh, 006h, 001h, 020h, 002h, 006h, 005h, 0cdh, 096h, 0efh, 0dbh, 0e0h
        db      0e6h, 020h, 020h, 003h, 025h, 020h, 0ddh, 006h, 003h, 0c3h, 096h, 0efh, 021h, 0ffh, 0f3h, 0cbh
        db      05eh, 0c8h, 0fbh, 0c9h, 032h, 076h, 0fdh, 03ah, 0e9h, 0f3h, 032h, 077h, 0fdh, 0e5h, 0d5h, 0c5h
        db      03ah, 076h, 0fdh, 0e6h, 00fh, 0cdh, 03ch, 0edh, 0c1h, 0d1h, 0e1h, 020h, 012h, 07bh, 0b7h, 020h
        db      00ch, 03ah, 0ffh, 0f3h, 0e6h, 040h, 01eh, 002h, 020h, 0ddh, 0cdh, 059h, 0efh, 0afh, 0c9h, 032h
        db      0d0h, 0f0h, 0feh, 004h, 030h, 006h, 03ah, 077h, 0fdh, 03dh, 020h, 0ceh, 079h, 0e6h, 00fh, 032h
        db      0d4h, 0f0h, 078h, 0e5h, 0d5h, 0c5h, 021h, 0dbh, 0f0h, 072h, 02bh, 0cdh, 0a5h, 0f0h, 079h, 0cdh
        db      0a5h, 0f0h, 071h, 021h, 0cch, 0f0h, 03ah, 0d0h, 0f0h, 0cdh, 0b1h, 0f0h, 0c1h, 0d1h, 0e1h, 0c2h
        db      047h, 0f0h, 0afh, 037h, 0c9h, 00eh, 0ffh, 0d6h, 00ah, 00ch, 030h, 0fbh, 0c6h, 00ah, 077h, 02bh
        db      0c9h, 0b7h, 0cdh, 0eah, 0f3h, 0b7h, 0c4h, 001h, 0f7h, 0afh, 0cdh, 0eah, 0f3h, 0b7h, 0cch, 009h
        db      0edh, 0feh, 003h, 0cah, 05ch, 0f6h, 047h, 03ah, 0f9h, 0f3h, 0b8h, 0c9h, 00dh, 00ah, 054h, 020h
        db      020h, 020h, 044h, 020h, 020h, 020h, 053h, 020h, 020h, 020h, 020h, 000h, 00dh, 00ah, 080h, 069h
        db      026h, 000h, 0afh, 0cdh, 036h, 0edh, 022h, 06eh, 0fdh, 0ebh, 0b7h, 032h, 06ah, 0fdh, 0c0h, 03dh
        db      032h, 073h, 0fdh, 07bh, 0feh, 004h, 0d2h, 092h, 0f1h, 07dh, 0e6h, 001h, 0c2h, 07eh, 0f1h, 0cdh
        db      04bh, 0f3h, 03ah, 06eh, 0fdh, 0cdh, 09ah, 0f1h, 0f6h, 080h, 04fh, 006h, 000h, 011h, 001h, 000h
        db      03eh, 001h, 021h, 000h, 0feh, 0cdh, 044h, 0f0h, 038h, 0f1h, 006h, 090h, 0cbh, 0b9h, 021h, 05ch
        db      0feh, 07eh, 0e6h, 010h, 011h, 01fh, 0f2h, 028h, 022h, 046h, 078h, 0e6h, 040h, 028h, 00eh, 03ah
        db      0f8h, 0f3h, 0c5h, 007h, 00dh, 020h, 0fch, 0c1h, 011h, 03fh, 0f2h, 038h, 00eh, 03eh, 0bfh, 0a0h
        db      047h, 011h, 02fh, 0f2h, 0e6h, 020h, 020h, 003h, 011h, 01fh, 0f2h, 03ah, 0f6h, 0f3h, 01fh, 00dh
        db      020h, 0fch, 038h, 008h, 078h, 0e6h, 002h, 0c2h, 0a6h, 0f3h, 018h, 00ah, 078h, 004h, 0e6h, 002h
        db      028h, 004h, 005h, 011h, 04fh, 0f2h, 0d5h, 02ah, 06eh, 0fdh, 011h, 0fah, 0f3h, 019h, 070h, 0cdh
        db      07eh, 0f1h, 02bh, 0d1h, 01ah, 077h, 013h, 001h, 00bh, 000h, 009h, 073h, 023h, 072h, 03ah, 06eh
        db      0fdh, 021h, 0cah, 0f1h, 011h, 011h, 000h, 03ch, 019h, 03dh, 020h, 0fch, 07eh, 032h, 06ah, 0fdh
        db      023h, 0c9h, 021h, 000h, 000h, 0afh, 032h, 004h, 000h, 0c9h, 03dh, 0feh, 001h, 03ch, 038h, 013h
        db      021h, 0bdh, 0f1h, 0c6h, 041h, 0beh, 028h, 00ah, 077h, 021h, 0b5h, 0f1h, 0cdh, 001h, 0f7h, 0cdh
        db      009h, 0edh, 0afh, 03ch, 0c9h, 00dh, 00ah, 04dh, 04fh, 055h, 04eh, 054h, 020h, 041h, 03ah, 020h
        db      049h, 04eh, 020h, 044h, 052h, 049h, 056h, 045h, 020h, 031h, 02ch, 020h, 054h, 059h, 050h, 045h
        db      020h, 041h, 04eh, 059h, 020h, 04bh, 045h, 059h, 00dh, 00ah, 080h, 010h, 000h, 000h, 019h, 000h
        db      000h, 000h, 000h, 000h, 001h, 0fch, 040h, 0f2h, 09ah, 0fch, 081h, 0fch, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 001h, 0fch, 02fh, 0f2h, 0d3h, 0fch, 0bah, 0fch, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 001h, 0fch, 02fh, 0f2h, 00ch, 0fdh, 0f3h, 0fch, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 001h, 0fch, 02fh, 0f2h, 045h, 0fdh, 02ch, 0fdh, 008h
        db      028h, 000h, 003h, 007h, 000h, 0a4h, 000h, 03fh, 000h, 0c0h, 000h, 010h, 000h, 002h, 000h, 010h
        db      028h, 000h, 004h, 00fh, 001h, 051h, 000h, 03fh, 000h, 080h, 000h, 010h, 000h, 002h, 000h, 010h
        db      028h, 000h, 004h, 00fh, 001h, 0a9h, 000h, 03fh, 000h, 080h, 000h, 010h, 000h, 002h, 000h, 020h
        db      028h, 000h, 005h, 01fh, 003h, 0c4h, 000h, 07fh, 000h, 080h, 000h, 020h, 000h, 002h, 000h, 001h
        db      000h, 000h, 060h, 069h, 022h, 06bh, 0fdh, 0c9h, 079h, 032h, 06dh, 0fdh, 0c9h, 060h, 069h, 022h
        db      070h, 0fdh, 0c9h, 069h, 060h, 0c9h, 0c5h, 0cdh, 04bh, 0f3h, 0c1h, 0c3h, 009h, 0f4h, 0cdh, 04bh
        db      0f3h, 03eh, 001h, 032h, 069h, 0fdh, 0afh, 032h, 072h, 0fdh, 018h, 046h, 0afh, 032h, 069h, 0fdh
        db      021h, 072h, 0fdh, 00dh, 0fah, 0a3h, 0f2h, 028h, 006h, 03ah, 06ah, 0fdh, 077h, 018h, 033h, 036h
        db      080h, 018h, 02fh, 0b6h, 028h, 02ch, 035h, 02ah, 065h, 0fdh, 0ebh, 02ah, 067h, 0fdh, 0b4h, 03eh
        db      028h, 0f2h, 0b6h, 0f2h, 03eh, 040h, 02ch, 095h, 020h, 002h, 06fh, 013h, 0e5h, 02ah, 06bh, 0fdh
        db      0cdh, 043h, 0f3h, 0d1h, 020h, 008h, 02ah, 06dh, 0fdh, 0cdh, 043h, 0f3h, 028h, 004h, 0afh, 032h
        db      072h, 0fdh, 02ah, 06bh, 0fdh, 0ebh, 02ah, 065h, 0fdh, 0cdh, 043h, 0f3h, 020h, 00eh, 02ah, 06dh
        db      0fdh, 0ebh, 02ah, 067h, 0fdh, 0cdh, 043h, 0f3h, 0e6h, 0fch, 028h, 00eh, 0cdh, 04bh, 0f3h, 03ah
        db      072h, 0fdh, 0e6h, 07fh, 03eh, 000h, 020h, 001h, 03ch, 0b7h, 02ah, 06bh, 0fdh, 022h, 065h, 0fdh
        db      02ah, 06dh, 0fdh, 022h, 067h, 0fdh, 006h, 001h, 0c4h, 055h, 0f3h, 03ah, 067h, 0fdh, 0e6h, 003h
        db      01fh, 067h, 01fh, 06fh, 011h, 000h, 0feh, 019h, 0edh, 05bh, 070h, 0fdh, 03ah, 069h, 0fdh, 03dh
        db      0f5h, 028h, 004h, 032h, 0f3h, 0f3h, 0ebh, 001h, 080h, 000h, 0edh, 0b0h, 0f1h, 0c8h, 021h, 072h
        db      0fdh, 07eh, 0b7h, 0f2h, 03ah, 0f3h, 0afh, 077h, 018h, 004h, 021h, 073h, 0fdh, 034h, 0cch, 04bh
        db      0f3h, 0afh, 0c9h, 07ah, 0ach, 03eh, 0ffh, 0c0h, 07bh, 0adh, 0c9h, 03ah, 0f3h, 0f3h, 0b7h, 0c8h
        db      0afh, 032h, 0f3h, 0f3h, 047h, 03ah, 067h, 0fdh, 0e6h, 0fch, 00fh, 00fh, 04fh, 02ah, 065h, 0fdh
        db      03ah, 068h, 0fdh, 0b7h, 0fah, 039h, 0edh, 0e5h, 0c5h, 0cdh, 09ah, 0f1h, 0c1h, 02ah, 068h, 0fdh
        db      026h, 000h, 011h, 0fah, 0f3h, 019h, 058h, 051h, 0f6h, 080h, 04fh, 07eh, 01fh, 030h, 012h, 07bh
        db      0b7h, 0cah, 0a6h, 0f3h, 0e3h, 07dh, 0feh, 023h, 038h, 003h, 03eh, 085h, 095h, 007h, 007h, 06fh
        db      0e3h, 0afh, 07ah, 01fh, 030h, 002h, 0c6h, 005h, 057h, 07eh, 0e1h, 026h, 001h, 0e6h, 041h, 020h
        db      00eh, 07dh, 0feh, 023h, 038h, 009h, 021h, 0d7h, 0f6h, 0cdh, 001h, 0f7h, 0c3h, 05ch, 0f6h, 07ch
        db      045h, 021h, 000h, 0feh, 0c3h, 044h, 0f0h, 0edh, 073h, 008h, 0c2h, 031h, 008h, 0c2h, 0e5h, 0d5h
        db      0c5h, 0f5h, 076h, 001h, 002h, 059h, 059h, 059h, 0c4h, 0f3h, 000h, 001h, 002h, 003h, 000h, 098h
        db      000h, 0a0h, 0a1h, 0a2h, 0a3h, 0f8h, 090h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 00ah, 0c9h, 000h, 000h, 0c9h, 000h, 000h
        db      0c9h, 000h, 000h, 000h, 000h, 0d7h, 000h, 000h, 0ffh, 001h, 0f0h, 000h, 000h, 000h, 002h, 010h
        db      0c3h, 0beh, 0f4h, 0c3h, 01ch, 0f4h, 0c3h, 027h, 0f4h, 0c3h, 041h, 0f4h, 0c3h, 044h, 0f4h, 0c3h
        db      096h, 0f4h, 0c3h, 074h, 0f4h, 0c3h, 05fh, 0f4h, 07eh, 070h, 070h, 001h, 0cdh, 00ch, 0f6h, 0dbh
        db      0d0h, 0e6h, 040h, 0c8h, 03eh, 0ffh, 0c9h, 0cdh, 01ch, 0f4h, 0cah, 027h, 0f4h, 0cdh, 000h, 0f6h
        db      0feh, 0e9h, 0cah, 03eh, 0f4h, 0feh, 07fh, 0cah, 03bh, 0f4h, 0c9h, 03eh, 008h, 0c9h, 03eh, 07fh
        db      0c9h, 0c3h, 003h, 0f6h, 0cdh, 05fh, 0f4h, 0cah, 044h, 0f4h, 0dbh, 074h, 0feh, 0f7h, 079h, 0cah
        db      05ch, 0f4h, 0d3h, 044h, 0d3h, 040h, 0c9h, 07fh, 0d3h, 050h, 0f6h, 080h, 0d3h, 050h, 0c9h, 0cdh
        db      00ch, 0f6h, 006h, 001h, 0dbh, 074h, 0feh, 0f7h, 0cah, 06dh, 0f4h, 006h, 004h, 0dbh, 041h, 0a0h
        db      0c8h, 0f6h, 0ffh, 0c9h, 0cdh, 00ch, 0f6h, 0dbh, 074h, 0feh, 0f7h, 0dbh, 041h, 0c2h, 08ah, 0f4h
        db      0e6h, 002h, 0cah, 074h, 0f4h, 0dbh, 040h, 0e6h, 07fh, 0c9h, 0e6h, 008h, 0cah, 074h, 0f4h, 0dbh
        db      040h, 0e6h, 07fh, 0d3h, 046h, 0c9h, 0cdh, 00ch, 0f6h, 0dbh, 074h, 0feh, 0f7h, 0dbh, 041h, 0c2h
        db      0abh, 0f4h, 0e6h, 001h, 0cah, 096h, 0f4h, 079h, 0d3h, 040h, 0c9h, 0e6h, 004h, 0cah, 096h, 0f4h
        db      079h, 0f6h, 080h, 0d3h, 040h, 0e6h, 07fh, 0d3h, 040h, 0f6h, 080h, 0d3h, 040h, 0c9h, 0afh, 032h
        db      003h, 000h, 032h, 004h, 000h, 0dbh, 075h, 0feh, 0f7h, 0c2h, 0dch, 0f4h, 03eh, 0ceh, 0d3h, 051h
        db      03eh, 037h, 0d3h, 051h, 03ah, 018h, 0f4h, 0d3h, 058h, 0c3h, 0e6h, 0f4h, 0feh, 0dfh, 0c2h, 0e6h
        db      0f4h, 03eh, 00dh, 0cdh, 052h, 0f4h, 0dbh, 074h, 0feh, 0f7h, 0c2h, 0fah, 0f4h, 03eh, 0ceh, 0d3h
        db      041h, 03eh, 037h, 0d3h, 041h, 03ah, 019h, 0f4h, 0d3h, 048h, 0dbh, 074h, 0feh, 0f7h, 0c2h, 011h
        db      0f5h, 03eh, 0ceh, 0d3h, 041h, 03eh, 037h, 0d3h, 041h, 03ah, 01ah, 0f4h, 0d3h, 048h, 0c3h, 01bh
        db      0f5h, 0feh, 0dfh, 0c2h, 01bh, 0f5h, 03eh, 00dh, 0cdh, 0b1h, 0f4h, 0c9h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 001h, 008h, 000h, 011h, 007h, 0d7h
        db      021h, 0c8h, 0f5h, 0edh, 0b0h, 0c3h, 000h, 0d7h, 006h, 048h, 044h, 042h, 04fh, 04fh, 054h, 020h
        db      04bh, 0f3h, 0b1h, 0f0h, 0e9h, 0f6h, 000h, 000h, 043h, 050h, 04dh, 057h, 04fh, 052h, 04bh, 000h
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 000h, 000h, 000h, 000h
        db      0c3h, 055h, 0f7h, 0c3h, 08dh, 0f7h, 0c3h, 011h, 0f7h, 0c3h, 01bh, 0f7h, 0c3h, 0ffh, 0fah, 0c3h
        db      082h, 0f7h, 002h, 000h, 001h, 001h, 0c9h, 000h, 000h, 0c3h, 0b3h, 0efh, 00dh, 07fh, 002h, 028h
        db      061h, 085h, 000h, 000h, 06bh, 0f8h, 02fh, 0f6h, 000h, 000h, 0c8h, 000h, 000h, 000h, 000h, 0ffh
        db      0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 028h, 043h, 029h, 020h, 031h, 039h, 038h
        db      031h, 020h, 04eh, 06fh, 072h, 074h, 068h, 020h, 053h, 074h, 061h, 072h, 020h, 043h, 06fh, 06dh
        db      070h, 075h, 074h, 065h, 072h, 073h, 02ch, 020h, 049h, 06eh, 063h, 02eh, 031h, 000h, 001h, 021h
        db      0feh, 0f3h, 07eh, 036h, 002h, 023h, 0a6h, 021h, 000h, 0d7h, 020h, 003h, 023h, 023h, 023h, 0e5h
        db      021h, 059h, 059h, 022h, 0c4h, 0f3h, 022h, 0c6h, 0f3h, 0afh, 04fh, 05fh, 032h, 0f3h, 0f3h, 03dh
        db      032h, 0c3h, 0f3h, 032h, 068h, 0fdh, 0cdh, 0dfh, 0f0h, 0cdh, 0e6h, 0f6h, 020h, 0e2h, 03eh, 0c9h
        db      032h, 0eah, 0f3h, 032h, 016h, 0f6h, 03eh, 0c3h, 032h, 000h, 000h, 032h, 005h, 000h, 021h, 003h
        db      0edh, 022h, 001h, 000h, 011h, 006h, 008h, 02ah, 0f4h, 0f3h, 019h, 022h, 006h, 000h, 021h, 080h
        db      000h, 022h, 070h, 0fdh, 00eh, 01ch, 0cdh, 08dh, 0f7h, 0cdh, 0edh, 0f3h, 03ah, 004h, 000h, 04fh
        db      0c9h, 03eh, 0c3h, 032h, 0fch, 0eeh, 000h, 0cdh, 000h, 0f4h, 03ah, 0f7h, 0f3h, 0b7h, 0cah, 05ch
        db      0f6h, 021h, 0bah, 0f5h, 0c3h, 06fh, 0f6h, 049h, 04ch, 04ch, 045h, 047h, 041h, 04ch, 020h, 041h
        db      043h, 043h, 045h, 053h, 053h, 080h, 021h, 000h, 0d7h, 03eh, 001h, 001h, 081h, 000h, 011h, 001h
        db      009h, 0cdh, 03ch, 0edh, 0c0h, 03eh, 00ah, 001h, 081h, 001h, 011h, 001h, 000h, 0cdh, 03ch, 0edh
        db      0c9h, 07eh, 0b7h, 0f8h, 0feh, 00ah, 030h, 002h, 0f6h, 030h, 04fh, 0cdh, 07bh, 0f2h, 023h, 018h
        db      0f0h, 0e5h, 021h, 0cbh, 0f3h, 006h, 000h, 009h, 046h, 0e1h, 0c9h, 079h, 0feh, 006h, 0d0h, 0e5h
        db      021h, 0cbh, 0f3h, 078h, 006h, 000h, 009h, 077h, 00eh, 006h, 009h, 04eh, 0edh, 079h, 0e1h, 0c9h
        db      0f3h, 0edh, 05bh, 012h, 0f6h, 026h, 001h, 0cdh, 0b3h, 0efh, 0f5h, 026h, 002h, 0cdh, 0b3h, 0efh
        db      007h, 007h, 007h, 007h, 0e1h, 0b4h, 03ch, 028h, 004h, 03dh, 032h, 01ch, 0f6h, 0cdh, 0a6h, 0efh
        db      0edh, 053h, 012h, 0f6h, 0c9h, 0dbh, 0d0h, 0e6h, 040h, 028h, 0fah, 0d5h, 0e5h, 0cdh, 030h, 0f7h
        db      03ah, 02bh, 0f6h, 0b7h, 028h, 013h, 01eh, 005h, 0cdh, 00fh, 0f6h, 016h, 004h, 0cdh, 0e8h, 0eeh
        db      015h, 020h, 0fah, 01dh, 020h, 0f2h, 0cdh, 00fh, 0f6h, 02ah, 01ch, 0f6h, 07dh, 0e1h, 0d1h, 0c3h
        db      03ch, 0f0h, 03ah, 0cfh, 0f3h, 0eeh, 040h, 032h, 0cfh, 0f3h, 0d3h, 0f8h, 0c9h, 0e5h, 021h, 000h
        db      000h, 039h, 0f3h, 031h, 000h, 0feh, 0e5h, 0d5h, 0c5h, 0ddh, 0e5h, 0fdh, 0e5h, 079h, 0e6h, 07fh
        db      0feh, 01fh, 028h, 004h, 0e6h, 07eh, 0feh, 00ah, 0cch, 0eeh, 0f7h, 0cdh, 0fch, 0f7h, 021h, 023h
        db      0f6h, 07eh, 0e6h, 0c0h, 028h, 01eh, 00eh, 00ah, 0fah, 0bdh, 0f7h, 0cbh, 0f9h, 0aeh, 077h, 0cdh
        db      0eeh, 0f7h, 021h, 0cah, 0f3h, 071h, 0cdh, 0b1h, 0fah, 021h, 023h, 0f6h, 07eh, 0e6h, 001h, 032h
        db      02eh, 0f6h, 0cbh, 0c6h, 03ah, 0cah, 0f3h, 0e6h, 07fh, 020h, 006h, 03ah, 022h, 0f6h, 032h, 0d0h
        db      0f3h, 0fdh, 0e1h, 0ddh, 0e1h, 0c1h, 0d1h, 0e1h, 0f9h, 0cdh, 03ch, 0f0h, 0e1h, 0c9h, 0cdh, 0e8h
        db      0eeh, 0cdh, 051h, 0fah, 03ah, 0cah, 0f3h, 0e6h, 07fh, 0c8h, 018h, 0f2h, 051h, 0cdh, 0f7h, 0f9h
        db      021h, 06bh, 0f8h, 022h, 024h, 0f6h, 03ah, 029h, 0f6h, 0b7h, 0c2h, 077h, 0f9h, 07ah, 0e6h, 07fh
        db      0feh, 07fh, 028h, 088h, 0feh, 020h, 0d2h, 0fdh, 087h, 05fh, 016h, 000h, 021h, 02bh, 0f8h, 019h
        db      019h, 05eh, 023h, 056h, 0ebh, 057h, 0ddh, 0cbh, 005h, 066h, 0e9h, 0fdh, 087h, 0ech, 0f8h, 0e9h
        db      0f8h, 0fdh, 087h, 022h, 0fah, 0cbh, 0f8h, 0cah, 0f8h, 0e5h, 0f8h, 02bh, 0f9h, 0fdh, 087h, 0fdh
        db      087h, 039h, 0f9h, 0fdh, 087h, 0fdh, 087h, 0fdh, 087h, 0fdh, 087h, 0fdh, 087h, 0d3h, 0f9h, 00bh
        db      0f9h, 0b3h, 0f8h, 0cfh, 0f9h, 0c0h, 0f8h, 0ffh, 0f8h, 003h, 0f9h, 0e1h, 0f9h, 0e5h, 0f9h, 0fdh
        db      087h, 084h, 0f9h, 0d0h, 0f8h, 0dch, 0f8h, 023h, 0f9h, 0fdh, 087h, 03ah, 023h, 0f6h, 0e6h, 090h
        db      0feh, 090h, 020h, 028h, 0ddh, 0cbh, 005h, 0beh, 03eh, 0f0h, 0ddh, 096h, 00ch, 04fh, 016h, 04fh
        db      041h, 03ah, 02ah, 0f6h, 06fh, 0c6h, 00ah, 05fh, 062h, 01ah, 077h, 02ch, 01ch, 010h, 0fah, 015h
        db      0f2h, 080h, 0f8h, 0afh, 032h, 022h, 0f6h, 03eh, 0e6h, 032h, 01fh, 0f6h, 0c1h, 051h, 00eh, 002h
        db      0cdh, 009h, 0f6h, 0c1h, 059h, 00eh, 001h, 0cdh, 009h, 0f6h, 043h, 00eh, 000h, 0cdh, 009h, 0f6h
        db      07ah, 042h, 0c9h, 021h, 023h, 0f6h, 0cbh, 0a6h, 0cbh, 06eh, 020h, 0e0h, 0cbh, 096h, 018h, 0dch
        db      0cdh, 0eeh, 0f7h, 021h, 023h, 0f6h, 0cbh, 0aeh, 018h, 0f2h, 0afh, 032h, 02bh, 0f6h, 018h, 0cch
        db      00eh, 004h, 0cdh, 006h, 0f6h, 0cbh, 0a8h, 0cdh, 009h, 0f6h, 018h, 0c0h, 00eh, 004h, 0cdh, 006h
        db      0f6h, 0cbh, 0e8h, 018h, 0f2h, 0dbh, 083h, 018h, 0b3h, 0afh, 018h, 002h, 03eh, 0ffh, 032h, 028h
        db      0f6h, 018h, 0a9h, 0ddh, 0cbh, 005h, 08eh, 018h, 0a3h, 0ddh, 0cbh, 005h, 0ceh, 018h, 09dh, 03eh
        db      0ffh, 018h, 002h, 03eh, 07fh, 032h, 01dh, 0f6h, 0c3h, 09ch, 0f8h, 0cdh, 0eeh, 0f7h, 0afh, 0cdh
        db      016h, 0f6h, 028h, 05ah, 032h, 02ah, 0f6h, 0afh, 032h, 01eh, 0f6h, 03ah, 02ah, 0f6h, 032h, 01fh
        db      0f6h, 018h, 04bh, 0cah, 0fdh, 087h, 021h, 017h, 0f9h, 018h, 046h, 0cah, 0fdh, 087h, 03ah, 01eh
        db      0f6h, 0b7h, 020h, 011h, 021h, 04bh, 0f9h, 018h, 006h, 0cah, 0fdh, 087h, 021h, 04fh, 0f9h, 03ah
        db      02ah, 0f6h, 0ddh, 0beh, 001h, 07ah, 0c2h, 0fdh, 087h, 018h, 026h, 0ddh, 036h, 000h, 04fh, 03eh
        db      0e6h, 0ddh, 096h, 00ch, 04fh, 026h, 04fh, 054h, 041h, 02eh, 0efh, 01eh, 0e5h, 01ah, 077h, 01dh
        db      02dh, 010h, 0fah, 006h, 00ah, 0afh, 077h, 02dh, 010h, 0fch, 025h, 0f2h, 057h, 0f9h, 021h, 09ch
        db      0f8h, 022h, 024h, 0f6h, 0c3h, 0fah, 087h, 0feh, 01bh, 028h, 00fh, 0feh, 03dh, 028h, 01ch, 0feh
        db      0bdh, 028h, 030h, 0afh, 032h, 029h, 0f6h, 0c3h, 09ch, 0f8h, 07ah, 0feh, 024h, 0cah, 0f3h, 0f8h
        db      0feh, 025h, 0cah, 0f9h, 0f8h, 0feh, 03dh, 028h, 0ebh, 018h, 0e8h, 07ah, 0d6h, 020h, 038h, 0e3h
        db      0feh, 018h, 030h, 0dfh, 087h, 057h, 087h, 087h, 082h, 0ddh, 086h, 004h, 032h, 02dh, 0f6h, 03eh
        db      0bdh, 018h, 0d1h, 07ah, 0d6h, 020h, 038h, 0cbh, 0feh, 050h, 030h, 0c7h, 032h, 02ch, 0f6h, 021h
        db      0c4h, 0f9h, 018h, 0adh, 02ah, 02ch, 0f6h, 022h, 01eh, 0f6h, 021h, 083h, 0f9h, 018h, 0a2h, 03eh
        db      001h, 018h, 002h, 03eh, 002h, 032h, 014h, 0f6h, 021h, 023h, 0f6h, 0cbh, 0eeh, 0cbh, 0d6h, 018h
        db      0a2h, 006h, 000h, 018h, 002h, 006h, 001h, 03ah, 0cah, 0f3h, 0e6h, 07fh, 07ah, 0cah, 0fdh, 087h
        db      078h, 032h, 02eh, 0f6h, 0c3h, 09ch, 0f8h, 0e1h, 00eh, 000h, 0cdh, 006h, 0f6h, 058h, 00ch, 0cdh
        db      006h, 0f6h, 04bh, 0c5h, 00eh, 002h, 0cdh, 006h, 0f6h, 04ah, 0c5h, 001h, 000h, 0f8h, 0cdh, 009h
        db      0f6h, 001h, 001h, 0f9h, 0cdh, 009h, 0f6h, 001h, 002h, 0fch, 0cdh, 009h, 0f6h, 0ddh, 021h, 01eh
        db      0f6h, 0e9h, 0cdh, 0eeh, 0f7h, 021h, 000h, 000h, 022h, 028h, 0f6h, 022h, 01eh, 0f6h, 022h, 022h
        db      0f6h, 0cdh, 03fh, 0fah, 021h, 01dh, 0f6h, 036h, 07fh, 021h, 0d0h, 0f8h, 0c3h, 071h, 0f9h, 021h
        db      000h, 000h, 011h, 001h, 000h, 001h, 0ffh, 04fh, 075h, 0edh, 0b0h, 001h, 005h, 000h, 0c3h, 009h
        db      0f6h, 0e5h, 021h, 015h, 0f6h, 0dbh, 060h, 02fh, 0a6h, 0c4h, 0b7h, 0fah, 0e1h, 0dbh, 0e0h, 0e6h
        db      004h, 0c8h, 0d3h, 0b0h, 03ah, 0cah, 0f3h, 0e6h, 07fh, 0c8h, 0e5h, 02ah, 014h, 0f6h, 095h, 030h
        db      003h, 085h, 06fh, 0afh, 067h, 020h, 01bh, 0c5h, 0d5h, 0e5h, 0ddh, 0e5h, 0fdh, 0e5h, 021h, 023h
        db      0f6h, 0cbh, 086h, 03ah, 02eh, 0f6h, 0b6h, 077h, 0cdh, 0b1h, 0fah, 0fdh, 0e1h, 0ddh, 0e1h, 0e1h
        db      0d1h, 0c1h, 03ah, 0cah, 0f3h, 0e6h, 080h, 0b4h, 032h, 0cah, 0f3h, 07dh, 0f2h, 0a1h, 0fah, 02fh
        db      03ch, 0e1h, 0c5h, 0f5h, 00eh, 005h, 0cdh, 006h, 0f6h, 0f1h, 080h, 047h, 0cdh, 009h, 0f6h, 0c1h
        db      0c9h, 0cdh, 0f7h, 0f9h, 0c3h, 06eh, 0f9h, 0c5h, 0d5h, 0e5h, 0ddh, 0e5h, 0afh, 032h, 015h, 0f6h
        db      0d3h, 060h, 021h, 0e7h, 0fah, 0e5h, 04eh, 0cdh, 0fch, 0f7h, 0e1h, 023h, 07eh, 0b7h, 0c2h, 0c5h
        db      0fah, 0cdh, 055h, 0f7h, 0feh, 00dh, 0cah, 0e1h, 0fah, 0f3h, 03eh, 0fch, 0d3h, 0a2h, 0c3h, 066h
        db      080h, 0ddh, 0e1h, 0e1h, 0d1h, 0c1h, 0c9h, 00dh, 052h, 041h, 04dh, 020h, 050h, 041h, 052h, 049h
        db      054h, 059h, 020h, 045h, 052h, 052h, 04fh, 052h, 007h, 000h, 0cdh, 008h, 0fbh, 0fbh, 0c9h, 0f3h
        db      0f5h, 0e5h, 0cdh, 008h, 0fbh, 0e1h, 0f1h, 0c9h, 0edh, 073h, 035h, 0fbh, 031h, 0dch, 0fdh, 0f5h
        db      0e5h, 0cdh, 0e8h, 0eeh, 02ah, 0cbh, 0f3h, 0e5h, 03ah, 0cdh, 0f3h, 0f5h, 0cdh, 0f0h, 0f3h, 0cdh
        db      051h, 0fah, 0f1h, 032h, 0cdh, 0f3h, 0d3h, 0a2h, 0e1h, 022h, 0cbh, 0f3h, 07ch, 0d3h, 0a1h, 07dh
        db      0d3h, 0a0h, 0e1h, 0f1h, 031h, 02dh, 0e2h, 0c9h, 03eh, 059h, 032h, 0c3h, 0f3h, 032h, 0c4h, 0f3h
        db      03eh, 0c9h, 032h, 062h, 0eeh, 001h, 081h, 002h, 011h, 001h, 000h, 021h, 000h, 0feh, 03eh, 001h
        db      0cdh, 044h, 0f0h, 021h, 001h, 0feh, 006h, 00bh, 07eh, 0feh, 020h, 038h, 00bh, 0feh, 05bh, 030h
        db      007h, 023h, 005h, 020h, 0f3h, 0c3h, 05ch, 0f6h, 03eh, 0ffh, 032h, 0f8h, 0f3h, 032h, 0f6h, 0f3h
        db      03eh, 004h, 032h, 0f9h, 0f6h, 03eh, 0c8h, 032h, 062h, 0eeh, 0c3h, 05ch, 0f6h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 0fah
        db      0fah, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0ffh, 0ffh, 0ffh, 0ffh, 0ceh, 0ffh, 0efh, 020h, 07fh, 0c1h, 03fh, 0ffh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0d2h, 022h, 05fh, 0fch, 000h, 000h, 000h, 000h, 000h, 041h, 04bh, 0c7h, 022h, 092h, 0efh
        db      073h, 04bh, 08bh, 080h, 080h, 080h, 080h, 080h, 080h, 080h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0feh, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 0ffh, 000h, 000h
        db      000h, 000h, 000h, 0d7h, 0b4h, 011h, 008h, 080h, 080h, 080h, 080h, 080h, 080h, 080h, 080h, 080h
        db      080h, 080h, 080h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 002h, 000h, 00fh, 000h, 001h, 010h, 002h, 000h, 00fh, 000h, 000h
        db      080h, 000h, 000h, 0ffh, 081h, 000h, 001h, 00ah, 087h, 0fbh, 02bh, 0e2h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 0a1h, 0efh, 04dh, 0efh, 065h, 0efh, 0edh, 0efh
        db      0cdh, 0efh, 0cdh, 0efh, 04dh, 0efh, 03bh, 0eeh, 04eh, 0eeh, 01ah, 0eeh, 042h, 000h, 042h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 032h, 034h, 07bh, 083h, 032h, 034h
        db      043h, 030h, 031h, 043h, 032h, 034h, 035h, 030h, 037h, 043h, 044h, 035h, 0deh, 0f0h, 000h, 000h
        db      001h, 002h, 022h, 0fbh, 054h, 003h, 001h, 002h, 00eh, 0e2h, 054h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 0f1h, 0eeh, 034h, 004h, 022h, 0fah, 000h, 0f8h, 06bh, 0f8h
        db      06bh, 0f8h, 0b0h, 0f8h, 0aeh, 0f7h, 021h, 0e2h, 0f0h, 000h, 03eh, 000h, 03eh, 000h, 039h, 0e2h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
        db      0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h, 0e5h
BiosDataEnd     equ     $

        end


