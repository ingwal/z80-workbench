;WADUZITDO
;Z80 VERSION OF THE 8080 PROGRAM BY LARRY KHERIATY
;
;THE OBJECT CODE IS THE 8080 CODE FROM BYTE, SEPT 1978,
;WRITTEN WITH ZILOG MNEMONICS. LINES MARKED + ARE CHANGED
;TO USE THE Z80 WORKBENCH TERMINAL INSTEAD OF SOLOS/CUTER.
;
SUB     EQU   0000H         ; USER SUBR START (CAN BE MODIFIED)
        ORG   0000H
;ENTER SYSTEM AT LOCATION 0 WITH STACK POINTER PRESET
;TO SCRATCH PAD RAM ENOUGH FOR A FEW LEVELS OF CALL

START:  LD    HL,(LOC)      ; SOURCE PROGRAM AREA START
EGET:   CALL  JIN           ; ACCEPT SOURCE CHAR
        CP    5CH           ; \ ?
        JP    Z,START       ; YES, BACK UP TO PROGRAM START

        CP    24H           ; $ ?
        JP    Z,EXEC        ; YES, GO EXECUTE THE PROGRAM

        CP    5FH           ; BS ?  (THE _ KEY)
        JP    NZ,DIS        ; NO
        DEC   HL            ; YES, BACK UP ONE IN SOURCE
        JP    EGET          ; LOOP BACK

;PROCESS DISPLAY OF NEXT LINE
DIS:    CP    2FH           ; / ?
        JP    NZ,PAD        ; NO
        CALL  PRT           ; GO PRINT TO CR
        JP    EGET          ; LOOP

;DO LINE REPLACEMENT- PAD TO END OF STMT WITH NULLS
PAD:    CP    25H           ; % ?
        JP    NZ,CHAR       ; NO
        LD    B,0DH         ; CR
        LD    A,B           ; CR TO A ALSO
        CALL  JOUT          ; PRINT IT
        LD    C,40H         ; COUNT OF 64
PADL:   CP    (HL)          ; AT CR YET ?
        JP    Z,CHAR        ; YES QUIT PADDING
        LD    (HL),00H      ; PAD WITH NULL
        INC   HL            ; INCR LOC PTR
        DEC   C             ; DECREMENT SAFETY COUNTER
        JP    NZ,PADL       ; LOOP TILL CR OR 64 NULLS

;STORE ENTERED SOURCE CHAR IN PROGRAM
CHAR:   LD    (HL),A        ; CHAR TO SOURCE LOC
        INC   HL            ; MOVE LOC PTR UP ONE
        CP    0DH           ; IS IT A CR ?
        CALL  Z,PLF         ; YES, ECHO A LINE FEED
        JP    EGET          ; NO, GET ANOTHER CHAR

;CHARACTER INPUT AND OUTPUT. THE TWO CALLS GO TO THE
;WORKBENCH ROUTINES KEYIN AND CHOUT (SOLOS/CUTER: 0C01FH, 0C019H)
JIN:    CALL  KEYIN         ; + CALL CHAR INPUT ROUTINE
        JP    Z,JIN         ; TRY AGAIN IF NO CHAR YET THERE
        LD    B,A           ; PREPARE TO ECHO THE CHAR
JOUT:   CALL  CHOUT         ; + CALL CHARACTER OUTPUT ROUTINE
        LD    A,B           ; RESTORE JIN CHAR TO A
        RET                 ; RETURN TO CALLER

;COME HERE TO BEGIN EXECUTION OF THE SOURCE PROGRAM
EXEC:   LD    HL,(LOC)      ; STARTING LOC OF PROGRAM
        DEC   HL            ; LESS ONE
LOOPI:  INC   HL            ; ADR OF NEXT PGM BYTE
LOOP:   LD    A,(HL)        ; NEXT PGM BYTE
        CP    2BH           ; * CHAR ? (NOTE 2BH IS '*'+1)
        JP    M,LOOPI       ; YES (OR IGNOREABLE CONT CHAR)

;PROCESS Y OR N FLAG TESTS
        CP    59H           ; Y ?
        JP    Z,TFLG        ; YES
        CP    4EH           ; N ?
        JP    NZ,XA         ; BRANCH IF NOT A FLAG TEST

TFLG:   INC   HL            ; STEP LOC OVER Y OR N
        CP    D             ; COMPARE TO CURRENT MATCH FLAG
        JP    Z,LOOP        ; ITS EQUAL SO EXECUTE THE STMT

;ITS A FLAG FAILURE, SKIP OVER THE STMT
SKIP:   INC   HL            ; STEP LOC PTR
        LD    A,(HL)        ; NEXT CHAR IN PGM
        CP    0DH           ; TO END OF STMT ?
        JP    NZ,SKIP       ; NOT YET, SO LOOP
        JP    LOOPI         ; AT NEXT STMT, GO DO IT

;PROCESS ACCEPT STATEMENT
XA:     CP    41H           ; A ?
        JP    NZ,XM         ; NO
        LD    (LST),HL      ; YES, SAVE LOC OF LAST ACCEPT
        CALL  JIN           ; ACCEPT ONE CHAR FROM KYBD
        LD    E,A           ; SAVE IT
        INC   HL            ; MOVE OVER A
        LD    B,0DH         ; CR
        CALL  JOUT          ; PRINT IT
        CALL  PLF           ; PRINT LINE FEED
        JP    LOOPI         ; STEP OVER : AND GO ON

;PROCESS MATCH STMT
XM:     CP    4DH           ; M ?
        JP    NZ,XJ         ; NO
        INC   HL            ; STEP OVER M
        INC   HL            ; STEP OVER :
        LD    A,(HL)        ; GET MATCH CHAR
        LD    D,59H         ; ASSUME Y
        CP    E             ; COMP MATCH CHAR TO INPUT CHAR
        JP    Z,MX          ; BRANCH IF IT MATCHES, FLG=Y
        LD    D,4EH         ; RESULT IS N
MX:     JP    LOOPI         ; MATCH FLAG (Y OR N) IS IN D

;PROCESS JUMP STATEMENT
XJ:     CP    4AH           ; J ?
        JP    NZ,XS         ; NO
        INC   HL            ; STEP OVER J
        INC   HL            ; STEP OVER :
        LD    A,(HL)        ; DESTINATION
        AND   0FH           ; CLEAR ZONE
        LD    B,A           ; NUMBER OF *S TO SKIP
        JP    NZ,JF         ; ITS A JUMP FORWARD
        LD    HL,(LST)      ; ZERO.. JUMP BACK TO LAST ACCEPT
        JP    LOOP          ; CONTINUE FROM THERE

;SKIP FORWARD UNTIL PASS N *-MARKERS ( N IS IN REG B )
JF:     INC   HL            ; STEP PGM LOC
        LD    A,(HL)        ; NEXT CHAR
        CP    2AH           ; *-MARKER ?
        JP    NZ,JF         ; NO, KEEP LOOPING
        DEC   B             ; FOUND ONE, COUNT IT
        JP    NZ,JF         ; LOOP IF NEED TO FIND MORE
        JP    LOOPI         ; DESTINATION FOUND, GO EXECUTE

;PROCESS STOP OR SUBROUTINE STATEMENT
XS:     CP    53H           ; S ?
        JP    NZ,XT         ; NO
        INC   HL            ; STEP OVER S
        INC   HL            ; STEP OVER :
        LD    A,(HL)        ; PARAMETER TO REG A
        INC   HL            ; STEP OVER PARAMETER
;NEXT STMT MAY BE MADE TO BE A CALL TO USER SUBR
        JP    SUB           ; GO TO USER SUBR (OR TO EDITOR)
        JP    LOOP          ; GO ON UPON RETURN FROM USER SUBR

;PROCESS TYPE STATEMENT AND SYNTAX ERRORS
XT:     CP    54H           ; T ?
        JP    NZ,TE         ; NO, ITS AN ERROR
        INC   HL            ; YES, STEP OVER T
        INC   HL            ; STEP OVER :
TE:     CALL  PRT           ; PRINT UP TO CR
        JP    LOOP          ; DONE WITH T

;SUBR TO PRINT UP TO NEXT CR
PRT:    LD    C,40H         ; COUNT OF 64
PRTA:   LD    B,(HL)        ; NEXT CHAR
        DEC   C             ; DECREMENT SAFETY COUNTER
        JP    Z,PLF         ; EXIT IF OVER 64 BEFORE CR
        CALL  JOUT          ; PRINT IT
        LD    A,(HL)        ; RELOAD CHAR TO ACCA
        INC   HL            ; STEP LOC PTR
        CP    0DH           ; CR ?
        JP    NZ,PRTA       ; NOT CR, LOOP

;SUBROUTINE TO PRINT LINE FEED AND PAD
PLF:    LD    C,00H         ; NUMBER OF NULLS TO PRINT
PLFL:   LD    B,00H         ; NULL
        CALL  JOUT          ; WRITE A NULL
        DEC   C             ; DECREMENT COUNTER
        JP    P,PLFL        ; LOOP TILL ENOUGH NULLS
        LD    B,0AH         ; LINE FEED
        JP    JOUT          ; PRINT THEN RETURN

;ABOVE IS END OF READ ONLY PORTION OF THE PROGRAM
;
;THE FOLLOWING IS CHANGEABLE DATA
;
        ORG   0100H         ; MOVE TO START OF DATA AREA
LOC:    DW    PGM           ; + ADDR OF SOURCE PROGRAM AREA
LST:    DW    0000H         ; PLACE TO SAVE LOC OF LAST A:
;THE NEXT TWO BYTES ARE ONLY FOR 6800 COMPATIBILITY
CHR:    DB    00H           ; UNUSED, LAST INPUT CHAR IN EREG
FLG:    DB    00H           ; UNUSED, MATCH-FLAG IN DREG

;WORKBENCH TERMINAL ROUTINES (NOT IN THE ORIGINAL)
;PORT 00H = STATUS (BIT 0 SET IF A KEY IS WAITING)
;PORT 01H = DATA (IN READS A KEY, OUT PRINTS A CHAR)
KEYIN:  IN    A,(00H)       ; + READ TERMINAL STATUS
        AND   01H           ; + KEY WAITING ? Z IF NOT
        RET   Z             ; + NO, RETURN WITH Z SET
        IN    A,(01H)       ; + YES, READ IT (IN KEEPS NZ)
        RET                 ; + RETURN CHAR IN A
CHOUT:  LD    A,B           ; + CHAR TO PRINT IS IN B
        OUT   (01H),A       ; + SEND IT TO THE TERMINAL
        RET                 ; +

PGM     EQU   $             ; + SOURCE PROGRAM AREA STARTS HERE
        END
