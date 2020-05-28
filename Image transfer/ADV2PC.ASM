;*****************************************************************************
;  
;  Adv2PC - Transfer floppy image from a NortStar Advantage to PC using
;           a SIO board in port 1 or 2. 
;
;
;       This program is a Flop2PC-like program. It borrows much of the 
;       ideas and the code of these programs written by Mikle Douglas. 
;       His Flop2PC programs normally run without an OS but Adv2PC uses 
;       CP/M for reading the disk data and the console IO.
;
;       - copy raw data of double sided doubble density disk in drive A or B
;         (512 bytes per sector, 10 sectors per track, 70 tracks). 
;         The disk image is the linear sequence of the 512 byte sectors from 
;         track 0, sector 0 through track 69, sector 9
;       - use SIO board in port 1 or port 2 for the transfer using the XMODEM 
;         protocol. 
;
;	This program only runs under CP/M.
;
;	Written by Holger Linning
;
;	Rev	 Date	    Desc
;	1.0	01/15/20    Original 
;
;  based on:
;
;
;  Flop2PC - Transfer floppy image to PC over a serial port using the
;	     IMSAI SIO-2 serial board and the North Star single density
;	     floppy controller.
;
;	This program transmits an image of a North Star single density floppy
;       to a PC over a serial port using the XMODEM protocol. The disk is
;	copied in raw format (256 bytes per sector, 10 sectors per track, 
;	35 tracks). The disk image is the linear sequence of the
;	256 byte sectors from track 0, sector 0 through track 34,
;	sector 9. The leading zeros before the data payload and the checksum
;	are not transferred.
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

	org	0100h		;load address

;-----------------------------------------------------------------------------
;   Initialize for transfer
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

; Prompt the user to start the XMODEM receive operation on the PC. 
;    Wait for a clear receive line for a least one second, then start
;    looking for NAK or 'C' (crc protocol) from the PC

	lxi	h,mStart	;display start file transfer prompt
	call	dispMsg

        IF      ADE
        jmp     haveNak         ;no need to wait
        ENDIF

clrRcv1	call	rcvByte		;loop until input clear for 1 second
	jnz	clrRcv1         

	xra	a		;set CRC flag to false (checksum mode)
	sta	crcFlag
waitNak	call	chkQuit		;give user chance to abort
	call	rcvByte		;wait for a character 
	cpi	NAK
	jz	haveNak		;have a NAK, use checksum protocol
	cpi	'C'		;CRC protocol requested?
	jnz	waitNak		;no
	sta	crcFlag		;set crc flag non-zero = CRC mode

;  NAK or 'C' received meaning the XMODEM receive has started. Initialize
;     for the transfer.

haveNak	xra	a		
	sta	sndTrk          ;no tracks sended so far
	sta	curTrk          ;start with track 0
	inr	a		;init xmodem block number to one
	sta	blkNum
	lxi	h,trkBuf	;trkBuf is initial starting point for
	shld	sndPtr		;   XMODEM send

;-----------------------------------------------------------------------------
;  mainLp - Loop through all tracks on the disk buffering as many tracks
;    as will fit in RAM before sending via xmodem, then repeat.
;-----------------------------------------------------------------------------
mainLp	call    initBf          ;init buffering 
        lxi	h,mRead		;display "Reading"	
	call	dispMsg
        
; Read and buffer tracks 
bufLoop	call	readTrk		;read into trkBuf

        lda     ctrTrk          ;count new read track
        inr     a
        sta     ctrTrk          
        
        call	setNTrk		;set next track (return in a)
       
	cpi	NUMTRK		;done all tracks on the disk?
	jz	sendBuf		;yes, go send the buffered tracks
        
	call	getEndB		;hl=end of used buffer
        xchg			;de=end of used buffer
	lhld	bufEnd		;hl=end of buffering space
	call	cmpDeHl		;compare current-end
        
	jc	bufLoop		;still room, keep going	

; Track buffer is full or all tracks have been read. Send the buffered
;    tracks via xmodem.

sendBuf	lxi	h,mSend		;display "Sending"	
	call	dispMsg
       
        call	sndTrks		;send the buffered tracks via xmodem

        lda     sndTrk          ;before sended tracks
        mov     b,a
        lda     ctrTrk          ;now sended tracks
        add     b
        sta     sndTrk          ;count of all sended tracks

	cpi	NUMTRK		;done all tracks?
	jnz	mainLp		;no, not done yet


; Send EOT and wait for response. Then display the success message and
;    start the program over.

allDone	call	sndEot		;send and get response for EOT

	lxi	h,mDone		;print the all done message
	call	dispMsg

	jmp	getDrv		;start over asking for a drive
	
;-----------------------------------------------------------------------------
; readTrk - read NUMSEC sectors from the current track into a trkBuf as
;   pointed to by trkPtr. After the track is read, trkPtr is updated
;   by the length of a track to point to the next track buffer.
;-----------------------------------------------------------------------------
readTrk	call    initT           ;init track reading 
        call	dSeek		;seek to current track

; secLoop - Read an entire track. Start at sector 0

secLoop	call	chkQuit		;check for ctrl-c
        call	setSect		;set desired sector 
	call	dRead		;read the sector

	call    dispPgs         ;show progress

	call	setNSec		;next sector 
        call    setOffs         ;new buffer offset
        
        lda     curSec          
	cpi	NUMSEC	        ;all sectors read?
	jnz	secLoop
        
        lxi	h,mCRLF	        ;new line for next sectors	
	call	dispMsg
	
        ret

;-----------------------------------------------------------------------------
; sndTrks - send the tracks buffered in trkBuf via xmodem. trkPtr points
;    to the end+1 of the data to send
;-----------------------------------------------------------------------------
sndTrks	call	getEndB		;hl=end of used buffer
       	shld	trkPtr		;set pointer to end of used buffer
	xchg			;de=end of buffered data + 1
	lhld	sndPtr		;hl=start tranmission address
        
sndLoop	push	d		;save end pointer
	call    dispPgs         ;show progress
        call	sndPkt		;send a packet
	pop	d		;de=end pointer

; At this point, hl->start of next packet and de->last byte read from disk+1.
;    If the next XMODEM packet will go past the end of the disk data,
;    we don't want to send it yet.

	lxi	b,PKTLEN	;bc=length of XMODEM packet
	dad	b		;hl=address at end of NEXT packet + 1
	call	cmpDeHl		;compare disk end - end of next packet
	jc	sndDone		;next packet will pass the end, stop
        
	lxi	b,-PKTLEN	;restore hl
	dad	b
	jmp	sndLoop

; sndDone - all the packets we can send have been sent. Move any bytes
;    left over to just before the start of trkBuf. The next group of
;    xmodem packets will be transmitted starting there.

sndDone	call	subDeHl		;hl=de-hl = left over byte count - PKTLEN
	mov	a,l		;a=left over count - PKTLEN
	adi	PKTLEN		;a=left over byte count
	mov	b,a		;b=count of bytes to move
	lxi	h,trkBuf	;hl->start of trkBuf
	jz	mvDone		;no bytes to move, we're done
	
; Copy the leftover data backwards to just before the track buffer. The
;   next XMODEM send sequence will start at the beginning of this copied
;   data instead of at the start of trkBuf.

moveLp	dcx	h		;hl->memory just before trkBuf
	dcx	d		;de->unsent bytes from end of trkBuf
	ldax	d		;move from end of trkBuf to before trkBuf
	mov	m,a	
	dcr	b
	jnz	moveLp
        
mvDone	shld	sndPtr		;save address from which to send next time
	ret

;-----------------------------------------------------------------------------
; sndPkt - send an xmodem format 128 byte packet. HL points to the 128 byte
;    buffer to send. On exit, HL points to the next 128 byte boundary.
;-----------------------------------------------------------------------------
sndPkt	mvi	a,XMTRIES	;init retry counter
	sta	xmRetry

; First, send header bytes

reSend	call	chkQuit		;check for ctrl-c
	push	h		;save hl for possible re-send
	mvi	a,SOH		;1st byte is SOH
	call	sndByte
	lda	blkNum		;2nd byte is the block number
	call	sndByte
	cma			;2nd complement of block number
	call	sndByte

; Init checksum and CRC and packet length for transmission of data portion

	xra	a		;init crc
	sta	crc16
	sta	crc16+1
	lxi	d,PKTLEN*256	;d=byte counter, e=0 (checksum)

; Loop sending the data bytes and updating checksum and CRC

pktLoop	mov	a,m
	call	sndByte		;send and update checksum in e
	call	calCrc		;update the CRC
	inx	h		;point to next byte
	dcr	d		;decrement bytes remaining
	jnz	pktLoop

; Send checksum or CRC based on crcFlag

	lda	crcFlag		;crc or checksum?
	ora	a
	jz	sndCsum		;flag clear = checksum
        
	lda	crc16+1		;a=high byte of CRC
	call	sndByte		;send it
	lda	crc16		;a=low byte of crc
	jmp	sndSkip		;skip next instruction
	
sndCsum	mov	a,e		;send the checksum byte

sndSkip	call	sndByte

;  All bytes sent. Wait for the response.

	call	rcvByte		;get the response character
	jz	sndFail		;timeout on response
        
	cpi	ACK		;ack received?
	jnz	sndFail		;no, send failed
        
	lda	blkNum		;increment block number
	inr	a
	sta	blkNum
	pop	b		;remove pushed hl, but don't clobber hl
	ret

; sndFail - ACK not received, decrement retry and try again.

sndFail	lxi	h,xmRetry	;point to retry counter
	dcr	m
	jz	xmFail		;retries used up, failed xmodem transfer

; If we've had 3 NAKs on the 1st packet and CRC is selected, assume
;   we took so long to send the 1st packet due to disk retries that
;   the receiver has since timed out and switched to checksum

	lda	crcFlag		;are we in CRC mode
	jz	clrRcv2		;no, ignore the rest of this
        
	lda	blkNum		;on block 1?
	dcr	a
	jnz	clrRcv2		;no, go on

	lda	xmRetry		;failed three times in a row on block 1?
	sui	XMTRIES-3
	jnz	clrRcv2		;no

	sta	crcFlag		;clear crcFlag to force checksum

;  clrRcv2 - wait for one second of line clear time and send packet again.

clrRcv2	call	rcvByte		;wait for 1 second of clear line
	jnz	clrRcv2

	pop	h		;restore pointer to the packet
	jmp	reSend		;re-send the packet

;  xmFail - Display failure message then restart program

xmFail	lxi	h,mXmdm		;xmodem failure message
	call	dispMsg
	lxi	sp,ourStk	;initialize stack pointer
	jmp	getDrv		;start over asking for drive

;-----------------------------------------------------------------------------
; calCrc - update the 16-bit CRC with one more byte. 
;    (Copied from M. Eberhard)
; On Entry:
;   a has the new byte
;   crc16 is current except this byte
; On Exit:
;   crc16 has been updated
;   Trashes a,bc
;-----------------------------------------------------------------------------
calCrc	push	d
	push	h
	lhld	crc16		;get CRC so far
	xra	h		;XOR into CRC top byte
	mov	h,a
	lxi	b,1021h		;bc=CRC16 polynomial
	mvi	d,8		;prepare to rotate 8 bits

; do 8 bit shift/divide by CRC polynomial

cRotLp	dad	h		;16-bit shift
	jnc	cClr		;skip if bit 15 was 0
	mov	a,h		;CRC=CRC xor 1021H
	xra	b
	mov	h,a
	mov	a,l
	xra	c
	mov	l,a
cClr	dcr	d
	jnz	cRotLp		;rotate 8 times

; save the updated CRC and exit

	shld	crc16		;save updated CRC
	pop	h
	pop	d
	ret

;-----------------------------------------------------------------------------
;  sndEot - send EOT character and wait for ACK response
;-----------------------------------------------------------------------------
sndEot	mvi	a,XMTRIES	;init retry counter
	sta	xmRetry
reEot	mvi	a,EOT		;send the EOT
	call	sndByte
	call	rcvByte		;wait for response
	jz	eotFail		;timeout
	cpi	ACK		;ack received?
	jnz	eotFail		;no, eot send failed
	ret			;otherwise, we're done.

; timeout waiting for ACK to EOT. Decrement retry counter and try again

eotFail	lxi	h,xmRetry	;point to retry counter
	dcr	m
	rz			;just give up - xfer was probably good
clrRcv3	call	rcvByte		;wait for 1 second of clear line
	jnz	clrRcv3
	jmp	reEot		;try again

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
; sndByte - send the byte in a through the specified transfer port. 
;     Adds the byte to register e for checksum. Clobbers b.
;     XMODEM send routine assumes serOut returns with a containing
;     the character sent.
;-----------------------------------------------------------------------------
sndByte	mov	b,a		;b=byte to transmit
	add	e		;update checksum
	mov	e,a		;e=updated checksum
	lda	xfrPort		;a=port to use for transfer
	jmp	serOut		;send the character

;-----------------------------------------------------------------------------
; rcvByte - Receive a byte from specified transfer port with a one second
;     timeout. If a timeout occurs, zero is returned in a and the zero 
;     flag is true. Otherwise, the character is returned in a (could be
;     zero) and zero flag is false. ONESEC must be set based on processor
;     speed and the number of cycles in the serIn call + 59.
;     Clobbers a, b and c.
;-----------------------------------------------------------------------------
rcvByte	lxi	b,ONESEC	;bc=cycles through this loop for 1s

rcvWait	lda	xfrPort		;(13) a=port to use for transfer
	call	serIn		;(17+cycles in serIn)look for a byte
	rnz			;(5)byte received

	dcx	b		;(5)otherwise, decrement timer
	mov	a,b		;(5)one second expire?
	ora	c		;(4)
	jnz	rcvWait		;(10)no, keep waiting
	ret			;return with timeout (zero true and in a)

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
; subDeHl - HL=DE-HL
;--------------------------------------------------------------------
subDeHl	mov	a,e		;subtract DE-HL, do lsbs first
	sub	l
	mov	l,a		;lsb result in l
	mov	a,d		;do msbs
	sbb	h
	mov	h,a		;msb result in h	
	ret

;---------------------------------------------------------------------
; Message constants
;---------------------------------------------------------------------
mWelcom	db	cr,lf,lf
	db	'===== Northstar Advantage to PC Image Transfer, v1.0 ====='
	db	cr,lf,lf
	db	'This program transfers an image of a Northstar Advantage'
	db	cr,lf
	db	'to a PC through a serial port using XMODEM.',0

mDrive	db	cr,lf,lf,'Insert floppy and specify source drive ('
mDrvMin	db	'x-'
mDrvMax	db	'x) or X to exit: ',0

mPort	db	cr,lf,lf
	db	'Specify the port of the SIO card to use for the image ',cr,lf
	db	'transfer (1-2) or X to exit: ',0

mStart	db	cr,lf,lf,'Start XMODEM receive operation on the PC now...',cr,lf,0

mDone	db	cr,lf,lf,'Transfer complete!',cr,lf,0

mXmdm	db	cr,lf,lf,'XMODEM communication failure',cr,lf,0

mExit	db	cr,lf,lf,'Exiting...',cr,lf,0

mCpm	db	cr,lf,lf
	db	'Insert CP/M disk into drive A, then press RETURN...',0

mSend	db	cr,lf,lf
	db	'Sending buffer data to PC (dot = XMODEM packet)',cr,lf,lf,0

mRead	db	cr,lf,lf
	db	'Reading floppy data to buffer (line = track, dot = sector)',cr,lf,lf,0

mCRLF	db	cr,lf, 0

;****************************************************************************
;
;  Hardware specific serial I/O routines. 
;     The following routines must be written to provide a common
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
        xra	a
        sta     ctrTrk          ;init count of tracks
                                ;in buffer
        ret

;***Subroutine**************************************
; initT - init vars for reading track 
;***************************************************

initT:  xra	a
        sta     curSec          ;start at sector 0
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
; dRead - Read sector on current track to buffer at prt.
;***************************************************

dRead:	lhld    trkPtr          ;pointer in buffer
        mov	b,h		;set dma address in BC
        mov	c,l		
        mvi     e,SETDMA
        call    BIOS            ;set dma address 
        mvi     e,READ          
        call    BIOS            ;read track
	ret			
        
;***Subroutine**************************************
; dSeek - set drive and track
;***************************************************

dSeek:	call	setDrv		;select drive
	lda	curTrk		;load track number
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
        shld    ptrDPH;         ;save disk parameters
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

        lda     sndTrk          ;tracks sended
        mov     b,a
        lda     curTrk          ;current track
        sub     b               ;don't count tracks that were already sended
        cpi     00h             ;    = (current track - sended tracks)
        jz      cmpSOfS         ;compute sector offset in track

addTr:  dad     d               ;HL = HL + DE
        dcr     a                       
        jnz     addTr           ;on zero: HL = BufferStart + 
                                ;   tracks in buffer * TRKLEN 

;translate sector to find correct buffer position
cmpSOfS push    h               ;HL start address of track in buffer
        lda	curSec	        ;number of logical sector to read
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
        dad     d               ;HL = BufferStart + numTrk * TRKLEN + 128 * sector
        shld    trkPtr          ;new pointer
	ret

;***Subroutine******************************
; getEndB - get end of so far used buffer 
; and return address in HL
;*******************************************
getEndB:lxi     h,TRKLEN        ;track length
        xchg                    ;track length in DE
        lxi     h,trkBuf        ;buffer start

        lda     sndTrk          ;tracks already sended
        mov     b,a
        lda     curTrk          ;current track
        sub     b               ;don't count track that were already sended
        cpi     00h
        rz      
        
addTrB: dad     d               ;HL = HL + DE
        dcr     a                       
        jnz     addTrB          ;on zero: HL = BufferStart + numTrk * TRKLEN 
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
sndTrk	ds	1		;count of tracks already sended
ctrTrk  ds      1               ;count tracks 
curSec	ds	1		;current logical sector on track
bufEnd	ds	2		;end address + 1 of last track spot in RAM
ptrDPH  ds      2               ;address of disk parameter header returned by SELDSK

; xmodem variables

xfrPort	ds	1		;pseudo port for file transfer
xmRetry	ds	1		;xmodem retry counter
blkNum	ds	1		;current xmodem block number
crcFlag	ds	1		;non zero if using CRC instead of checksum
crc16	ds	2		;crc-16 result
sndPtr	ds	2		;pointer for start of XMODEM send

; misc variables

biosStart  ds	2		;start of BIOS
baseDrv	   ds	1		;ascii 1st drive - baseDrv = 0
	   ds	512		;stack space

ourStk	equ	$
	ds	PKTLEN		;space for pre-pended unsent data
	
        org	1000h		;buffer
trkBuf	equ	$

	end

