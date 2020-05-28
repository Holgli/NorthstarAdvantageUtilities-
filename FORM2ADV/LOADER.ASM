;***********************************************************************
;
;  Quick binary file loader for the Northstar Advantage computer
;       Using the Mini Monitor store this program at memory address c000h:
;       - to enter the Mini-Monitor press CONTROL-C 
;       - type Dc000 to display and change memory
;       - type <return> to exit form D-command
;       - type Jc000 to run loader at address c000
;       Then send the program file as 8-bit binary
;       through SIO in port 1. After sucessful transmission
;       reset the computer. Enter the Mini Monitor again and 
;       run the program at address c080h: 
;       - to enter the Mini-Monitor press CONTROL-C 
;       - type Jc080 
;
;***********************************************************************

; 8251 USART Equates

PORT    equ     050h            ;SIO board in slot 1
DATA    equ     PORT            ;USART data address
CTRL    equ     PORT+1          ;USART control / status
BAUD    equ     PORT+8          ;Baud rate register
BDRT    equ     126             ;set Baud rate of 9600 Baud, 16*CLK

        org     0c000h
        
;reset and init USART

setBdrt mvi     a,BDRT
        out     BAUD            ;set Baud rate
        
reset   mvi     a,080h          ;USART commands to reset
        out     CTRL
        out     CTRL
        mvi     a,040h          
        out     CTRL            ;reset

init    mvi     a,0ceh          ;2 stop bits, no parity, 8 data bits, 16*CLK 
        out     CTRL            ;set mode
        mvi     a,037h          ;CMD: RTS, ER, RXF, DTR, TXEN
        out     CTRL            ;give command 
        
        in      DATA            ;clear possible garbage
        in      DATA

;receive data

        lxi     h,0c080h        ;start of program to load
loop    in      CTRL            ;wait for a character
        ani     2       
        jz      loop

        in      DATA            ;get the character
        mov     m,a             ;store it
        inx     h               ;move to next location
        jmp     loop

        end

 