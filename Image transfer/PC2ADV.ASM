;******************************************************************************
;
;  
;  PC2Adv - Transfer disk image from PC to a NortStar Advantage using
;           a SIO board in port 1 or 2. 
;
;       This program is a PC2Flop-like program. It borrows much of the 
;       ideas and the code of these programs written by Mikle Douglas. 
;       His PC2Flop programs normally run without an OS but PC2Adv uses 
;       CP/M for writing the disk data and the console IO.
;
;       - write raw data of double sided doubble density disk in drive A or B
;         (512 bytes per sector, 10 sectors per track, 70 tracks). 
;       - use SIO board in port 1 or port 2 for the transfer of a disk image 
;         using the XMODEM protocol. The disk image is the linear sequence 
;         of the 512 byte sectors from track 0, sector 0 through 
;         track 69, sector 9
;
;	This program only runs under CP/M.
;
;	Written by Holger Linning
;
;	Rev	 Date	    Desc
;	1.0	01/16/20    Original 
;
;  based on:
;
;
;  PC2Flop - Transfer disk image from PC to floppy over serial port
;	     using the IMSAI SIO-2 serial board and the North Star
;	     single density floppy controller.
;
;	This program writes a North Star single density disk from a disk image
;       transmitted from a PC. The image is transmitted through a serial port
;       using the XMODEM checksum protocol. The image is written directly to
; 	the floppy in raw format (256 bytes per sector, 10 sectors per track,
;	35 tracks). The disk image is the linear sequence of 256 byte sectors
;	from track 0, sector 0 through track 34 sector 9.
;
;	This program runs standalone at 0x100 or under CP/M.
;
;	Written by Mike Douglas
;
;	Rev	 Date	    Desc
;	1.0	09/22/19    Original
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

NUMTRK	equ	70		;number of tracks
NUMSEC	equ	40		;number of sectors per track (logical CPM sectors)
SECLEN	equ	128		;sector length (logical CPM sectors)
MINDRV	equ	0		;first drive number
MAXDRV	equ	1		;max drive number 

TRKLEN	equ	(NUMSEC*SECLEN)	;length of track in bytes

; CP/M start addresses
BIOSPTR equ     0000h+1         ;pointer to BIOS 
BDOSPTR equ     0005h+1         ;pointer to BDOS         

; BIOS jump table entry points
BOOT	equ     00h             ;Cold start 
WBOOT	equ     BOOT+3          ;Warm boot
CONST	equ     BOOT+6          ;Console status
CONIN	equ     BOOT+9          ;Console input
CONOUT	equ     BOOT+12         ;Console output
LIST	equ     BOOT+15         ;Printer output
PUNCH	equ     BOOT+18         ;Paper tape punch output
READER	equ     BOOT+21         ;Paper tape reader input
HOME	equ     BOOT+24         ;Move disc head to track 0
SELDSK	equ     BOOT+27         ;Select disc drive
SETTRK	equ     BOOT+30         ;Set track number
SETSEC	equ     BOOT+33         ;Set sector number
SETDMA	equ     BOOT+36         ;Set DMA address
READ	equ     BOOT+39         ;Read a sector
WRITE	equ     BOOT+42         ;Write a sector

; XMODEM equates
        IF      NOT ADE
SOH	equ	001h
EOT	equ	004h
ACK	equ	006h
NAK	equ	015h
        ENDIF

        IF      ADE
DUMMY   equ     0ffh
SOH	equ	DUMMY           ;use dummy values for XMODEM            
EOT	equ	DUMMY           
ACK	equ	DUMMY
NAK	equ	DUMMY
        ENDIF

PKTLEN	equ	128		;128 byte xmodem packet length
XMTRIES	equ	10		;number of xmodem retries

; character equates
CR	equ	13		;ascii for carriage return
LF	equ	10		;ascii for line feed
DEL	equ	7Fh		;ascii DEL
BS	equ	08h		;ascii backspace
CTRLC	equ	03		;ascii for control-c

	org	0100h	
;-----------------------------------------------------------------------------
;  Initialize for transfer
;-----------------------------------------------------------------------------
init	lxi	sp,ourStk	;initialize stack pointer

        lhld    BIOSPTR
        dcx     h
        dcx     h
        dcx     h
        shld    biosStart       ;save start of BIOS

	call	setDrvN		;set drive names 
	call	sizeRam		;determine amount of RAM available
	mvi	a,MINDRV	;a=default drive
	sta	drvNum		;need for pgmExit

        IF      ADE
        lxi     h,0000h
        shld    helpVal         ;init help var for debugging
        ENDIF


;  Display welcome message, then get the drive number and port number
;    to use for the transfer from the operator.

	lxi	h,mWelcom	;display welcome message
	call	dispMsg

; getDrv - get drive letter from the user.

getDrv	lxi	h,mDrive	;display drive number prompt
	call	dispMsg
	call	rcvCon		;get byte from the console
	ori	20h		;upper case letters to lower case
	cpi	'x'		;exit requested?
	jz	pgmExit		;yes
	lxi	h,baseDrv	;ascii 1st drive - baseDrv = 0
	sub	m
	jm	getDrv		;error, entry was < first drive
	cpi	MAXDRV-MINDRV+1	;validate <= max drive
	jnc	getDrv		;invalid, prompt again
	adi	MINDRV		;restore offset of 1st drive (if any)
	sta	drvNum		;save the drive number to use

; Verify drive is not write protected

	call	dRestor		;restore to track 0 (selects drive)

; getPort - get serial port number 1-2 from the user.

getPort	lxi	h,mPort		;display transfer port prompt
	call	dispMsg
	call	rcvCon		;get byte from the console
	ori	20h		;upper to lower case, nums not affected
	cpi	'x'		;exit requested?
	jz	pgmExit		;yes
	sui	'1'		;'1' to 0
	cpi	2		;validate input was '1' or '2'
	jnc	getPort		;invalid, prompt again
	sta	xfrPort		;save the port to use

; Prompt the user to insert the disk to write, initialize, then start
;   sending NAK to start the XMODEM reception.

	lxi	h,mStart	;display start file transfer prompt
	call	dispMsg
        
	xra	a		;init track counter
	sta	curTrk          ;start with track 0
	
        inr	a		;init xmodem block number to one
	sta	blkNum

	mvi	a,NAK		;send starting nak after purging input data
	call	purgSio         

;-----------------------------------------------------------------------------
;  mainLp - Receive as many packets as will fit into RAM and then write
;      tracks to disk. Repeat until entire disk is written. 
;-----------------------------------------------------------------------------
mainLp	lxi	h,mRecv		;display "Receiving"	
	call	dispMsg
        
        call    initBf          ;init buffering 
        
        call	bufPkts		;buffer as many packets as possible

	lhld	rcvPtr		;hl=start of last packet received
	xchg			;de=start of last packet received
	lxi	h,trkBuf	;hl=start of track buffer
	call	cmpDeHl		;compare last packet start - trkBuf
	jc	allDone		;nothing received but an EOT

        lxi	h,mWrite	;display "Writing"	
	call	dispMsg

; trkLoop - write tracks until all disk tracks have been written or all
;    the tracks in the buffer have been written.

trkLoop	call	wrtTrak		;write a track

        lda     wrtTrk          ;increment written tracks in buffer 
	inr	a
	sta	wrtTrk	

        call    setNTrk         ;set next track (return in a)

	cpi	NUMTRK		;done all tracks?
	jz	allDone		;yes
        
	call	getEndB		;hl=end of written tracks in buffer
	xchg			;de=next track pointer
	lhld	rcvPtr		;hl=start of last packet received
	call	cmpDeHl		;compare end of buffer - rcvPtr

	jc	trkLoop		;another track is present

	lda	eotFlag		;see if EOT terminated the reception
	cpi	EOT	
	jz	allDone		;if so, probably a single side disk
	mvi	a,ACK		;ACK the last packet or EOT
	call	sndByte
	jmp	mainLp		;go receive more packets

; allDone - The disk is completely written. ACK the final packet (or EOT),
;     display the "transfer complete" message and start the program over.

allDone	mvi	a,ACK		;ACK the final packet or EOT
	call	sndByte
	lxi	h,mDone		;hl->done message
	call	dispMsg
	jmp	getDrv		;start over asking for drive num

;-----------------------------------------------------------------------------
; bufPkts - Receive XMODEM packets until we fill all the track buffer
;   space available. Reception starts at the address pointed to by
;   rcvPtr. Reception is stopped when the last packet exactly
;   fills the end of the last track spot in RAM. rcvPtr is
;   updated on exit to point to the start of the last packet received.
;   The disk write routines use this pointer to know where data ends and
;   then update rcvPtr to start to where to begin receiving new packets.
;-----------------------------------------------------------------------------
bufPkts	lhld    rcvPtr
        call	rcvPkt		;receive a packet (Pointer to buffer in HL) 

        push    h
	call    dispPgs         ;show progress
        pop     h

	xchg			;de=current xmodem receive pointer
	sta	eotFlag		;save status returned (may be EOT)
	cpi	EOT		;EOT received?
	jz	bufDone		;yes, buffering is done
	lhld	bufEnd		;hl=end of buffering space
	call	cmpDeHl		;compare current-end	
	jnc	bufDone		;past or at end, buffering is done
	mvi	a,ACK		;otherwise, ACK the packet
	call	sndByte
	xchg			;put xmodem rcv pointer back in HL
	jmp	bufPkts		;buffer some more

; bufDone - no more room for packets. Update rcvPtr to point to the 
;   start of the last packet received so the disk write routines know
;   where data ends.

bufDone	shld	rcvPtr		;save use by write tracks
	ret

;-----------------------------------------------------------------------------
; rcvPkt - receive an xmodem format 128 byte packet. HL points to the 128 byte
;    buffer to receive. HL is updated by 128 bytes after each succuessful
;    reception of a new 128 byte packet.
;-----------------------------------------------------------------------------

nakPkt	pop	h		;get HL back
	mvi	a,NAK
	call	purgSio		;purge receive for 1s then transmit NAK

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
   	xra	a		   ;return a zero
        ret
        ENDIF
        
        push	h		;save HL for retries
waitSoh	call	chkQuit		;check for user abort
	mvi	a,3		;3 second timeout for soh
	call	rcvByte		;receive character with timeout
	jz	nakPkt		;timeout
	cpi	SOH		;SOH received?
	jz	haveSoh
	cpi	EOT		;EOT to say we're done?
	jnz	waitSoh		;no, keep looking for SOH
	pop	h		;undo the entry push
	ret			;return with EOT

;  Have SOH, receive block number and not block number

haveSoh	mvi	a,1		;one second timeout once inside a packet
	call	rcvByte		;get the block number
	jz	nakPkt		;timeout, NAK and start over
	sta	rcvBlk		;save the received block number
	mvi	a,1		;one second timeout
	call	rcvByte		;get not block number
	jz	nakPkt		;timeout, NAK and start over
	sta	rcvNBlk		;save not block number

;  Receive the 128 byte block

	mvi	e,0		;init checksum
	mvi	d,pktLen	;d is byte counter
pktLoop	mvi	a,1		;one second timeout
	call	rcvByte		;get next data byte
	jz	nakPkt		;timeout
	mov	m,a		;store the character
	inx	h		;point to next byte
	add	e		;update the checksum
	mov	e,a
	dcr	d		;decrement bytes remaining
	jnz	pktLoop

;  Verify the checksum

	mvi	a,1		;one second timeout
	call	rcvByte		;get the checksum
	jz	nakPkt		;timeout
	cmp	e		;checksum match?
	jnz	nakPkt		;no, packet error

;  Checksum good. Verify block numbers

	lda	rcvNBlk		;verify rcvBlk = not (rcvNBlk)
	cma			;A should = block number now
	mov	b,a		;save in b
	lda	rcvBlk
	cmp	b		;compare rcvBlk = not(rcvNBlk)?
	jnz	nakPkt		;no, error
	lda	blkNum		;compare rcvBlk = expected blkNum
	cmp	b
	jnz	nakPkt		;nak if not the same (also nak's re-send)
	inr	a		;increment expected block number
	sta	blkNum
	pop	b		;get HL off stack, but don't clobber HL
	xra	a		;return a zero
        shld    rcvPtr          ;point to next block
	ret

;-----------------------------------------------------------------------------
; wrtTrak - write NUMSEC sectors to the current track in trkBuf
;   as pointed to by trkPtr. After the track is written, trkPtr is updated
;   by the length of a track to point to the next track buffer. 
;-----------------------------------------------------------------------------
wrtTrak	lxi	h,mCRLF	        ;new line for next blocks	
	call	dispMsg

        call    initT           ;init track writing 
        call	dSeek		;seek to the track

; wrtLoop - write a full track starting sector 0

wrtLoop	call	chkQuit		;check for ctrl-c
        call	setSect		;set desired sector 
	call	dWrite		;write the sector
	call    dispPgs         ;show progress
        call	setNSec	        ;set next sector 
        call    setOffs         ;set new offset in buffer
        lda     wrtSec
        dcr     a
        sta     wrtSec          ;decrement sectors to write
        jnz	wrtLoop		;loop until all sectors written
	ret

;-----------------------------------------------------------------------------
; dispMsg - display the null-terminated message passed in hl on the
;    console device. Clobbers c, hl
;-----------------------------------------------------------------------------
dispMsg	mov	a,m		;get the next message byte
	ora	a		;null terminates
	rz
        
	mov	c,a		;CONOUT wants character in c
        mvi     e,CONOUT
	call	BIOS
	inx	h		;move to next byte
	jmp	dispMsg

;-----------------------------------------------------------------------------
; dispPgs - display progress
;    Clobbers c
;-----------------------------------------------------------------------------
dispPgs	mvi	c,'.'		;CONOUT wants character in c
        mvi     e,CONOUT
	call	BIOS
	ret	

;-----------------------------------------------------------------------------
; rcvCon - Receive a character from the console device, echo it, then
;   wait for a CR. Exits program if Ctrl-c typed. Returns with invalid
;   character (null) if BS or DEL pressed after 1st character
;   Returns character in a, clobbers c.
;-----------------------------------------------------------------------------
rcvCon	mvi     e,CONIN
        call	BIOS		;check for input

	ani	7fh
	cpi	CTRLC		;abort requested?
	jz	pgmExit		;yes

	cpi	CR		;return pressed?
	rz			;yes, don't echo it

	mov	c,a		;CONOUT needs character in c
        mvi     e,CONOUT
	call	BIOS            ;echo it

; Wait for CR, then return 1st character typed
rcvCr	mvi     e,CONIN
        call	BIOS		;check for input

	ani	7fh
	cpi	CTRLC		;abort requested?
	jz	pgmExit		;yes

	cpi	DEL		;delete
	rz			;yes, return DEL character

	cpi	BS		;backspace?
	rz			;yes, return BS character
	cpi	CR		;return pressed?

	jnz	rcvCr		;no, keep waiting
	mov	a,c		;return 1st character typed
	ret

;-----------------------------------------------------------------------------
; purgSio - Wait for 1 second of idle time on receive line, then transmit the
;	character passed in A (usually ACK or NAK). Clobbers b
;-----------------------------------------------------------------------------
purgSio	push	a
purge	mvi	a,1		;1 second timeout
	call	rcvByte		;wait for 1 second without activity

        IF NOT ADE              ;wait only on real machine
	jnz	purge
        ENDIF

	pop	a		;get back the character to send
				;fall through to sndByte
;-----------------------------------------------------------------------------
; sndByte - send the byte in a through the specified transfer port. 
;     Clobbers b. (assuming serOut clobbers only a).
;-----------------------------------------------------------------------------
sndByte	mov	b,a		;b=byte to transmit
	lda	xfrPort		;a=port to use for transfer
	jmp	serOut		;send the character

;-----------------------------------------------------------------------------
; rcvByte - Receive a byte from the specified transfer port. A wait timeout
;     in seconds is specified in a. If a timeout occurs, zero is returned in
;     a and the zero flag is true. Otherwise, the character is returned in a 
;     (could be zero) and the zero flag is false. ONESEC must be set based on
;     processor speed and the number of cycles in the serIn call + 59.
;     Clobbers a, b and c.
;-----------------------------------------------------------------------------
rcvByte	push	d		;save d, e
	mov	d,a		;save timeout in d

initSec	lxi	b,ONESEC	;bc=cycles through this loop for 1s
rcvWait	lda	xfrPort		;(13) a=port to use for transfer
	call	serIn		;(17+42) look for a byte
	jnz	haveChr		;(10) byte received
	dcx	b		;(5) otherwise, decrement timer
	mov	a,b		;(5) one second expire?
	ora	c		;(4)
	jnz	rcvWait		;(10) no, keep waiting

; one second timeout has occured. Decrement the seconds counter.

	dcr	d		;decrement seconds counter
	jnz	initSec		;initialize for another 1 second count
haveChr	pop	d		;restore d, e
	ret

;--------------------------------------------------------------
; chkQuit - check for the user to request abort (ctrl-c). If
;    a character is present on the console port, read it and
;    see if ctrl-c. Clobbers A
;--------------------------------------------------------------
chkQuit	mvi     e,CONST
        call	BIOS		;check for console input
        cpi     00h             ;0 = no character
	rz
        
	ani	7fh
	cpi	CTRLC		;abort requested?
	rnz			;no

; Ctrl-C typed while program is running. Return to drive prompt.

	lxi	sp,ourStk	;initialize stack pointer
	jmp	getDrv		;start over asking for drive num

;--------------------------------------------------------------
; pgmExit - Exit to CP/M 
;--------------------------------------------------------------

; CP/M exit. If boot drive was used, prompt user to insert CP/M disk

pgmExit	lda	drvNum		;boot drive used?
	sui	MINDRV
	jnz	noDisk		;not 1, disk prompt not needed
        
	lxi	h,mCpm		;display "insert cp/m disk"	
	call	dispMsg
	call	rcvCon		;wait for a character
        
noDisk	lxi	h,mExit		;display "exiting" message
	call	dispMsg
        
        lhld    biosStart
        mvi     d,00h
        mvi     e,WBOOT
        dad     d
	pchl		        ;reboot CP/M

;--------------------------------------------------------------
; We're running under CP/M. Change drive prompt message to show drive
;    letters instead of drive numbers and change baseDrv to convert
;    an 'A' to the base drive number (MINDRV).
;--------------------------------------------------------------

setDrvN	mvi	a,'A'		;'A' in drive message instead of number
	sta	mDrvMin
	adi	MAXDRV-MINDRV	;max drive letter
	sta	mDrvMax
	mvi	a,'a'		;ascii 1st drive - baseDrv = 0
	sta	baseDrv
	ret

;------------------------------------------------------------------
; sizeRam - determine how much RAM we have for buffering tracks.
;   Sets the bufEnd variable which points to end address of 
;   the last possible track buffer + 1
;------------------------------------------------------------------
sizeRam	lhld	BDOSPTR		;get address of BDOS

; ramEnd - end of RAM found. Now determine the end address + 1 of the
;   last track buffer that will fit in RAM. Store in bufEnd

ramEnd	xchg			;de=end of RAM + 1
	mvi	a,-((TRKLEN SHR 8) + 1) AND 0ffh
	cmp	d		;force de < (10000h - TRKLEN)
	jnc	topOk
	mov	d,a		;limit max address
topOk	lxi	h,trkBuf	;hl=start of track buffer
	lxi	b,TRKLEN	;bc=length of track in bytes

; Loop increasing hl by TRKLEN until hl > end of RAM.

bfEndLp	dad	b		;hl=hl+track length
	call	cmpHlDe		;compare hl-de
	jc	bfEndLp		;still more room, keep going

; Subtrack one track length from hl, this will be the end address + 1 of
;   the the last track buffer that will fit in RAM

	lxi	b,-TRKLEN	;subtract one track length
	dad	b		;hl = end address of last track + 1
	shld	bufEnd		;save as bufEnd
	ret

;--------------------------------------------------------------------
; cmHlDe - compare HL-DE. Carry set if HL<DE, carry clear if HL>=DE
;--------------------------------------------------------------------
cmpHlDe	mov	a,l		;compare HL-DE, do lsbs first
	sub	e
	mov	a,h		;do msbs
	sbb	d
	ret			;carry set HL<DE, clear HL>=DE

;--------------------------------------------------------------------
; cmDeHl - compare DE-HL. Carry set if DE<HL, carry clear if DE>=HL
;--------------------------------------------------------------------
cmpDeHl	mov	a,e		;compare DE-HL, do lsbs first
	sub	l
	mov	a,d		;do msbs
	sbb	h
	ret			;carry set DE<HL, clear DE>=HL

;--------------------------------------------------------------------
; subHlDe - HL=HL-DE
;--------------------------------------------------------------------
subHlDe	mov	a,l		;subtract HL-DE, do lsbs first
	sub	e
	mov	l,a		;lsb result in l
	mov	a,h		;do msbs
	sbb	d
	mov	h,a		;msb result in h	
	ret
;-----------------------------------------------------------------------------
;   Data Area
;-----------------------------------------------------------------------------
mWelcom	db	cr,lf,lf
	db	'===== PC to Northstar Advantage Image Transfer v1.0 ====='
	db	cr,lf,lf	
	db	'This program writes a North Star Advantage floppy from'
	db	cr,lf
	db	'a disk image received through a serial port via XMODEM.',0

mDrive	db	cr,lf,lf,'Insert and specify destination drive ('
mDrvMin	db	'x-'
mDrvMax	db	'x) or X to exit: ',0

mPort	db	cr,lf,lf
	db	'Specify the port of the SIO card to use for the image ',cr,lf
	db	'transfer (1-2) or X to exit: ',0

mStart	db	cr,lf,lf
	db	'Start XMODEM send now...',0

mDone	db	cr,lf,lf,'Creation of new disk successful!',cr,lf,0

mExit	db	cr,lf,lf,'Exiting...',cr,lf,0

mCpm	db	cr,lf,lf
	db	'Insert CP/M disk into drive A, then press Return...',0

mRecv	db	cr,lf,lf
	db	'Receiving image data from PC (dot = XMODEM packet)',cr,lf,lf,0

mWrite	db	cr,lf,lf
	db	'Writing buffer to floppy disk (line = track, dot = sector)',cr,lf,0

mCRLF	db	cr,lf, 0

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

SIOACR	equ	51h		;control, SIO Board in slot 1
SIOADR	equ	50h		;data, SIO Board in slot 1

SIOBCR	equ	41h		;control, SIO Board in slot 2
SIOBDR	equ	40h		;data, SIO Board in slot 2

SIORDA	equ	02h		;read data available flag
SIOTRE	equ	01h		;transmit register empty flag

SIOCTL	equ	08h		;interrupt control register

; The rcvByte subroutine above times a one second timeout with a code
;    loop that calls the hardware specific serIn routine below. ONESEC
;    must be set based on processor speed and the number of cycles in 
;    the serIn call + 59 cycles for the rcvByte code. 

ONESEC	equ	39604		;rcvByte loop count for 1 second (4mhz)

;----------------------------------------------------------------------------
; Hardware specific I/O
; serIn - input character from port specified in a
;       0 = first serial port
;       1 = second serial port
;    inputs: a = port to read from
;    outputs: z true if no character present
;	      z false if character returned in a
; 42 cycles including return when no character present
;-----------------------------------------------------------------------------
serIn	ora	a		;(4) port 0 or 1?
	jnz	s2InB		;(10) port 1, 2nd serial port

; Input from 1st serial port

s2InA	in	SIOACR		;(10+1) see if a new character is present
        
        IF      ADE
        mvi     a,SIORDA        ;character always available if ADE
        ENDIF
	
        ani	SIORDA		;(7)
	rz			;(10) no character, return zero status
	in	SIOADR		;return character and non-zero status

        IF      ADE
        mvi     a,DUMMY         ;use just dummy character 
        ENDIF

	ret	
	
; Input from 2nd serial port

s2InB	in	SIOBCR		;(10+1) see if a new character is present
        
        IF      ADE
        mvi     a,SIORDA        ;character always available if ADE
        ENDIF
	
	ani	SIORDA		;(7)
	rz			;(10) no character, return zero status
	in	SIOBDR		;return character and non-zero status

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
;	     b = character to send
;-----------------------------------------------------------------------------
serOut	ora	a		;port 0 or 1 ?
	jnz	s2OutB		;second serial port

; Send character through console serial port

S2OutA	in	SIOACR		;wait for OK to transmit
	ani	SIOTRE
	jz	S2OutA
	mov	a,b		;a=character to transmit
	out	SIOADR		;send it
	ret

; Send character through second serial port

s2OutB	in	SIOBCR		;wait for OK to transmit
	ani	SIOTRE
	jz	s2OutB
	mov	a,b		;a=character to transmit
	out	SIOBDR		;send it
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

jmpBIOS lhld    biosStart       ;start of BIOS in HL
        mvi     d,00h
        dad     d               ;offset for BIOS call in E
        pchl                    ;jump to BIOS routine

;***Subroutine**************************************
; initBf - init vars for buffer 
;***************************************************

initBf: lxi     h,trkBuf        ;buffer start
        shld    trkPtr          ;reset pointer
        shld    rcvPtr
        xra	a
        sta     wrtTrk          ;init count of written tracks
        ret

;***Subroutine**************************************
; initT - init vars for writing track 
;***************************************************

initT:  xra	a
        sta     curSec          ;start at sector 0
        mvi	a,NUMSEC	;init count of sectors to write
        sta     wrtSec         
        call    getEndB         ;get start of buffer in HL
        shld    trkPtr          ;pointer to free buffer
        ret

;***Subroutine******************************
; setNTrk - set next track number
;*******************************************

setNTrk:lda	curTrk	        ;current track accessed
        inr     a               ;move to next track 
        sta     curTrk          ;new current track
	ret 			

;***Subroutine**************************************
; dWrite - Write sector on current track to buffer at prt.
;***************************************************

dWrite: lhld    trkPtr          ;pointer in buffer
        mov	b,h		;set dma address in BC
        mov	c,l		
        mvi     e,SETDMA
        call    BIOS            ;set dma address
        mvi     c,01h           ;write must be immediate 
        mvi     e,Write          
        call    BIOS            ;write track
	ret			
        
;***Subroutine*************************
; dRestor - Restore to track 0
; On Exit:
;   curTrk = 0 
;**************************************

dRestor: call	setDrv		;select drive
        xra     a
	sta	curTrk		;current track = 0
        mvi     e,HOME          
        call    BIOS            ;move head to track 0
	ret			

;***Subroutine**************************************
; dSeek - set drive and track
;***************************************************

dSeek:	lda	curTrk		;load track number
        mvi	b,00h		;set track number in BC
        mov	c,a		
        mvi     e,SETTRK          
        call    BIOS            ;set track
	ret			
        
;***Subroutine********************************
; setDrv - Select drive.
;*********************************************

setDrv: lda     drvNum
        mvi     b,00h
        mov	c,a		;set drive number in c
        mvi     e,SELDSK          
        call    BIOS            ;set drive
	ret			
        
;***Subroutine******************************
; setNSec - set next sector number
;*******************************************

setNSec:lda	curSec	        ;last sector accessed
        inr     a               ;move to next sector 
        sta     curSec          ;new current sector
	ret 			

;***Subroutine******************************
; setSect - set current sector.
;*******************************************

setSect:lda	curSec		;current sector
        mvi     b,00h
        mov	c,a		;set sector number in BC
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
        lda	curSec	        ;number of logical sector to write
        lxi     h,trslate       ;load start of translation table to HL
        mvi     d,00h
        mov     e,a             ;load current logical sector to DE
        dad     d               ;add to get address of number of physical sector
        mov     a,m             ;load physical sector number to a
        pop     h
        
        stc
        cmc			;clear carry
	rar
	mov	d,a		;D=sector >> 1
	rar			;put lsbit into msbit	
	ani	80h
	mov	e,a		;DE = 128 * sector
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

drvNum	ds	1		;drive number to use
curTrk	ds	1		;current track number drive is on
trkPtr	ds	2		;pointer into trkBuf at sector boundaries
wrtTrk	ds	1		;count of tracks already written
wrtSec	ds	1		;count of sectors already written
curSec	ds	1		;current logical sector on track
bufEnd	ds	2		;end address + 1 of last track spot in RAM
helpVal ds      2               ;dummy value
        
; xmodem variables

xfrPort	ds	1		;pseudo port for file transfer
blkNum	ds	1		;current xmodem block number
rcvBlk	ds	1		;block number received
rcvNBlk	ds	1		;"not" block number received
rcvPtr	ds	2		;pointer for start of XMODEM send

; misc variables

biosStart  ds	2		;start of BIOS
baseDrv	   ds	1		;ascii 1st drive - baseDrv = 0
eotFlag	   ds	1		;set to EOT if EOT terminated reception
	   ds	512		;stack space

ourStk	equ	$
	ds	PKTLEN		;space for pre-pended unsent data
	
        org	1000h		;buffer
trkBuf	equ	$

	end


