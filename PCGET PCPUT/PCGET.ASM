; North Star Advantage Version
;
;  of PCGET
;
;  Hacked by Holger Linning for the Advantage Computer
;
;	Ver	Date	   Desc
;   	---    --------    -----------------------------------------------
;	1.0    01/20/20	   Initial version 
;
;
;  North Star Horizon Version. Assumes 4MHz CPU
;
;  PCGET - This CP/M program receives a file from a PC via a serial 
;  port and writes it to a file on the CP/M system. The file transfer uses
;  the XMODEM protocol. 
;
;  Note this program is gutted from the Ward Christenson Modem program.
;
;  Hacked together by Mike Douglas for the Horizon Computer
;
;	Ver	Date	   Desc
;   	---    --------    -----------------------------------------------
;	1.0    10/7/15	   Initial version. This code is almost the same 
;			   as the Vector Graphic version as both use the
;			   same 8251 ports for serial I/O.
;

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

;  Serial Port Equates

SIOACR	equ	51h		;control, SIO Board in slot 1
SIOADR	equ	50h		;data, SIO Board in slot 1

SIOBCR	equ	41h		;control, SIO Board in slot 2
SIOBDR	equ	40h		;data, SIO Board in slot 2

SIORDA	equ	02h		;read data available flag
SIOTRE	equ	01h		;transmit register empty flag


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

;DEFINE ASCII CHARACTERS USED

CTRLC	EQU	3		;Control-C
LF	EQU	10
CR	EQU	13

	org	100h

;  Verify a file name was specified

	lda	PARAM1		;A=1st character of parameter 1
	cpi	' '		;make sure file name present
	jnz	haveFn		;yes, have a file name
	lxi	d,mHelp		;display usage message
	mvi	c,print
	call	bdos
	ret			;return to CPM

;  See if port "B" specified (2nd parameter) (meaning for Advantage: Port B = SIO in Slot 2, else 1)

haveFn	mvi	b,SIOADR	;assume port a used
	lxi	d,mSendA	;port a send message
	lda	PARAM2		;A=1st character of parameter 2
	cpi	'2'		;port b specified?
	jnz	doXfer		;no, go do the transfer
	mvi	b,SIOBDR	;use port b
usePtB	lxi	d,mSendB	;port b send message
	
;  doXfer - Switch to local stack and do the transfer.

doXfer	mov	a,b		;a=address of serial port to use
	sta	rcvSDR		;modify IN instruction for data register
	sta	sndSDR		;modify OUT instruction for data register
	inr	a		;a=serial port control register address
	sta	rcvSCR		;modify IN for control register in RECV
	sta	sndSCR		;modify IN for control register in SEND
	LXI	H,0		;HL=0
	DAD	SP		;HL=STACK FROM CP/M
	SHLD	STACK		;..SAVE IT
	LXI	SP,STACK	;SP=MY STACK
	xra	a
	sta	SECTNO		;init sector number to zero
	MVI	C,PRINT		;print the send message
	CALL	BDOS		;PRINT ID MESSAGE

;  GOBBLE UP GARBAGE CHARS FROM THE LINE

purge	MVI	B,1		;times out after 1 second if no data
	CALL	RECV
	jc	RECEIVE$FILE	;line is clear, go receive the file
	cpi	ctrlc		;exit if abort requested
	jz	abort
	jmp	purge
;
;**************RECEIVE FILE****************
;
RECEIVE$FILE:
	CALL	ERASE$OLD$FILE
	CALL	MAKE$NEW$FILE
	MVI	A,NAK
	CALL	SEND		;SEND NAK

RECV$LOOP:
RECV$HDR:
	MVI	B,3		;3 SEC TIMEOUT
	CALL	RECV
	JNC	RHNTO		;NO TIMEOUT

RECV$HDR$TIMEOUT:
RECV$SECT$ERR:			;PURGE THE LINE OF INPUT CHARS
	MVI	B,1		;1 SEC W/NO CHARS
	CALL	RECV
	JNC	RECV$SECT$ERR 	;LOOP UNTIL SENDER DONE
	MVI	A,NAK
	CALL	SEND		;SEND NAK
	JMP	RECV$HDR

;GOT CHAR - MUST BE SOH OR CTRL-C TO ABORT

RHNTO:	CPI	SOH
	JZ	GOT$SOH
	cpi	ctrlc		;control-c to abort?
	jz	abort
	CPI	EOT
	JZ	GOT$EOT
	JMP	RECV$SECT$ERR

GOT$SOH:
	MVI	B,1
	CALL	RECV
	JC	RECV$HDR$TIMEOUT
	MOV	D,A		;D=BLK #
	MVI	B,1
	CALL	RECV		;GET CMA'D SECT #
	JC	RECV$HDR$TIMEOUT
	CMA
	CMP	D		;GOOD SECTOR #?
	JZ	RECV$SECTOR
	JMP	RECV$SECT$ERR

;  Receive Sector

RECV$SECTOR:
	MOV	A,D		;GET SECTOR #
	STA	RSECTNO
	MVI	C,0		;INIT CKSUM
	LXI	H,80H		;POINT TO BUFFER
RECV$CHAR:
	MVI	B,1		;1 SEC TIMEOUT
	CALL	RECV		;GET CHAR
	JC	RECV$HDR$TIMEOUT
	MOV	M,A		;STORE CHAR
	INR	L		;DONE?
	JNZ	RECV$CHAR

;VERIFY CHECKSUM

	MOV	D,C		;SAVE CHECKSUM
	MVI	B,1		;TIMEOUT
	CALL	RECV		;GET CHECKSUM
	JC	RECV$HDR$TIMEOUT
	CMP	D		;CHECK
	JNZ	RECV$SECT$ERR
;
;GOT A SECTOR, WRITE IF = 1+PREV SECTOR
;
	LDA	RSECTNO
	MOV	B,A		;SAVE IT
	LDA	SECTNO		;GET PREV
	INR	A		;CALC NEXT SECTOR #
	CMP	B		;MATCH?
	JNZ	DO$ACK

;GOT NEW SECTOR - WRITE IT

	LXI	D,FCB
	MVI	C,WRITE
	CALL	BDOS
	ORA	A
	JNZ	WRITE$ERROR
	LDA	RSECTNO
	STA	SECTNO		;UPDATE SECTOR #
DO$ACK	MVI	A,ACK
	CALL	SEND
	JMP	RECV$LOOP

WRITE$ERROR:
	CALL	ERXIT
	DB	13,10,10,'Error Writing File',13,10,'$'

GOT$EOT:
	MVI	A,ACK		;ACK THE EOT
	CALL	SEND
	LXI	D,FCB
	MVI	C,CLOSE
	CALL	BDOS
	INR	A
	JNZ	XFER$CPLT
	CALL	ERXIT
	DB	13,10,10,'Error Closing File',13,10,'$'
;
ERASE$OLD$FILE:
	LXI	D,FCB
	MVI	C,SRCHF		;SEE IF IT EXISTS
	CALL	BDOS
	INR	A		;FOUND?
	RZ			;NO, RETURN
ERAY:	LXI	D,FCB
	MVI	C,ERASE
	CALL	BDOS
	RET
;
MAKE$NEW$FILE:
	LXI	D,FCB
	MVI	C,MAKE
	CALL	BDOS
	INR	A		;FF=BAD
	RNZ			;OPEN OK

;DIRECTORY FULL - CAN'T MAKE FILE
	CALL	ERXIT
	DB	13,10,10,'Error - Can''t Make File',13,10
	DB	'(directory must be full)',13,10,'$'
;
; S U B R O U T I N E S
;
; - - - - - - - - - - - - - - -

;EXIT PRINTING MESSAGE FOLLOWING 'CALL ERXIT'

ERXIT	POP	D		;GET MESSAGE
	MVI	C,PRINT
	CALL	BDOS		;PRINT MESSAGE
EXIT	LHLD	STACK		;GET ORIGINAL STACK
	SPHL			;RESTORE IT
	RET			;--EXIT-- TO CP/M

; - - - - - - - - - - - - - - -
;MODEM RECV
;-------------------------------------
RECV	PUSH	D		;SAVE
MSEC	lxi	d,(248shl 8)	;63 cycles, 4.032ms/wrap*248=1s (4MHz)

rcvSCR	equ	$+1		;address of I/O port for the following IN
MWTI	IN	SIOACR		;(10)

        IF      ADE
        mvi     a,SIORDA        ;character always available if ADE
        ENDIF

	ANI	SIORDA		;(7)
	JNZ	MCHAR		;(10) GOT CHAR

; no character present, decrement timeout

	cpi	0		;(7) waste some time
	cpi	0		;(7) waste some time
	cpi	0		;(7) waste some time
	DCR	E		;(5) COUNT DOWN
	JNZ	MWTI		;(10) FOR TIMEOUT
	DCR	D		;do msb every 256th time
	JNZ	MWTI
	DCR	B		;DCR # OF SECONDS
	JNZ	MSEC

;MODEM TIMED OUT RECEIVING

	POP	D		;RESTORE D,E
	STC			;CARRY SHOWS TIMEOUT
	RET

;GOT MODEM CHAR

rcvSDR	equ	$+1		;address of I/O port for the following IN
MCHAR	IN	SIOADR

        IF      ADE
        mvi     a,DUMMY         ;use just dummy character 
        ENDIF

	POP	D		;RESTORE DE
	PUSH	PSW		;CALC CHECKSUM
	ADD	C
	MOV	C,A
	POP	PSW
	ORA	A		;TURN OFF CARRY TO SHOW NO TIMEOUT
	RET


; - - - - - - - - - - - - - - -
;MODEM SEND CHAR ROUTINE
;----------------------------------
;
SEND	PUSH	PSW		;CHECK IF MONITORING OUTPUT
	ADD	C		;CALC CKSUM
	MOV	C,A

sndSCR	equ	$+1		;address of I/O port for the following IN
SENDW	IN	SIOACR
	ANI	SIOTRE
	JZ	SENDW
	POP	PSW		;GET CHAR

sndSDR	equ	$+1		;address of I/O port for the following IN
	OUT	SIOADR
	RET

;-----------------------------------------
;  messages
;-----------------------------------------

mSendA	db	'Start XMODEM send now... (SIO slot 1) $'
mSendB	db	'Start XMODEM send now... (SIO slot 2) $'
mHelp	db	CR,LF,'PCGET Ver 1.0 for North Star Advantage',CR,LF,LF
	db	'Receives a file from a PC through a serial port',CR,LF
	db	'using the XMODEM protocol.',CR,LF,LF
	db	'Usage: PCGET file.ext [S]',CR,LF
	db	'   S = SIO slot (1 or 2)',CR,LF,'$'

;DONE - CLOSE UP SHOP

XFER$CPLT:
	CALL	ERXIT
	DB	13,10,10,'Transfer Complete',13,10,'$'

abort:	call	erxit
	db	13,10,10,'Transfer Aborted',13,10,'$'

	DS	40	;STACK AREA
STACK	DS	2	;STACK POINTER
RSECTNO	DS	1	;RECEIVED SECTOR NUMBER
SECTNO	DS	1	;CURRENT SECTOR NUMBER 
serPort	ds	1	;I/O address of serial port to use (2 or 4)
;
; BDOS EQUATES (VERSION 2)
;
RDCON	EQU	1
WRCON	EQU	2
PRINT	EQU	9
CONST	EQU	11	;CONSOLE STAT
OPEN	EQU	15	;0FFH=NOT FOUND
CLOSE	EQU	16	;   "	"
SRCHF	EQU	17	;   "	"
SRCHN	EQU	18	;   "	"
ERASE	EQU	19	;NO RET CODE
READ	EQU	20	;0=OK, 1=EOF
WRITE	EQU	21	;0=OK, 1=ERR, 2=?, 0FFH=NO DIR SPC
MAKE	EQU	22	;0FFH=BAD
REN	EQU	23	;0FFH=BAD
STDMA	EQU	26
BDOS	EQU	5
REIPL	EQU	0
FCB	EQU	5CH	;DEFAULT FCB
PARAM1	EQU	FCB+1	;COMMAND LINE PARAMETER 1 IN FCB
PARAM2	EQU	PARAM1+16	;COMMAND LINE PARAMETER 2
	END
