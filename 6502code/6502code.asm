;
; Pi1MHz 6502 helper code
;

discaccess = &FCD6

MACRO PAGERTS
    LDX #&FF
    JMP &FC88
ENDMACRO

MACRO ENDBLOCK pos
    SKIPTO &FE00
    COPYBLOCK &FD00, &FE00, pos
    CLEAR &FD00, &FE00
ENDMACRO

MACRO LOADFILETOSWR filename
{
    LDA &F4
    PHA
    LDX #15
.romlp
    stx    &f4
    stx    &fe30
;; Step 1: Test if candidate slot already contains a rom image
;; so we don't clobber any pre-existing ROM images
    ldy     &8007
    lda     &8000, Y
    bne     testram
    lda     &8001, Y
    cmp     #'('
    bne     testram
    lda     &8002, Y
    cmp     #'C'
    bne     testram
    lda     &8003, Y
    cmp     #')'
    bne     testram

;; Step 2: Test if that pre-existing rom image is SWMMFS
;; so we re-use the same slot again and again
     ;   lda     &b5fe
     ;   cmp     #MAGIC0
     ;   bne     romnxt
     ;   lda     &b5ff
     ;   cmp     #MAGIC1
     ;   bne     romnxt
    beq romnxt
;; Step 3: Check if slot is RAM
.testram
    lda     &8006
    eor     #&FF
    sta     &8006
    cmp     &8006
    PHP
    eor     #&FF
        sta     &8006
        PLP
        beq     SWRfound
.romnxt
    dex
    bpl     romlp

; no SWR found
.noswr
    PLA
    sta    &f4
    sta    &fe30
   ; should really put the error on the stack
   ; and fake RTS on the stack
   ; LDX     #255
   ; STX     &FC88   ; Restore JIM
    BRK
    EQUB 255: EQUS "No SWR":EQUB 0
}
.fileerror

    PLA
    sta    &f4
    sta    &fe30
   ; should really put the error on the stack
   ; and fake RTS on the stack
   ; LDX     #255
   ; STX     &FC88   ; Restore JIM
    BRK
    EQUB &D6: EQUS "No ROM":EQUB 0

.SWRfound

    ; fopen
    LDY #0   : STY discaccess
    DEY      : STY discaccess+1
               STY discaccess+2

.fopenloop
    INY
    LDA fopenstring, Y: STA discaccess+3
    BPL fopenloop
    STA discaccess+4

.fopencheckloop
    LDA discaccess+4
    BMI fopencheckloop
    BNE fileerror ; file not found

    LDY #0   : STY discaccess

.freadsetuploop
    LDA freaddata, Y: STA discaccess+3
    INY
    CMP #255
    BNE freadsetuploop
    STA discaccess+4

.freadcheckloop
    LDA discaccess+4
    BEQ readdone
    BMI freadcheckloop
    CMP #20
    BNE fileerror ; file open error

.readdone
    LDY #0   : STY discaccess
             : STY discaccess+1
    LDA #&F0 : STA discaccess+2

             : STY swrpointer+1
    LDA #&80 : STA swrpointer+2

    LDX #&C0-&80
.copyswrloop
    LDA discaccess+3
.swrpointer
    STA &8000,Y
    INY
    BNE copyswrloop

    INC swrpointer+2
    DEX
    BNE copyswrloop;
    ; Y is zero
           : STY discaccess
    DEY    : STY discaccess+1
             STY discaccess+2
    ; fclose
    LDA #3
    STA discaccess+3
    STY discaccess+4

    LDA #200
    LDX #3
    JSR &FFF4
    JMP (&FFFC) ; Reset


.fopenstring
    EQUB 2, 0, 1 : EQUS filename : EQUB 0, 255

.freaddata
    EQUB 4, 0, &40, 0
    EQUB 0, 0, &F0, 0
    EQUB 0, 0, 0, 0
    EQUB &FF

ENDMACRO

; Page 0
; help screen
{
ORG &FD00
    LDA #0   : STA discaccess ; clear byte pointer to zero.
    LDA #&E0 : STA discaccess+1
    LDA #&FF : STA discaccess+2
.stringloop
    LDA discaccess+3 ; auto increment register
    JSR &FFEE
    TAX ; Set flags
    BNE stringloop
    PAGERTS

  ENDBLOCK &000
}
; page 1 status screen
{
    ORG &FD00
    PAGERTS

    ENDBLOCK &100
}

; Page 2
; oswrch redirector
{
ORG &FD00

newoswrch = &FCD1

  LDA &20E
  STA newoswrch+4
  LDA &20F
  STA newoswrch+4+1
  LDA #(newoswrch MOD 256)
  STA &20E
  LDA #(newoswrch DIV 256)
  STA &20F
  PAGERTS

  ENDBLOCK &200
}

; Page 3
; ADFS
{
ORG &FD00
    LOADFILETOSWR "ROMS/ADFS.rom"
    ENDBLOCK &300
}

; Page 4
; MMFS
{
ORG &FD00
    LOADFILETOSWR "ROMS/MMFS.rom"
    ENDBLOCK &400
}

; Page 5
; MMFSv2
{
ORG &FD00
    LOADFILETOSWR "ROMS/MMFS2.rom"
    ENDBLOCK &500
}

.end

SAVE "../firmware/6502code.bin" , 0, &600
