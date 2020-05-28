;******************************************************************************
;
;  
;  Form2Adv - NortStar Advantage formatting program. 
;             Using the Mini Monitor type in the loader routine and
;             transmit this program to memory over the serial line
;             (SIO in port 1). 
;
;       - uses FORMAT.COM, BDOS, BIOS code of Northstar Graphics CP/M
;
;       This program only runs standalone. Use MLOAD.COM to create.
;
;       Written by Holger Linning
;
;       Rev      Date       Desc
;       1.0     01/30/20    Original 
;
;*****************************************************************************


BIAS    equ     0c000h          ;start of ram after boot 
START   equ     00080h          ;load address of program (+0c000h)
RESTORE equ     000c0h          ;address of commands to restore CP/M environment
BDOS    equ     0df00h          ;start of BDOS 
BIOS    equ     0ed00h          ;start of BIOS

;-----------------------------------------------------------------------------
;  Prepare start of program which has been loaded to 0c080H before. 
;  Loader program was typed in at 0c000h. 
;-----------------------------------------------------------------------------
        org     START   

        ;map memory
        mvi     a,1 
        out     0a0h            ; page 1 to A0 
        mvi     a,2               
        out     0a1h            ; page 2 to A1
        mvi     a,3               
        out     0a2h            ; page 3 to A2

        ;move restore commands, program, zero page, BDOS and BIOS to first memory page
        lxi     d,RESTORE       ;DE = destination of copy 
        lxi     h,RESTORE+BIAS  ;HL = start of copy
        lxi     b,BIOSDataEnd - RESTORE ;count of bytes
        dw      0b0edh          ;LDIR = copy memory

        ;clear parity erros
        mvi     a,3
        out     060h            ;clear parity errors, enable interrupts 
        
        jmp     RESTORE         ;jump to restore CP/M environment

        org     RESTORE         
                                ;restore BDOS and BIOS
        lxi     d,BDOS          ;DE = destination of copy
        lxi     h,BDOSDataStart ;HL = start of copy
        lxi     b,BIOSDataEnd - BDOSDataStart ;count of bytes
        dw      0b0edh          ;LDIR = copy memory

                                ;restore zero page
        lxi     d,00000h        ;DE = destination of copy
        lxi     h,zerostart     ;HL = start of copy
        lxi     b,zeroend - zerostart ;count of bytes
        dw      0b0edh          ;LDIR = copy memory

        jmp     progstart;      ;now jump to start address of TPA

        ;fill space
        ds      progstart - $ + RESTORE
        
        org     0100h   

;-----------------------------------------------------------------------------
;  Pseudo TPA (insert here the HEX codes of your program)
;-----------------------------------------------------------------------------
progstart:
        db      0c3h, 03eh, 001h, 046h, 04fh, 052h, 04dh, 041h, 054h, 020h, 056h, 045h, 052h, 053h, 049h, 04fh 
        db      04eh, 020h, 031h, 02eh, 031h, 020h, 043h, 04fh, 050h, 059h, 052h, 049h, 047h, 048h, 054h, 02ch 
        db      031h, 039h, 038h, 031h, 020h, 04eh, 04fh, 052h, 054h, 048h, 020h, 053h, 054h, 041h, 052h, 020h 
        db      043h, 04fh, 04dh, 050h, 055h, 054h, 045h, 052h, 053h, 02ch, 049h, 04eh, 043h, 02eh, 031h, 000h 
        db      001h, 011h, 038h, 003h, 0cdh, 0e8h, 002h, 021h, 008h, 006h, 0cdh, 0d9h, 002h, 032h, 067h, 007h 
        db      021h, 095h, 004h, 0feh, 044h, 0cah, 07ah, 001h, 021h, 06bh, 004h, 0feh, 051h, 0cah, 07ah, 001h 
        db      021h, 097h, 003h, 0feh, 032h, 0cah, 07ah, 001h, 0feh, 058h, 0cah, 000h, 000h, 0feh, 003h, 0cah 
        db      000h, 000h, 021h, 040h, 004h, 0feh, 04eh, 0c2h, 047h, 001h, 07eh, 032h, 069h, 007h, 023h, 022h 
        db      06fh, 007h, 021h, 023h, 004h, 0cdh, 0d9h, 002h, 0cdh, 0f7h, 002h, 011h, 043h, 005h, 0dah, 0bdh 
        db      001h, 032h, 068h, 007h, 0e6h, 007h, 0f6h, 030h, 032h, 0d8h, 003h, 03ah, 068h, 007h, 0e6h, 040h 
        db      0c2h, 0c3h, 001h, 03ah, 069h, 007h, 0feh, 0f2h, 011h, 0b6h, 005h, 0cah, 0bdh, 001h, 0e6h, 040h 
        db      0cah, 0ceh, 001h, 03ah, 068h, 007h, 0b7h, 0fah, 0ceh, 001h, 011h, 0ebh, 004h, 0cdh, 0e8h, 002h 
        db      0c3h, 047h, 001h, 03ah, 067h, 007h, 0feh, 04eh, 011h, 063h, 005h, 0c2h, 0bdh, 001h, 011h, 0beh 
        db      003h, 0cdh, 0e8h, 002h, 02ah, 06fh, 007h, 0cdh, 0d9h, 002h, 0feh, 003h, 0cah, 000h, 000h, 0feh 
        db      00dh, 0c2h, 047h, 001h, 03ah, 067h, 007h, 011h, 012h, 007h, 021h, 045h, 000h, 0feh, 051h, 0cah 
        db      003h, 002h, 011h, 0e9h, 006h, 021h, 022h, 000h, 0feh, 04eh, 0c2h, 003h, 002h, 011h, 03eh, 007h 
        db      021h, 09fh, 000h, 025h, 022h, 06dh, 007h, 0cdh, 0e8h, 002h, 021h, 055h, 009h, 001h, 000h, 014h 
        db      036h, 000h, 023h, 00dh, 0c2h, 010h, 002h, 005h, 0c2h, 010h, 002h, 02ah, 001h, 000h, 011h, 030h 
        db      000h, 019h, 022h, 06bh, 007h, 021h, 06eh, 007h, 034h, 046h, 03ah, 06dh, 007h, 0b8h, 0dah, 049h 
        db      002h, 021h, 055h, 009h, 011h, 000h, 000h, 0cdh, 02ah, 003h, 03eh, 00ah, 0cdh, 06ah, 007h, 00eh 
        db      002h, 01eh, 02ah, 0cdh, 005h, 000h, 0c3h, 025h, 002h, 021h, 055h, 009h, 001h, 000h, 014h, 036h 
        db      0e5h, 023h, 00dh, 0c2h, 04fh, 002h, 005h, 0c2h, 04fh, 002h, 001h, 080h, 002h, 03ah, 067h, 007h 
        db      0feh, 053h, 0c2h, 068h, 002h, 001h, 000h, 003h, 011h, 000h, 000h, 021h, 055h, 009h, 0cdh, 02ah 
        db      003h, 03eh, 00ah, 0cdh, 06ah, 007h, 021h, 055h, 009h, 001h, 000h, 008h, 036h, 020h, 023h, 00dh 
        db      0c2h, 07ch, 002h, 005h, 0c2h, 07ch, 002h, 021h, 0bch, 002h, 022h, 0f3h, 007h, 03ah, 069h, 007h 
        db      032h, 0e5h, 007h, 0feh, 0f0h, 021h, 071h, 007h, 0cah, 0b2h, 002h, 021h, 05eh, 001h, 022h, 0f3h 
        db      007h, 021h, 079h, 007h, 0feh, 0f2h, 0c2h, 0b2h, 002h, 021h, 040h, 006h, 022h, 0f3h, 007h, 021h 
        db      081h, 007h, 011h, 0d9h, 007h, 006h, 008h, 0cdh, 0eeh, 002h, 021h, 089h, 007h, 0cdh, 02ah, 003h 
        db      0fah, 0c6h, 002h, 021h, 055h, 009h, 006h, 000h, 03eh, 004h, 011h, 000h, 000h, 0cdh, 06ah, 007h 
        db      011h, 0fbh, 003h, 0cdh, 0e8h, 002h, 0c3h, 047h, 001h, 0ebh, 0cdh, 0e8h, 002h, 00eh, 001h, 0cdh 
        db      005h, 000h, 0feh, 060h, 0d8h, 0e6h, 05fh, 0c9h, 00eh, 009h, 0cdh, 005h, 000h, 0c9h, 07eh, 012h 
        db      023h, 013h, 005h, 0c2h, 0eeh, 002h, 0c9h, 0feh, 041h, 0dah, 0feh, 002h, 0d6h, 010h, 0feh, 031h 
        db      0d8h, 0d6h, 031h, 0feh, 004h, 03fh, 0d8h, 03ch, 047h, 011h, 0f5h, 006h, 02ah, 001h, 000h, 019h 
        db      04fh, 07eh, 007h, 00dh, 0c2h, 012h, 003h, 00fh, 0e6h, 080h, 0b0h, 048h, 047h, 02bh, 02bh, 07eh 
        db      00fh, 00dh, 0c2h, 020h, 003h, 00fh, 0e6h, 040h, 0b0h, 0c9h, 03ah, 068h, 007h, 0e6h, 007h, 04fh 
        db      03ah, 069h, 007h, 0e6h, 080h, 0b1h, 04fh, 0c9h, 00dh, 00ah, 04eh, 06fh, 072h, 074h, 068h, 020h 
        db      053h, 074h, 061h, 072h, 020h, 047h, 072h, 061h, 070h, 068h, 069h, 063h, 073h, 020h, 043h, 050h 
        db      02fh, 04dh, 020h, 032h, 02eh, 032h, 030h, 020h, 044h, 069h, 073h, 06bh, 065h, 074h, 074h, 065h 
        db      020h, 046h, 06fh, 072h, 06dh, 061h, 074h, 074h, 065h, 072h, 00dh, 00ah, 049h, 06eh, 069h, 074h 
        db      069h, 061h, 06ch, 069h, 07ah, 065h, 073h, 020h, 044h, 069h, 073h, 06bh, 065h, 074h, 074h, 065h 
        db      073h, 020h, 066h, 06fh, 072h, 020h, 075h, 073h, 065h, 020h, 077h, 069h, 074h, 068h, 020h, 043h 
        db      050h, 02fh, 04dh, 00dh, 00ah, 00ah, 024h, 0b0h, 00dh, 00ah, 054h, 06fh, 020h, 066h, 06fh, 072h 
        db      06dh, 061h, 074h, 020h, 061h, 073h, 03ah, 020h, 043h, 050h, 02fh, 04dh, 020h, 032h, 020h, 044h 
        db      06fh, 075h, 062h, 06ch, 065h, 02dh, 044h, 065h, 06eh, 073h, 069h, 074h, 079h, 024h, 00dh, 00ah 
        db      04ch, 06fh, 061h, 064h, 020h, 044h, 069h, 073h, 06bh, 065h, 074h, 074h, 065h, 020h, 069h, 06eh 
        db      020h, 044h, 072h, 069h, 076h, 065h, 03ah, 020h, 058h, 02ch, 00dh, 00ah, 053h, 074h, 072h, 069h 
        db      06bh, 065h, 020h, 052h, 045h, 054h, 055h, 052h, 04eh, 020h, 03ch, 063h, 072h, 03eh, 020h, 077h 
        db      068h, 065h, 06eh, 020h, 072h, 065h, 061h, 064h, 079h, 02ch, 024h, 00dh, 00ah, 00ah, 044h, 069h 
        db      073h, 06bh, 065h, 074h, 074h, 065h, 020h, 053h, 075h, 063h, 063h, 065h, 073h, 073h, 066h, 075h 
        db      06ch, 06ch, 079h, 020h, 049h, 06eh, 069h, 074h, 069h, 061h, 06ch, 069h, 07ah, 065h, 064h, 00dh 
        db      00ah, 00ah, 024h, 00dh, 00ah, 00ah, 045h, 06eh, 074h, 065h, 072h, 020h, 044h, 072h, 069h, 076h 
        db      065h, 020h, 06eh, 075h, 06dh, 062h, 065h, 072h, 028h, 031h, 02dh, 034h, 029h, 03ah, 020h, 024h 
        db      0f2h, 00dh, 00ah, 054h, 06fh, 020h, 066h, 06fh, 072h, 06dh, 061h, 074h, 020h, 061h, 073h, 03ah 
        db      020h, 04fh, 063h, 074h, 061h, 06ch, 02dh, 043h, 061h, 070h, 061h, 063h, 069h, 074h, 079h, 020h 
        db      044h, 069h, 073h, 06bh, 065h, 074h, 074h, 065h, 03ah, 020h, 024h, 0f0h, 00dh, 00ah, 054h, 06fh 
        db      020h, 066h, 06fh, 072h, 06dh, 061h, 074h, 020h, 061h, 073h, 03ah, 020h, 051h, 075h, 061h, 064h 
        db      02dh, 043h, 061h, 070h, 061h, 063h, 069h, 074h, 079h, 020h, 044h, 069h, 073h, 06bh, 065h, 074h 
        db      074h, 065h, 03ah, 020h, 024h, 090h, 00dh, 00ah, 054h, 06fh, 020h, 066h, 06fh, 072h, 06dh, 061h 
        db      074h, 020h, 061h, 073h, 03ah, 020h, 044h, 06fh, 075h, 062h, 06ch, 065h, 02dh, 044h, 065h, 06eh 
        db      073h, 069h, 074h, 079h, 020h, 044h, 069h, 073h, 06bh, 065h, 074h, 074h, 065h, 03ah, 020h, 024h 
        db      010h, 00dh, 00ah, 054h, 06fh, 020h, 066h, 06fh, 072h, 06dh, 061h, 074h, 020h, 061h, 073h, 03ah 
        db      020h, 053h, 069h, 06eh, 067h, 06ch, 065h, 02dh, 044h, 065h, 06eh, 073h, 069h, 074h, 079h, 020h 
        db      044h, 069h, 073h, 06bh, 065h, 074h, 074h, 065h, 03ah, 020h, 024h, 00dh, 00ah, 00ah, 02ah, 02ah 
        db      02ah, 020h, 045h, 052h, 052h, 04fh, 052h, 020h, 02dh, 020h, 043h, 061h, 06eh, 020h, 04eh, 04fh 
        db      054h, 020h, 066h, 06fh, 072h, 06dh, 061h, 074h, 020h, 051h, 075h, 061h, 064h, 02dh, 043h, 061h 
        db      070h, 061h, 063h, 069h, 074h, 079h, 00dh, 00ah, 02ah, 02ah, 02ah, 020h, 043h, 050h, 04dh, 047h 
        db      045h, 04eh, 020h, 077h, 061h, 073h, 020h, 074h, 06fh, 06ch, 064h, 020h, 074h, 068h, 061h, 074h 
        db      020h, 044h, 072h, 069h, 076h, 065h, 020h, 069h, 073h, 020h, 04eh, 04fh, 054h, 020h, 051h, 075h 
        db      061h, 064h, 024h, 00dh, 00ah, 00ah, 02ah, 02ah, 02ah, 020h, 045h, 052h, 052h, 04fh, 052h, 020h 
        db      02dh, 020h, 042h, 041h, 044h, 020h, 044h, 052h, 049h, 056h, 045h, 020h, 04eh, 055h, 04dh, 042h 
        db      045h, 052h, 024h, 00dh, 00ah, 00ah, 02ah, 02ah, 02ah, 020h, 045h, 052h, 052h, 04fh, 052h, 020h 
        db      02dh, 020h, 04fh, 06eh, 06ch, 079h, 020h, 04eh, 03dh, 04eh, 049h, 04eh, 045h, 020h, 046h, 06fh 
        db      072h, 06dh, 061h, 074h, 020h, 050h, 065h, 072h, 06dh, 069h, 074h, 074h, 065h, 064h, 00dh, 00ah 
        db      073h, 069h, 06eh, 063h, 065h, 020h, 043h, 050h, 04dh, 047h, 045h, 04eh, 020h, 077h, 061h, 073h 
        db      020h, 074h, 06fh, 06ch, 064h, 020h, 064h, 072h, 069h, 076h, 065h, 020h, 069h, 073h, 020h, 04eh 
        db      02dh, 054h, 059h, 050h, 045h, 024h, 00dh, 00ah, 00ah, 02ah, 02ah, 02ah, 020h, 045h, 052h, 052h 
        db      04fh, 052h, 020h, 02dh, 020h, 04eh, 020h, 046h, 06fh, 072h, 06dh, 061h, 074h, 020h, 063h, 061h 
        db      06eh, 06eh, 06fh, 074h, 020h, 062h, 065h, 020h, 064h, 06fh, 06eh, 065h, 00dh, 00ah, 073h, 069h 
        db      06eh, 063h, 065h, 020h, 043h, 050h, 04dh, 047h, 045h, 04eh, 020h, 077h, 061h, 073h, 020h, 06eh 
        db      06fh, 074h, 020h, 074h, 06fh, 06ch, 064h, 020h, 064h, 072h, 069h, 076h, 065h, 020h, 069h, 073h 
        db      020h, 04eh, 02dh, 054h, 059h, 050h, 045h, 024h, 00dh, 00ah, 053h, 065h, 06ch, 065h, 063h, 074h 
        db      020h, 06fh, 06eh, 065h, 020h, 06fh, 066h, 020h, 074h, 068h, 065h, 020h, 066h, 06fh, 072h, 06dh 
        db      061h, 074h, 020h, 06fh, 070h, 074h, 069h, 06fh, 06eh, 073h, 020h, 062h, 065h, 06ch, 06fh, 077h 
        db      03ah, 00dh, 00ah, 00ah, 044h, 020h, 03dh, 020h, 044h, 06fh, 075h, 062h, 06ch, 065h, 02dh, 044h 
        db      065h, 06eh, 073h, 069h, 074h, 079h, 020h, 053h, 069h, 06eh, 067h, 06ch, 065h, 02dh, 053h, 069h 
        db      064h, 065h, 064h, 020h, 03dh, 020h, 044h, 00dh, 00ah, 051h, 020h, 03dh, 020h, 051h, 075h, 061h 
        db      064h, 02dh, 043h, 061h, 070h, 061h, 063h, 069h, 074h, 079h, 020h, 028h, 044h, 06fh, 075h, 062h 
        db      06ch, 065h, 02dh, 053h, 069h, 064h, 065h, 064h, 029h, 03dh, 020h, 051h, 00dh, 00ah, 04eh, 020h 
        db      03dh, 020h, 04eh, 069h, 06eh, 065h, 02dh, 043h, 061h, 070h, 061h, 063h, 069h, 074h, 079h, 02ch 
        db      020h, 04eh, 02dh, 044h, 072h, 069h, 076h, 065h, 073h, 020h, 06fh, 06eh, 06ch, 079h, 03dh, 020h 
        db      04eh, 00dh, 00ah, 058h, 020h, 03dh, 020h, 065h, 058h, 069h, 074h, 020h, 02dh, 020h, 057h, 061h 
        db      072h, 06dh, 020h, 042h, 06fh, 06fh, 074h, 020h, 066h, 072h, 06fh, 06dh, 020h, 041h, 03ah, 020h 
        db      020h, 020h, 020h, 03dh, 020h, 058h, 00dh, 00ah, 00ah, 045h, 06eh, 074h, 065h, 072h, 020h, 06fh 
        db      070h, 074h, 069h, 06fh, 06eh, 020h, 06ch, 065h, 074h, 074h, 065h, 072h, 020h, 028h, 044h, 02ch 
        db      051h, 02ch, 04eh, 02ch, 058h, 029h, 03ah, 020h, 024h, 00dh, 00ah, 02dh, 020h, 050h, 072h, 06fh 
        db      063h, 065h, 065h, 064h, 069h, 06eh, 067h, 020h, 074h, 06fh, 020h, 046h, 06fh, 072h, 06dh, 061h 
        db      074h, 020h, 033h, 035h, 020h, 02ah, 020h, 054h, 072h, 061h, 063h, 06bh, 073h, 020h, 02dh, 00dh 
        db      00ah, 024h, 00dh, 00ah, 02dh, 020h, 050h, 072h, 06fh, 063h, 065h, 065h, 064h, 069h, 06eh, 067h 
        db      020h, 074h, 06fh, 020h, 046h, 06fh, 072h, 06dh, 061h, 074h, 020h, 037h, 030h, 020h, 02ah, 020h 
        db      054h, 072h, 061h, 063h, 06bh, 073h, 020h, 02dh, 02eh, 02eh, 02eh, 00dh, 00ah, 024h, 00dh, 00ah 
        db      02dh, 020h, 050h, 072h, 06fh, 063h, 065h, 065h, 064h, 069h, 06eh, 067h, 020h, 074h, 06fh, 020h 
        db      046h, 06fh, 072h, 06dh, 061h, 074h, 020h, 031h, 036h, 030h, 020h, 02ah, 020h, 054h, 072h, 061h 
        db      063h, 06bh, 073h, 02eh, 02eh, 02eh, 024h, 069h, 074h, 079h, 0c3h, 000h, 000h, 06fh, 075h, 062h 
        db      06ch, 051h, 055h, 041h, 044h, 02eh, 043h, 041h, 050h, 044h, 04fh, 055h, 042h, 04ch, 045h, 02dh 
        db      044h, 04eh, 049h, 04eh, 045h, 02dh, 043h, 041h, 050h, 020h, 020h, 020h, 020h, 020h, 020h, 020h 
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h 
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 043h, 050h, 02fh, 04dh, 020h, 032h, 02eh 
        db      032h, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 020h, 020h, 020h, 020h, 020h, 020h, 020h 
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h 
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 058h, 058h, 058h, 058h, 058h, 058h, 058h 
        db      058h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 044h, 049h, 053h, 04bh, 045h, 054h, 054h 
        db      045h, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 043h, 050h, 04dh, 020h, 046h, 052h, 04fh 
        db      04dh, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 04eh, 04fh, 052h, 054h, 048h, 020h, 02ah 
        db      020h, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 053h, 054h, 041h, 052h, 020h, 020h, 020h 
        db      020h, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 02dh, 02dh, 02dh, 02dh, 02dh, 02dh, 02dh 
        db      02dh, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 02dh, 053h, 059h, 053h, 054h, 045h, 04dh 
        db      02dh, 001h, 000h, 013h, 000h, 086h, 000h, 000h, 000h, 02dh, 054h, 052h, 041h, 043h, 04bh, 053h 
        db      02dh, 001h, 000h, 013h, 000h, 086h, 000h, 000h, 000h, 042h, 049h, 04fh, 053h, 020h, 020h, 020h 
        db      020h, 001h, 000h, 007h, 000h, 086h, 000h, 000h, 000h, 055h, 053h, 045h, 052h, 020h, 020h, 020h 
        db      020h, 008h, 000h, 001h, 000h, 086h, 000h, 000h, 000h, 043h, 050h, 04dh, 020h, 043h, 043h, 050h 
        db      020h, 009h, 000h, 004h, 000h, 086h, 000h, 000h, 000h, 043h, 050h, 04dh, 020h, 042h, 044h, 04fh 
        db      053h, 00dh, 000h, 007h, 000h, 086h, 000h, 000h, 000h, 02dh, 02dh, 02dh, 02dh, 02dh, 02dh, 02dh 
        db      02dh, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 044h, 049h, 052h, 02eh, 053h, 045h, 043h 
        db      031h, 014h, 000h, 001h, 000h, 083h, 000h, 000h, 000h, 044h, 049h, 052h, 02eh, 053h, 045h, 043h 
        db      032h, 019h, 000h, 001h, 000h, 083h, 000h, 000h, 000h, 044h, 049h, 052h, 02eh, 053h, 045h, 043h 
        db      033h, 015h, 000h, 001h, 000h, 083h, 000h, 000h, 000h, 044h, 049h, 052h, 02eh, 053h, 045h, 043h 
        db      034h, 01ah, 000h, 001h, 000h, 083h, 000h, 000h, 000h, 02dh, 02dh, 02dh, 02dh, 02dh, 02dh, 02dh 
        db      02dh, 000h, 000h, 000h, 000h, 080h, 000h, 000h, 000h, 043h, 050h, 04dh, 020h, 044h, 041h, 054h 
        db      041h, 000h, 000h, 000h, 000h, 087h, 000h, 000h, 000h, 044h, 041h, 054h, 041h, 053h, 045h, 043h 
        db      031h, 016h, 000h, 001h, 000h, 087h, 000h, 000h, 000h, 044h, 041h, 054h, 041h, 053h, 045h, 043h 
        db      032h, 01bh, 000h, 001h, 000h, 087h, 000h, 000h, 000h, 044h, 041h, 054h, 041h, 053h, 045h, 043h 
        db      033h, 017h, 000h, 001h, 000h, 087h, 000h, 000h, 000h, 044h, 041h, 054h, 041h, 053h, 045h, 043h 
        db      034h, 01ch, 001h, 087h, 000h, 02eh, 02eh, 02eh, 02eh, 02eh, 02eh, 02eh, 02eh, 000h, 000h, 000h 
        db      000h, 087h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h 
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h 
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
progend:     equ     $

;-----------------------------------------------------------------------------
;  end of program
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
;  start of zero page 0000h - 00c0h
;-----------------------------------------------------------------------------
zerostart:     equ     $
        db      0c3h, 003h, 0edh, 000h, 000h, 0c3h, 006h, 0dfh, 0c1h, 035h, 00bh, 049h, 0c3h, 006h, 0c0h, 047h
        db      0b9h, 013h, 008h, 000h, 084h, 047h, 065h, 016h, 089h, 020h, 020h, 033h, 075h, 033h, 0c3h, 0f3h
        db      0c3h, 0f3h, 0d2h, 0d6h, 0ebh, 009h, 0ebh, 03dh, 020h, 0e8h, 0c3h, 004h, 002h, 0afh, 0c3h, 00dh
        db      0f8h, 04eh, 04fh, 052h, 054h, 048h, 020h, 053h, 0c3h, 086h, 0cbh, 027h, 073h, 020h, 066h, 061h
        db      06dh, 000h, 06ch, 079h, 020h, 06fh, 066h, 020h, 042h, 055h, 053h, 049h, 04eh, 045h, 053h, 053h
        db      020h, 073h, 06fh, 066h, 074h, 077h, 061h, 072h, 065h, 000h, 069h, 000h, 000h, 020h, 020h, 020h
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 000h, 000h, 000h, 072h, 000h, 020h, 020h, 020h
        db      020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      032h, 004h, 039h, 036h, 030h, 030h, 000h, 031h, 020h, 043h, 04fh, 04dh, 001h, 000h, 000h, 047h
        db      044h, 045h, 046h, 047h, 048h, 049h, 04ah, 04bh, 016h, 017h, 018h, 019h, 01ah, 01bh, 01ch, 000h
        db      045h, 050h, 043h, 047h, 045h, 054h, 020h, 020h, 020h, 043h, 04fh, 04dh, 000h, 000h, 000h, 006h
        db      027h, 000h, 000h, 000h, 0f0h, 000h, 0ffh, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
zeroend:     equ     $
;-----------------------------------------------------------------------------
;  end of zero page
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
;  start of BDOS / BIOS
;-----------------------------------------------------------------------------
BDOSDataStart:
        db      0e3h, 016h, 000h, 003h, 0fdh, 06eh, 0c3h, 011h, 0dfh, 099h, 0dfh, 0a5h, 0dfh, 0abh, 0dfh, 0b1h
        db      0dfh, 0ebh, 022h, 043h, 0e2h, 0ebh, 07bh, 032h, 0d6h, 0ech, 021h, 000h, 000h, 022h, 045h, 0e2h
        db      039h, 022h, 00fh, 0e2h, 031h, 041h, 0e2h, 0afh, 032h, 0e0h, 0ech, 032h, 0deh, 0ech, 021h, 074h
        db      0ech, 0e5h, 079h, 0feh, 029h, 0d0h, 04bh, 021h, 047h, 0dfh, 05fh, 016h, 000h, 019h, 019h, 05eh
        db      023h, 056h, 02ah, 043h, 0e2h, 0ebh, 0e9h, 003h, 0edh, 0c8h, 0e1h, 090h, 0e0h, 0ceh, 0e1h, 012h
        db      0edh, 00fh, 0edh, 0d4h, 0e1h, 0edh, 0e1h, 0f3h, 0e1h, 0f8h, 0e1h, 0e1h, 0e0h, 0feh, 0e1h, 07eh
        db      0ebh, 083h, 0ebh, 045h, 0ebh, 09ch, 0ebh, 0a5h, 0ebh, 0abh, 0ebh, 0c8h, 0ebh, 0d7h, 0ebh, 0e0h
        db      0ebh, 0e6h, 0ebh, 0ech, 0ebh, 0f5h, 0ebh, 0feh, 0ebh, 004h, 0ech, 00ah, 0ech, 011h, 0ech, 02ch
        db      0e4h, 017h, 0ech, 01dh, 0ech, 026h, 0ech, 02dh, 0ech, 041h, 0ech, 047h, 0ech, 04dh, 0ech, 00eh
        db      0ebh, 053h, 0ech, 004h, 0e2h, 004h, 0e2h, 09bh, 0ech, 021h, 0cah, 0dfh, 0cdh, 0e5h, 0dfh, 0feh
        db      003h, 0cah, 000h, 000h, 0c9h, 021h, 0d5h, 0dfh, 0c3h, 0b4h, 0dfh, 021h, 0e1h, 0dfh, 0c3h, 0b4h
        db      0dfh, 021h, 0dch, 0dfh, 0cdh, 0e5h, 0dfh, 0c3h, 000h, 000h, 042h, 064h, 06fh, 073h, 020h, 045h
        db      072h, 072h, 020h, 04fh, 06eh, 020h, 020h, 03ah, 020h, 024h, 042h, 061h, 064h, 020h, 053h, 065h
        db      063h, 074h, 06fh, 072h, 024h, 053h, 065h, 06ch, 065h, 063h, 074h, 024h, 046h, 069h, 06ch, 065h
        db      020h, 052h, 02fh, 04fh, 024h, 0e5h, 0cdh, 0c9h, 0e0h, 03ah, 042h, 0e2h, 0c6h, 041h, 032h, 0c6h
        db      0dfh, 001h, 0bah, 0dfh, 0cdh, 0d3h, 0e0h, 0c1h, 0cdh, 0d3h, 0e0h, 021h, 00eh, 0e2h, 07eh, 036h
        db      000h, 0b7h, 0c0h, 0c3h, 009h, 0edh, 0cdh, 0fbh, 0dfh, 0cdh, 014h, 0e0h, 0d8h, 0f5h, 04fh, 0cdh
        db      090h, 0e0h, 0f1h, 0c9h, 0feh, 00dh, 0c8h, 0feh, 00ah, 0c8h, 0feh, 009h, 0c8h, 0feh, 008h, 0c8h
        db      0feh, 020h, 0c9h, 03ah, 00eh, 0e2h, 0b7h, 0c2h, 045h, 0e0h, 0cdh, 006h, 0edh, 0e6h, 001h, 0c8h
        db      0cdh, 009h, 0edh, 0feh, 013h, 0c2h, 042h, 0e0h, 0cdh, 009h, 0edh, 0feh, 003h, 0cah, 000h, 000h
        db      0afh, 0c9h, 032h, 00eh, 0e2h, 03eh, 001h, 0c9h, 03ah, 00ah, 0e2h, 0b7h, 0c2h, 062h, 0e0h, 0c5h
        db      0cdh, 023h, 0e0h, 0c1h, 0c5h, 0cdh, 00ch, 0edh, 0c1h, 0c5h, 03ah, 00dh, 0e2h, 0b7h, 0c4h, 00fh
        db      0edh, 0c1h, 079h, 021h, 00ch, 0e2h, 0feh, 07fh, 0c8h, 034h, 0feh, 020h, 0d0h, 035h, 07eh, 0b7h
        db      0c8h, 079h, 0feh, 008h, 0c2h, 079h, 0e0h, 035h, 0c9h, 0feh, 00ah, 0c0h, 036h, 000h, 0c9h, 079h
        db      0cdh, 014h, 0e0h, 0d2h, 090h, 0e0h, 0f5h, 00eh, 05eh, 0cdh, 048h, 0e0h, 0f1h, 0f6h, 040h, 04fh
        db      079h, 0feh, 009h, 0c2h, 048h, 0e0h, 00eh, 020h, 0cdh, 048h, 0e0h, 03ah, 00ch, 0e2h, 0e6h, 007h
        db      0c2h, 096h, 0e0h, 0c9h, 0cdh, 0ach, 0e0h, 00eh, 020h, 0cdh, 00ch, 0edh, 00eh, 008h, 0c3h, 00ch
        db      0edh, 00eh, 023h, 0cdh, 048h, 0e0h, 0cdh, 0c9h, 0e0h, 03ah, 00ch, 0e2h, 021h, 00bh, 0e2h, 0beh
        db      0d0h, 00eh, 020h, 0cdh, 048h, 0e0h, 0c3h, 0b9h, 0e0h, 00eh, 00dh, 0cdh, 048h, 0e0h, 00eh, 00ah
        db      0c3h, 048h, 0e0h, 00ah, 0feh, 024h, 0c8h, 003h, 0c5h, 04fh, 0cdh, 090h, 0e0h, 0c1h, 0c3h, 0d3h
        db      0e0h, 03ah, 00ch, 0e2h, 032h, 00bh, 0e2h, 02ah, 043h, 0e2h, 04eh, 023h, 0e5h, 006h, 000h, 0c5h
        db      0e5h, 0cdh, 0fbh, 0dfh, 0e6h, 07fh, 0e1h, 0c1h, 0feh, 00dh, 0cah, 0c1h, 0e1h, 0feh, 00ah, 0cah
        db      0c1h, 0e1h, 0feh, 008h, 0c2h, 016h, 0e1h, 078h, 0b7h, 0cah, 0efh, 0e0h, 005h, 03ah, 00ch, 0e2h
        db      032h, 00ah, 0e2h, 0c3h, 070h, 0e1h, 0feh, 07fh, 0c2h, 026h, 0e1h, 078h, 0b7h, 0cah, 0efh, 0e0h
        db      07eh, 005h, 02bh, 0c3h, 0a9h, 0e1h, 0feh, 005h, 0c2h, 037h, 0e1h, 0c5h, 0e5h, 0cdh, 0c9h, 0e0h
        db      0afh, 032h, 00bh, 0e2h, 0c3h, 0f1h, 0e0h, 0feh, 010h, 0c2h, 048h, 0e1h, 0e5h, 021h, 00dh, 0e2h
        db      03eh, 001h, 096h, 077h, 0e1h, 0c3h, 0efh, 0e0h, 0feh, 018h, 0c2h, 05fh, 0e1h, 0e1h, 03ah, 00bh
        db      0e2h, 021h, 00ch, 0e2h, 0beh, 0d2h, 0e1h, 0e0h, 035h, 0cdh, 0a4h, 0e0h, 0c3h, 04eh, 0e1h, 0feh
        db      015h, 0c2h, 06bh, 0e1h, 0cdh, 0b1h, 0e0h, 0e1h, 0c3h, 0e1h, 0e0h, 0feh, 012h, 0c2h, 0a6h, 0e1h
        db      0c5h, 0cdh, 0b1h, 0e0h, 0c1h, 0e1h, 0e5h, 0c5h, 078h, 0b7h, 0cah, 08ah, 0e1h, 023h, 04eh, 005h
        db      0c5h, 0e5h, 0cdh, 07fh, 0e0h, 0e1h, 0c1h, 0c3h, 078h, 0e1h, 0e5h, 03ah, 00ah, 0e2h, 0b7h, 0cah
        db      0f1h, 0e0h, 021h, 00ch, 0e2h, 096h, 032h, 00ah, 0e2h, 0cdh, 0a4h, 0e0h, 021h, 00ah, 0e2h, 035h
        db      0c2h, 099h, 0e1h, 0c3h, 0f1h, 0e0h, 023h, 077h, 004h, 0c5h, 0e5h, 04fh, 0cdh, 07fh, 0e0h, 0e1h
        db      0c1h, 07eh, 0feh, 003h, 078h, 0c2h, 0bdh, 0e1h, 0feh, 001h, 0cah, 000h, 000h, 0b9h, 0dah, 0efh
        db      0e0h, 0e1h, 070h, 00eh, 00dh, 0c3h, 048h, 0e0h, 0cdh, 006h, 0e0h, 0c3h, 001h, 0e2h, 0cdh, 015h
        db      0edh, 0c3h, 001h, 0e2h, 079h, 03ch, 0cah, 0e0h, 0e1h, 03ch, 0cah, 006h, 0edh, 0c3h, 00ch, 0edh
        db      0cdh, 006h, 0edh, 0b7h, 0cah, 091h, 0ech, 0cdh, 009h, 0edh, 0c3h, 001h, 0e2h, 03ah, 003h, 000h
        db      0c3h, 001h, 0e2h, 021h, 003h, 000h, 071h, 0c9h, 0ebh, 04dh, 044h, 0c3h, 0d3h, 0e0h, 0cdh, 023h
        db      0e0h, 032h, 045h, 0e2h, 0c9h, 03eh, 001h, 0c3h, 001h, 0e2h, 000h, 002h, 002h, 000h, 000h, 0a7h
        db      0deh, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 058h, 0f0h, 005h, 0fbh, 00eh
        db      0e2h, 054h, 000h, 01fh, 0f4h, 02ah, 0f4h, 0f4h, 0e0h, 007h, 0d7h, 07fh, 000h, 007h, 0d7h, 074h
        db      0ech, 000h, 000h, 006h, 0d7h, 000h, 000h, 021h, 00bh, 0dfh, 05eh, 023h, 056h, 0ebh, 0e9h, 00ch
        db      00dh, 0c8h, 01ah, 077h, 013h, 023h, 0c3h, 050h, 0e2h, 03ah, 042h, 0e2h, 04fh, 0cdh, 01bh, 0edh
        db      07ch, 0b5h, 0c8h, 05eh, 023h, 056h, 023h, 022h, 0b3h, 0ech, 023h, 023h, 022h, 0b5h, 0ech, 023h
        db      023h, 022h, 0b7h, 0ech, 023h, 023h, 0ebh, 022h, 0d0h, 0ech, 021h, 0b9h, 0ech, 00eh, 008h, 0cdh
        db      04fh, 0e2h, 02ah, 0bbh, 0ech, 0ebh, 021h, 0c1h, 0ech, 00eh, 00fh, 0cdh, 04fh, 0e2h, 02ah, 0c6h
        db      0ech, 07ch, 021h, 0ddh, 0ech, 036h, 0ffh, 0b7h, 0cah, 09dh, 0e2h, 036h, 000h, 03eh, 0ffh, 0b7h
        db      0c9h, 0cdh, 018h, 0edh, 0afh, 02ah, 0b5h, 0ech, 077h, 023h, 077h, 02ah, 0b7h, 0ech, 077h, 023h
        db      077h, 0c9h, 0cdh, 027h, 0edh, 0c3h, 0bbh, 0e2h, 0cdh, 02ah, 0edh, 0b7h, 0c8h, 021h, 009h, 0dfh
        db      0c3h, 04ah, 0e2h, 02ah, 0eah, 0ech, 00eh, 002h, 0cdh, 0eah, 0e3h, 022h, 0e5h, 0ech, 022h, 0ech
        db      0ech, 021h, 0e5h, 0ech, 04eh, 023h, 046h, 02ah, 0b7h, 0ech, 05eh, 023h, 056h, 02ah, 0b5h, 0ech
        db      07eh, 023h, 066h, 06fh, 079h, 093h, 078h, 09ah, 0d2h, 0fah, 0e2h, 0e5h, 02ah, 0c1h, 0ech, 07bh
        db      095h, 05fh, 07ah, 09ch, 057h, 0e1h, 02bh, 0c3h, 0e4h, 0e2h, 0e5h, 02ah, 0c1h, 0ech, 019h, 0dah
        db      00fh, 0e3h, 079h, 095h, 078h, 09ch, 0dah, 00fh, 0e3h, 0ebh, 0e1h, 023h, 0c3h, 0fah, 0e2h, 0e1h
        db      0c5h, 0d5h, 0e5h, 0ebh, 02ah, 0ceh, 0ech, 019h, 044h, 04dh, 0cdh, 01eh, 0edh, 0d1h, 02ah, 0b5h
        db      0ech, 073h, 023h, 072h, 0d1h, 02ah, 0b7h, 0ech, 073h, 023h, 072h, 0c1h, 079h, 093h, 04fh, 078h
        db      09ah, 047h, 02ah, 0d0h, 0ech, 0ebh, 0cdh, 030h, 0edh, 04dh, 044h, 0c3h, 021h, 0edh, 021h, 0c3h
        db      0ech, 04eh, 03ah, 0e3h, 0ech, 0b7h, 01fh, 00dh, 0c2h, 045h, 0e3h, 047h, 03eh, 008h, 096h, 04fh
        db      03ah, 0e2h, 0ech, 00dh, 0cah, 05ch, 0e3h, 0b7h, 017h, 0c3h, 053h, 0e3h, 080h, 0c9h, 02ah, 043h
        db      0e2h, 011h, 010h, 000h, 019h, 009h, 03ah, 0ddh, 0ech, 0b7h, 0cah, 071h, 0e3h, 06eh, 026h, 000h
        db      0c9h, 009h, 05eh, 023h, 056h, 0ebh, 0c9h, 0cdh, 03eh, 0e3h, 04fh, 006h, 000h, 0cdh, 05eh, 0e3h
        db      022h, 0e5h, 0ech, 0c9h, 02ah, 0e5h, 0ech, 07dh, 0b4h, 0c9h, 03ah, 0c3h, 0ech, 02ah, 0e5h, 0ech
        db      029h, 03dh, 0c2h, 090h, 0e3h, 022h, 0e7h, 0ech, 03ah, 0c4h, 0ech, 04fh, 03ah, 0e3h, 0ech, 0a1h
        db      0b5h, 06fh, 022h, 0e5h, 0ech, 0c9h, 02ah, 043h, 0e2h, 011h, 00ch, 000h, 019h, 0c9h, 02ah, 043h
        db      0e2h, 011h, 00fh, 000h, 019h, 0ebh, 021h, 011h, 000h, 019h, 0c9h, 0cdh, 0aeh, 0e3h, 07eh, 032h
        db      0e3h, 0ech, 0ebh, 07eh, 032h, 0e1h, 0ech, 0cdh, 0a6h, 0e3h, 03ah, 0c5h, 0ech, 0a6h, 032h, 0e2h
        db      0ech, 0c9h, 0cdh, 0aeh, 0e3h, 03ah, 0d5h, 0ech, 0feh, 002h, 0c2h, 0deh, 0e3h, 0afh, 04fh, 03ah
        db      0e3h, 0ech, 081h, 077h, 0ebh, 03ah, 0e1h, 0ech, 077h, 0c9h, 00ch, 00dh, 0c8h, 07ch, 0b7h, 01fh
        db      067h, 07dh, 01fh, 06fh, 0c3h, 0ebh, 0e3h, 00eh, 080h, 02ah, 0b9h, 0ech, 0afh, 086h, 023h, 00dh
        db      0c2h, 0fdh, 0e3h, 0c9h, 00ch, 00dh, 0c8h, 029h, 0c3h, 005h, 0e4h, 0c5h, 03ah, 042h, 0e2h, 04fh
        db      021h, 001h, 000h, 0cdh, 004h, 0e4h, 0c1h, 079h, 0b5h, 06fh, 078h, 0b4h, 067h, 0c9h, 02ah, 0adh
        db      0ech, 03ah, 042h, 0e2h, 04fh, 0cdh, 0eah, 0e3h, 07dh, 0e6h, 001h, 0c9h, 021h, 0adh, 0ech, 04eh
        db      023h, 046h, 0cdh, 00bh, 0e4h, 022h, 0adh, 0ech, 02ah, 0c8h, 0ech, 023h, 0ebh, 02ah, 0b3h, 0ech
        db      073h, 023h, 072h, 0c9h, 0cdh, 05eh, 0e4h, 011h, 009h, 000h, 019h, 07eh, 017h, 0d0h, 021h, 00fh
        db      0dfh, 0c3h, 04ah, 0e2h, 0cdh, 01eh, 0e4h, 0c8h, 021h, 00dh, 0dfh, 0c3h, 04ah, 0e2h, 02ah, 0b9h
        db      0ech, 03ah, 0e9h, 0ech, 085h, 06fh, 0d0h, 024h, 0c9h, 02ah, 043h, 0e2h, 011h, 00eh, 000h, 019h
        db      07eh, 0c9h, 0cdh, 069h, 0e4h, 036h, 000h, 0c9h, 0cdh, 069h, 0e4h, 0f6h, 080h, 077h, 0c9h, 02ah
        db      0eah, 0ech, 0ebh, 02ah, 0b3h, 0ech, 07bh, 096h, 023h, 07ah, 09eh, 0c9h, 0cdh, 07fh, 0e4h, 0d8h
        db      013h, 072h, 02bh, 073h, 0c9h, 07bh, 095h, 06fh, 07ah, 09ch, 067h, 0c9h, 00eh, 0ffh, 02ah, 0ech
        db      0ech, 0ebh, 02ah, 0cch, 0ech, 0cdh, 095h, 0e4h, 0d0h, 0c5h, 0cdh, 0f7h, 0e3h, 02ah, 0bdh, 0ech
        db      0ebh, 02ah, 0ech, 0ech, 019h, 0c1h, 00ch, 0cah, 0c4h, 0e4h, 0beh, 0c8h, 0cdh, 07fh, 0e4h, 0d0h
        db      0cdh, 02ch, 0e4h, 0c9h, 077h, 0c9h, 0cdh, 09ch, 0e4h, 0cdh, 0e0h, 0e4h, 00eh, 001h, 0cdh, 0b8h
        db      0e2h, 0c3h, 0dah, 0e4h, 0cdh, 0e0h, 0e4h, 0cdh, 0b2h, 0e2h, 021h, 0b1h, 0ech, 0c3h, 0e3h, 0e4h
        db      021h, 0b9h, 0ech, 04eh, 023h, 046h, 0c3h, 024h, 0edh, 02ah, 0b9h, 0ech, 0ebh, 02ah, 0b1h, 0ech
        db      00eh, 080h, 0c3h, 04fh, 0e2h, 021h, 0eah, 0ech, 07eh, 023h, 0beh, 0c0h, 03ch, 0c9h, 021h, 0ffh
        db      0ffh, 022h, 0eah, 0ech, 0c9h, 02ah, 0c8h, 0ech, 0ebh, 02ah, 0eah, 0ech, 023h, 022h, 0eah, 0ech
        db      0cdh, 095h, 0e4h, 0d2h, 019h, 0e5h, 0c3h, 0feh, 0e4h, 03ah, 0eah, 0ech, 0e6h, 003h, 006h, 005h
        db      087h, 005h, 0c2h, 020h, 0e5h, 032h, 0e9h, 0ech, 0b7h, 0c0h, 0c5h, 0cdh, 0c3h, 0e2h, 0cdh, 0d4h
        db      0e4h, 0c1h, 0c3h, 09eh, 0e4h, 079h, 0e6h, 007h, 03ch, 05fh, 057h, 079h, 00fh, 00fh, 00fh, 0e6h
        db      01fh, 04fh, 078h, 087h, 087h, 087h, 087h, 087h, 0b1h, 04fh, 078h, 00fh, 00fh, 00fh, 0e6h, 01fh
        db      047h, 02ah, 0bfh, 0ech, 009h, 07eh, 007h, 01dh, 0c2h, 056h, 0e5h, 0c9h, 0d5h, 0cdh, 035h, 0e5h
        db      0e6h, 0feh, 0c1h, 0b1h, 00fh, 015h, 0c2h, 064h, 0e5h, 077h, 0c9h, 0cdh, 05eh, 0e4h, 011h, 010h
        db      000h, 019h, 0c5h, 00eh, 011h, 0d1h, 00dh, 0c8h, 0d5h, 03ah, 0ddh, 0ech, 0b7h, 0cah, 088h, 0e5h
        db      0c5h, 0e5h, 04eh, 006h, 000h, 0c3h, 08eh, 0e5h, 00dh, 0c5h, 04eh, 023h, 046h, 0e5h, 079h, 0b0h
        db      0cah, 09dh, 0e5h, 02ah, 0c6h, 0ech, 07dh, 091h, 07ch, 098h, 0d4h, 05ch, 0e5h, 0e1h, 023h, 0c1h
        db      0c3h, 075h, 0e5h, 02ah, 0c6h, 0ech, 00eh, 003h, 0cdh, 0eah, 0e3h, 023h, 044h, 04dh, 02ah, 0bfh
        db      0ech, 036h, 000h, 023h, 00bh, 078h, 0b1h, 0c2h, 0b1h, 0e5h, 02ah, 0cah, 0ech, 0ebh, 02ah, 0bfh
        db      0ech, 073h, 023h, 072h, 0cdh, 0a1h, 0e2h, 02ah, 0b3h, 0ech, 036h, 003h, 023h, 036h, 000h, 0cdh
        db      0feh, 0e4h, 00eh, 0ffh, 0cdh, 005h, 0e5h, 0cdh, 0f5h, 0e4h, 0c8h, 0cdh, 05eh, 0e4h, 03eh, 0e5h
        db      0beh, 0cah, 0d2h, 0e5h, 03ah, 041h, 0e2h, 0beh, 0c2h, 0f6h, 0e5h, 023h, 07eh, 0d6h, 024h, 0c2h
        db      0f6h, 0e5h, 03dh, 032h, 045h, 0e2h, 00eh, 001h, 0cdh, 06bh, 0e5h, 0cdh, 08ch, 0e4h, 0c3h, 0d2h
        db      0e5h, 03ah, 0d4h, 0ech, 0c3h, 001h, 0e2h, 0c5h, 0f5h, 03ah, 0c5h, 0ech, 02fh, 047h, 079h, 0a0h
        db      04fh, 0f1h, 0a0h, 091h, 0e6h, 01fh, 0c1h, 0c9h, 03eh, 0ffh, 032h, 0d4h, 0ech, 021h, 0d8h, 0ech
        db      071h, 02ah, 043h, 0e2h, 022h, 0d9h, 0ech, 0cdh, 0feh, 0e4h, 0cdh, 0a1h, 0e2h, 00eh, 000h, 0cdh
        db      005h, 0e5h, 0cdh, 0f5h, 0e4h, 0cah, 094h, 0e6h, 02ah, 0d9h, 0ech, 0ebh, 01ah, 0feh, 0e5h, 0cah
        db      04ah, 0e6h, 0d5h, 0cdh, 07fh, 0e4h, 0d1h, 0d2h, 094h, 0e6h, 0cdh, 05eh, 0e4h, 03ah, 0d8h, 0ech
        db      04fh, 006h, 000h, 079h, 0b7h, 0cah, 083h, 0e6h, 01ah, 0feh, 03fh, 0cah, 07ch, 0e6h, 078h, 0feh
        db      00dh, 0cah, 07ch, 0e6h, 0feh, 00ch, 01ah, 0cah, 073h, 0e6h, 096h, 0e6h, 07fh, 0c2h, 02dh, 0e6h
        db      0c3h, 07ch, 0e6h, 0c5h, 04eh, 0cdh, 007h, 0e6h, 0c1h, 0c2h, 02dh, 0e6h, 013h, 023h, 004h, 00dh
        db      0c3h, 053h, 0e6h, 03ah, 0eah, 0ech, 0e6h, 003h, 032h, 045h, 0e2h, 021h, 0d4h, 0ech, 07eh, 017h
        db      0d0h, 0afh, 077h, 0c9h, 0cdh, 0feh, 0e4h, 03eh, 0ffh, 0c3h, 001h, 0e2h, 0cdh, 054h, 0e4h, 00eh
        db      00ch, 0cdh, 018h, 0e6h, 0cdh, 0f5h, 0e4h, 0c8h, 0cdh, 044h, 0e4h, 0cdh, 05eh, 0e4h, 036h, 0e5h
        db      00eh, 000h, 0cdh, 06bh, 0e5h, 0cdh, 0c6h, 0e4h, 0cdh, 02dh, 0e6h, 0c3h, 0a4h, 0e6h, 050h, 059h
        db      079h, 0b0h, 0cah, 0d1h, 0e6h, 00bh, 0d5h, 0c5h, 0cdh, 035h, 0e5h, 01fh, 0d2h, 0ech, 0e6h, 0c1h
        db      0d1h, 02ah, 0c6h, 0ech, 07bh, 095h, 07ah, 09ch, 0d2h, 0f4h, 0e6h, 013h, 0c5h, 0d5h, 042h, 04bh
        db      0cdh, 035h, 0e5h, 01fh, 0d2h, 0ech, 0e6h, 0d1h, 0c1h, 0c3h, 0c0h, 0e6h, 017h, 03ch, 0cdh, 064h
        db      0e5h, 0e1h, 0d1h, 0c9h, 079h, 0b0h, 0c2h, 0c0h, 0e6h, 021h, 000h, 000h, 0c9h, 00eh, 000h, 01eh
        db      020h, 0d5h, 006h, 000h, 02ah, 043h, 0e2h, 009h, 0ebh, 0cdh, 05eh, 0e4h, 0c1h, 0cdh, 04fh, 0e2h
        db      0cdh, 0c3h, 0e2h, 0c3h, 0c6h, 0e4h, 0cdh, 054h, 0e4h, 00eh, 00ch, 0cdh, 018h, 0e6h, 02ah, 043h
        db      0e2h, 07eh, 011h, 010h, 000h, 019h, 077h, 0cdh, 0f5h, 0e4h, 0c8h, 0cdh, 044h, 0e4h, 00eh, 010h
        db      01eh, 00ch, 0cdh, 001h, 0e7h, 0cdh, 02dh, 0e6h, 0c3h, 027h, 0e7h, 00eh, 00ch, 0cdh, 018h, 0e6h
        db      0cdh, 0f5h, 0e4h, 0c8h, 00eh, 000h, 01eh, 00ch, 0cdh, 001h, 0e7h, 0cdh, 02dh, 0e6h, 0c3h, 040h
        db      0e7h, 00eh, 00fh, 0cdh, 018h, 0e6h, 0cdh, 0f5h, 0e4h, 0c8h, 0cdh, 0a6h, 0e3h, 07eh, 0f5h, 0e5h
        db      0cdh, 05eh, 0e4h, 0ebh, 02ah, 043h, 0e2h, 00eh, 020h, 0d5h, 0cdh, 04fh, 0e2h, 0cdh, 078h, 0e4h
        db      0d1h, 021h, 00ch, 000h, 019h, 04eh, 021h, 00fh, 000h, 019h, 046h, 0e1h, 0f1h, 077h, 079h, 0beh
        db      078h, 0cah, 08bh, 0e7h, 03eh, 000h, 0dah, 08bh, 0e7h, 03eh, 080h, 02ah, 043h, 0e2h, 011h, 00fh
        db      000h, 019h, 077h, 0c9h, 07eh, 023h, 0b6h, 02bh, 0c0h, 01ah, 077h, 013h, 023h, 01ah, 077h, 01bh
        db      02bh, 0c9h, 0afh, 032h, 045h, 0e2h, 032h, 0eah, 0ech, 032h, 0ebh, 0ech, 0cdh, 01eh, 0e4h, 0c0h
        db      0cdh, 069h, 0e4h, 0e6h, 080h, 0c0h, 00eh, 00fh, 0cdh, 018h, 0e6h, 0cdh, 0f5h, 0e4h, 0c8h, 001h
        db      010h, 000h, 0cdh, 05eh, 0e4h, 009h, 0ebh, 02ah, 043h, 0e2h, 009h, 00eh, 010h, 03ah, 0ddh, 0ech
        db      0b7h, 0cah, 0e8h, 0e7h, 07eh, 0b7h, 01ah, 0c2h, 0dbh, 0e7h, 077h, 0b7h, 0c2h, 0e1h, 0e7h, 07eh
        db      012h, 0beh, 0c2h, 01fh, 0e8h, 0c3h, 0fdh, 0e7h, 0cdh, 094h, 0e7h, 0ebh, 0cdh, 094h, 0e7h, 0ebh
        db      01ah, 0beh, 0c2h, 01fh, 0e8h, 013h, 023h, 01ah, 0beh, 0c2h, 01fh, 0e8h, 00dh, 013h, 023h, 00dh
        db      0c2h, 0cdh, 0e7h, 001h, 0ech, 0ffh, 009h, 0ebh, 009h, 01ah, 0beh, 0dah, 017h, 0e8h, 077h, 001h
        db      003h, 000h, 009h, 0ebh, 009h, 07eh, 012h, 03eh, 0ffh, 032h, 0d2h, 0ech, 0c3h, 010h, 0e7h, 021h
        db      045h, 0e2h, 035h, 0c9h, 0cdh, 054h, 0e4h, 02ah, 043h, 0e2h, 0e5h, 021h, 0ach, 0ech, 022h, 043h
        db      0e2h, 00eh, 001h, 0cdh, 018h, 0e6h, 0cdh, 0f5h, 0e4h, 0e1h, 022h, 043h, 0e2h, 0c8h, 0ebh, 021h
        db      00fh, 000h, 019h, 00eh, 011h, 0afh, 077h, 023h, 00dh, 0c2h, 046h, 0e8h, 021h, 00dh, 000h, 019h
        db      077h, 0cdh, 08ch, 0e4h, 0cdh, 0fdh, 0e6h, 0c3h, 078h, 0e4h, 0afh, 032h, 0d2h, 0ech, 0cdh, 0a2h
        db      0e7h, 0cdh, 0f5h, 0e4h, 0c8h, 02ah, 043h, 0e2h, 001h, 00ch, 000h, 009h, 07eh, 03ch, 0e6h, 01fh
        db      077h, 0cah, 083h, 0e8h, 047h, 03ah, 0c5h, 0ech, 0a0h, 021h, 0d2h, 0ech, 0a6h, 0cah, 08eh, 0e8h
        db      0c3h, 0ach, 0e8h, 001h, 002h, 000h, 009h, 034h, 07eh, 0e6h, 00fh, 0cah, 0b6h, 0e8h, 00eh, 00fh
        db      0cdh, 018h, 0e6h, 0cdh, 0f5h, 0e4h, 0c2h, 0ach, 0e8h, 03ah, 0d3h, 0ech, 03ch, 0cah, 0b6h, 0e8h
        db      0cdh, 024h, 0e8h, 0cdh, 0f5h, 0e4h, 0cah, 0b6h, 0e8h, 0c3h, 0afh, 0e8h, 0cdh, 05ah, 0e7h, 0cdh
        db      0bbh, 0e3h, 0afh, 0c3h, 001h, 0e2h, 0cdh, 005h, 0e2h, 0c3h, 078h, 0e4h, 03eh, 001h, 032h, 0d5h
        db      0ech, 03eh, 0ffh, 032h, 0d3h, 0ech, 0cdh, 0bbh, 0e3h, 03ah, 0e3h, 0ech, 021h, 0e1h, 0ech, 0beh
        db      0dah, 0e6h, 0e8h, 0feh, 080h, 0c2h, 0fbh, 0e8h, 0cdh, 05ah, 0e8h, 0afh, 032h, 0e3h, 0ech, 03ah
        db      045h, 0e2h, 0b7h, 0c2h, 0fbh, 0e8h, 0cdh, 077h, 0e3h, 0cdh, 084h, 0e3h, 0cah, 0fbh, 0e8h, 0cdh
        db      08ah, 0e3h, 0cdh, 0d1h, 0e2h, 0cdh, 0b2h, 0e2h, 0c3h, 0d2h, 0e3h, 0c3h, 005h, 0e2h, 03eh, 001h
        db      032h, 0d5h, 0ech, 03eh, 000h, 032h, 0d3h, 0ech, 0cdh, 054h, 0e4h, 02ah, 043h, 0e2h, 0cdh, 047h
        db      0e4h, 0cdh, 0bbh, 0e3h, 03ah, 0e3h, 0ech, 0feh, 080h, 0d2h, 005h, 0e2h, 0cdh, 077h, 0e3h, 0cdh
        db      084h, 0e3h, 00eh, 000h, 0c2h, 06eh, 0e9h, 0cdh, 03eh, 0e3h, 032h, 0d7h, 0ech, 001h, 000h, 000h
        db      0b7h, 0cah, 03bh, 0e9h, 04fh, 00bh, 0cdh, 05eh, 0e3h, 044h, 04dh, 0cdh, 0beh, 0e6h, 07dh, 0b4h
        db      0c2h, 048h, 0e9h, 03eh, 002h, 0c3h, 001h, 0e2h, 022h, 0e5h, 0ech, 0ebh, 02ah, 043h, 0e2h, 001h
        db      010h, 000h, 009h, 03ah, 0ddh, 0ech, 0b7h, 03ah, 0d7h, 0ech, 0cah, 064h, 0e9h, 0cdh, 064h, 0e4h
        db      073h, 0c3h, 06ch, 0e9h, 04fh, 006h, 000h, 009h, 009h, 073h, 023h, 072h, 00eh, 002h, 03ah, 045h
        db      0e2h, 0b7h, 0c0h, 0c5h, 0cdh, 08ah, 0e3h, 03ah, 0d5h, 0ech, 03dh, 03dh, 0c2h, 0bbh, 0e9h, 0c1h
        db      0c5h, 079h, 03dh, 03dh, 0c2h, 0bbh, 0e9h, 0e5h, 02ah, 0b9h, 0ech, 057h, 077h, 023h, 014h, 0f2h
        db      08ch, 0e9h, 0cdh, 0e0h, 0e4h, 02ah, 0e7h, 0ech, 00eh, 002h, 022h, 0e5h, 0ech, 0c5h, 0cdh, 0d1h
        db      0e2h, 0c1h, 0cdh, 0b8h, 0e2h, 02ah, 0e5h, 0ech, 00eh, 000h, 03ah, 0c4h, 0ech, 047h, 0a5h, 0b8h
        db      023h, 0c2h, 09ah, 0e9h, 0e1h, 022h, 0e5h, 0ech, 0cdh, 0dah, 0e4h, 0cdh, 0d1h, 0e2h, 0c1h, 0c5h
        db      0cdh, 0b8h, 0e2h, 0c1h, 03ah, 0e3h, 0ech, 021h, 0e1h, 0ech, 0beh, 0dah, 0d2h, 0e9h, 077h, 034h
        db      00eh, 002h, 000h, 000h, 021h, 000h, 000h, 0f5h, 0cdh, 069h, 0e4h, 0e6h, 07fh, 077h, 0f1h, 0feh
        db      07fh, 0c2h, 000h, 0eah, 03ah, 0d5h, 0ech, 0feh, 001h, 0c2h, 000h, 0eah, 0cdh, 0d2h, 0e3h, 0cdh
        db      05ah, 0e8h, 021h, 045h, 0e2h, 07eh, 0b7h, 0c2h, 0feh, 0e9h, 03dh, 032h, 0e3h, 0ech, 036h, 000h
        db      0c3h, 0d2h, 0e3h, 0afh, 032h, 0d5h, 0ech, 0c5h, 02ah, 043h, 0e2h, 0ebh, 021h, 021h, 000h, 019h
        db      07eh, 0e6h, 07fh, 0f5h, 07eh, 017h, 023h, 07eh, 017h, 0e6h, 01fh, 04fh, 07eh, 01fh, 01fh, 01fh
        db      01fh, 0e6h, 00fh, 047h, 0f1h, 023h, 06eh, 02ch, 02dh, 02eh, 006h, 0c2h, 08bh, 0eah, 021h, 020h
        db      000h, 019h, 077h, 021h, 00ch, 000h, 019h, 079h, 096h, 0c2h, 047h, 0eah, 021h, 00eh, 000h, 019h
        db      078h, 096h, 0e6h, 07fh, 0cah, 07fh, 0eah, 0c5h, 0d5h, 0cdh, 0a2h, 0e7h, 0d1h, 0c1h, 02eh, 003h
        db      03ah, 045h, 0e2h, 03ch, 0cah, 084h, 0eah, 021h, 00ch, 000h, 019h, 071h, 021h, 00eh, 000h, 019h
        db      070h, 0cdh, 051h, 0e7h, 03ah, 045h, 0e2h, 03ch, 0c2h, 07fh, 0eah, 0c1h, 0c5h, 02eh, 004h, 00ch
        db      0cah, 084h, 0eah, 0cdh, 024h, 0e8h, 02eh, 005h, 03ah, 045h, 0e2h, 03ch, 0cah, 084h, 0eah, 0c1h
        db      0afh, 0c3h, 001h, 0e2h, 0e5h, 0cdh, 069h, 0e4h, 036h, 0c0h, 0e1h, 0c1h, 07dh, 032h, 045h, 0e2h
        db      0c3h, 078h, 0e4h, 00eh, 0ffh, 0cdh, 003h, 0eah, 0cch, 0c1h, 0e8h, 0c9h, 00eh, 000h, 0cdh, 003h
        db      0eah, 0cch, 003h, 0e9h, 0c9h, 0ebh, 019h, 04eh, 006h, 000h, 021h, 00ch, 000h, 019h, 07eh, 00fh
        db      0e6h, 080h, 081h, 04fh, 03eh, 000h, 088h, 047h, 07eh, 00fh, 0e6h, 00fh, 080h, 047h, 021h, 00eh
        db      000h, 019h, 07eh, 087h, 087h, 087h, 087h, 0f5h, 080h, 047h, 0f5h, 0e1h, 07dh, 0e1h, 0b5h, 0e6h
        db      001h, 0c9h, 00eh, 00ch, 0cdh, 018h, 0e6h, 02ah, 043h, 0e2h, 011h, 021h, 000h, 019h, 0e5h, 072h
        db      023h, 072h, 023h, 072h, 0cdh, 0f5h, 0e4h, 0cah, 00ch, 0ebh, 0cdh, 05eh, 0e4h, 011h, 00fh, 000h
        db      0cdh, 0a5h, 0eah, 0e1h, 0e5h, 05fh, 079h, 096h, 023h, 078h, 09eh, 023h, 07bh, 09eh, 0dah, 006h
        db      0ebh, 073h, 02bh, 070h, 02bh, 071h, 0cdh, 02dh, 0e6h, 0c3h, 0e4h, 0eah, 0e1h, 0c9h, 02ah, 043h
        db      0e2h, 011h, 020h, 000h, 0cdh, 0a5h, 0eah, 021h, 021h, 000h, 019h, 071h, 023h, 070h, 023h, 077h
        db      0c9h, 02ah, 0afh, 0ech, 03ah, 042h, 0e2h, 04fh, 0cdh, 0eah, 0e3h, 0e5h, 0ebh, 0cdh, 059h, 0e2h
        db      0e1h, 0cch, 047h, 0e2h, 07dh, 01fh, 0d8h, 02ah, 0afh, 0ech, 04dh, 044h, 0cdh, 00bh, 0e4h, 022h
        db      0afh, 0ech, 0c3h, 0a3h, 0e5h, 03ah, 0d6h, 0ech, 021h, 042h, 0e2h, 0beh, 0c8h, 077h, 0c3h, 021h
        db      0ebh, 03eh, 0ffh, 032h, 0deh, 0ech, 02ah, 043h, 0e2h, 07eh, 0e6h, 01fh, 03dh, 032h, 0d6h, 0ech
        db      0feh, 01eh, 0d2h, 075h, 0ebh, 03ah, 042h, 0e2h, 032h, 0dfh, 0ech, 07eh, 032h, 0e0h, 0ech, 0e6h
        db      0e0h, 077h, 0cdh, 045h, 0ebh, 03ah, 041h, 0e2h, 02ah, 043h, 0e2h, 0b6h, 077h, 0c9h, 03eh, 022h
        db      0c3h, 001h, 0e2h, 021h, 000h, 000h, 022h, 0adh, 0ech, 022h, 0afh, 0ech, 0afh, 032h, 042h, 0e2h
        db      021h, 080h, 000h, 022h, 0b1h, 0ech, 0cdh, 0dah, 0e4h, 0c3h, 021h, 0ebh, 0cdh, 072h, 0e4h, 0cdh
        db      051h, 0ebh, 0c3h, 051h, 0e7h, 0cdh, 051h, 0ebh, 0c3h, 0a2h, 0e7h, 00eh, 000h, 0ebh, 07eh, 0feh
        db      03fh, 0cah, 0c2h, 0ebh, 0cdh, 0a6h, 0e3h, 07eh, 0feh, 03fh, 0c4h, 072h, 0e4h, 0cdh, 051h, 0ebh
        db      00eh, 00fh, 0cdh, 018h, 0e6h, 0c3h, 0e9h, 0e4h, 02ah, 0d9h, 0ech, 022h, 043h, 0e2h, 0cdh, 051h
        db      0ebh, 0cdh, 02dh, 0e6h, 0c3h, 0e9h, 0e4h, 0cdh, 051h, 0ebh, 0cdh, 09ch, 0e6h, 0c3h, 001h, 0e6h
        db      0cdh, 051h, 0ebh, 0c3h, 0bch, 0e8h, 0cdh, 051h, 0ebh, 0c3h, 0feh, 0e8h, 0cdh, 072h, 0e4h, 0cdh
        db      051h, 0ebh, 0c3h, 024h, 0e8h, 0cdh, 051h, 0ebh, 0cdh, 016h, 0e7h, 0c3h, 001h, 0e6h, 02ah, 0afh
        db      0ech, 0c3h, 029h, 0ech, 03ah, 042h, 0e2h, 0c3h, 001h, 0e2h, 0ebh, 022h, 0b1h, 0ech, 0c3h, 0dah
        db      0e4h, 02ah, 0bfh, 0ech, 0c3h, 029h, 0ech, 02ah, 0adh, 0ech, 0c3h, 029h, 0ech, 0cdh, 051h, 0ebh
        db      0cdh, 03bh, 0e7h, 0c3h, 001h, 0e6h, 02ah, 0bbh, 0ech, 022h, 045h, 0e2h, 0c9h, 03ah, 0d6h, 0ech
        db      0feh, 0ffh, 0c2h, 03bh, 0ech, 03ah, 041h, 0e2h, 0c3h, 001h, 0e2h, 0e6h, 01fh, 032h, 041h, 0e2h
        db      0c9h, 0cdh, 051h, 0ebh, 0c3h, 093h, 0eah, 0cdh, 051h, 0ebh, 0c3h, 09ch, 0eah, 0cdh, 051h, 0ebh
        db      0c3h, 0d2h, 0eah, 02ah, 043h, 0e2h, 07dh, 02fh, 05fh, 07ch, 02fh, 02ah, 0afh, 0ech, 0a4h, 057h
        db      07dh, 0a3h, 05fh, 02ah, 0adh, 0ech, 0ebh, 022h, 0afh, 0ech, 07dh, 0a3h, 06fh, 07ch, 0a2h, 067h
        db      022h, 0adh, 0ech, 0c9h, 03ah, 0deh, 0ech, 0b7h, 0cah, 091h, 0ech, 02ah, 043h, 0e2h, 036h, 000h
        db      03ah, 0e0h, 0ech, 0b7h, 0cah, 091h, 0ech, 077h, 03ah, 0dfh, 0ech, 032h, 0d6h, 0ech, 0cdh, 045h
        db      0ebh, 02ah, 00fh, 0e2h, 0f9h, 02ah, 045h, 0e2h, 07dh, 044h, 0c9h, 0cdh, 051h, 0ebh, 03eh, 002h
        db      032h, 0d5h, 0ech, 00eh, 000h, 0cdh, 007h, 0eah, 0cch, 003h, 0e9h, 0c9h, 0e5h, 000h, 000h, 001h
        db      000h, 080h, 000h, 0deh, 0f1h, 0e0h, 0f1h, 0e2h, 0f1h, 001h, 0fch, 040h, 0f2h, 09ah, 0fch, 081h
        db      0fch, 028h, 000h, 004h, 00fh, 001h, 0a9h, 000h, 03fh, 000h, 080h, 000h, 010h, 000h, 002h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 006h, 000h, 000h, 000h, 000h, 000h, 000h, 0ffh, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 00fh, 000h, 000h, 000h, 060h, 0ffh, 0ffh, 00fh, 000h, 000h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
BDOSDataEnd     equ     $

BIOSDataStart:
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
BIOSDataEnd     equ     $

        end


