ORG 0000H
    LJMP MAIN

ORG 0003H ; INT0_ISR for P3.2
    LJMP INT0_ISR

ORG 0013H ; INT1_ISR for P3.3
 LJMP INT1_ISR


ORG 001BH ; Timer1 ISR Vector Address
TIMER1_ISR:
    INC R1 ; Increment overflow counter
    CJNE R1, #20, SKIP_FLAG ; Check if 20 overflows occurred (50ms * 20 = 1s)
    MOV R1,#0 ; Reset counter
    SETB 30H ; Set flag for 1s delay completion

SKIP_FLAG:
    MOV TH1, #4CH ; Reload Timer1 for 50ms delay
    MOV TL1, #000H
    CLR TF1 ; Clear Timer1 overflow flag
    RETI ; Return from interrupt


ORG 0030H
MAIN:
    MOV SP, #60H ; Stack pointer init
    MOV 30H, #00H ; Initial state = 0
 ;MOV R7, #01H ; Reset flag

    ; Enable interrupts using direct register access
    MOV IE, #10001101B ; EA=1, EX1=1, EX0=1, ET1=1
    SETB IT0
    SETB IT1
 MOV TMOD, #10H ; Timer1 in Mode 1 (16-bit)
    MOV TH1, #4CH ; Load Timer1 for 50ms delay
    MOV TL1, #000H
    SETB TR1  
    ; LCD Initialization
    MOV DPTR, #MYCOM

INIT_LCD:
    CLR A
    MOVC A, @A+DPTR
    ACALL COMNWRT
    ACALL DELAY
    INC DPTR
    JZ MAIN_LOOP
    SJMP INIT_LCD

MAIN_LOOP:
    ; Display 'ST' once at C0 and C1
    ACALL PRINT_ST  

LOOP_AGAIN:
    MOV A, 30H ; Load current state

    CJNE A, #00H, CHECK_STATE_1
    ACALL STATE_RESET
    SJMP LOOP_AGAIN

CHECK_STATE_1:
    CJNE A, #01H, CHECK_STATE_2
    ACALL STATE_RUNNING
    SJMP LOOP_AGAIN

CHECK_STATE_2:
    CJNE A, #02H, CHECK_STATE_3
    ACALL STATE_PAUSED
    SJMP LOOP_AGAIN

CHECK_STATE_3:
    CJNE A, #03H, LOOP_AGAIN
    ACALL STATE_LAP
    SJMP LOOP_AGAIN


INT0_ISR:
    ACALL DEBOUNCE_DELAY
    MOV A, 30H
    MOV R2, A ; Store previous state before changing

    CJNE A, #00H, STATE_1_OR_2_OR_3
    MOV 30H, #01H ; From 0 -> 1
    RETI

STATE_1_OR_2_OR_3:
    CJNE A, #01H, CHECK_2
    MOV 30H, #02H ; From 1 -> 2
    RETI

CHECK_2:
    CJNE A, #02H, CHECK_3
    MOV 30H, #01H ; From 2 -> 1
    RETI

CHECK_3:
    CJNE A, #03H, RET_FROM_ISR
    MOV 30H, #01H ; From 3 -> 1
    MOV R2, #01H ; Set flag for clearing LAP once
    RETI


RET_FROM_ISR:
    RETI

;--int1 isr---

INT1_ISR:
ACALL DEBOUNCE_DELAY
    MOV A, 30H
    CJNE A, #01H, CHECK_IF_3 ; Check if state is 1
    MOV 30H, #03H ; From 1 -> 3 (LAP)
    RETI

CHECK_IF_3:
    CJNE A, #03H, CHECK_IF_2 ; Check if state is 3
    MOV 30H, #01H ; From 3 -> 1 (RUNNING)
   
    RETI

CHECK_IF_2:
    CJNE A, #02H, RET_FROM_INT1 ; Check if state is 2
    MOV 30H, #00H ; From 2 -> 0 (RESET)
    MOV R5, #00H
    MOV R6, #00H
    ;MOV R7, #01H
    RETI

RET_FROM_INT1:
    RETI
;----states

STATE_RESET:
    ; Display 00:00
    MOV A, #80H
    ACALL COMNWRT
    MOV A, #'0'
    ACALL DATAWRT
    MOV A, #'0'
    ACALL DATAWRT
    MOV A, #':'
    ACALL DATAWRT
    MOV A, #'0'
    ACALL DATAWRT
    MOV A, #'0'
    ACALL DATAWRT

    ; Reset time registers
    MOV R5, #00H
    MOV R6, #00H

    ; Enter Idle Mode
    ORL PCON, #01H  ; Enable IDL mode

    NOP
    NOP
    NOP  ; Stabilization after waking up

    RET


STATE_RUNNING:
    JNB 30H, SKIP_TIME_UPDATE ; Wait for 1-second flag
    CLR 30H ; Clear 1s flag
    INC R6
    CJNE R6, #60, SKIP_MIN_INC
    MOV R6, #00H
    INC R5
SKIP_MIN_INC:
    ACALL DISPLAY_TIME

    ; Clear LAP once when returning from LAP state
    DJNZ R2, CLEAR_LAP  
SKIP_TIME_UPDATE:
    RET

CLEAR_LAP:
    MOV A, #08DH
    ACALL COMNWRT
    MOV A, #' ' ; Overwrite 'L'
    ACALL DATAWRT
    MOV A, #' ' ; Overwrite 'A'
    ACALL DATAWRT
    MOV A, #' ' ; Overwrite 'P'
    ACALL DATAWRT
    RET
STATE_PAUSED:
    ACALL DISPLAY_TIME  ; Show frozen time

    ; Enter Idle Mode
    ORL PCON, #01H  ; Enable IDL mode

    NOP
    NOP
    NOP  ; Stabilization after waking up

    RET


STATE_LAP:
 JNB 30H, SKIPTIMEUPDATE ; Wait for 1-second flag
    CLR 30H ; Clear 1s flag
    INC R6
    CJNE R6, #60, SKIPMININC
    MOV R6, #00H
    INC R5
 SKIPMININC: ACALL PRINT_LAP  
SKIPTIMEUPDATE:
RET


DISPLAY_TIME:
    MOV A, #80H
    ACALL COMNWRT
    ; Tens of R5
    MOV A, R5
    MOV B, #10
    DIV AB
    ADD A, #'0'
    ACALL DATAWRT
    ; Ones of R5
    MOV A, B
    ADD A, #'0'
    ACALL DATAWRT
    MOV A, #':'
    ACALL DATAWRT
    ; Tens of R6
    MOV A, R6
    MOV B, #10
    DIV AB
    ADD A, #'0'
    ACALL DATAWRT
    ; Ones of R6
    MOV A, B
    ADD A, #'0'
    ACALL DATAWRT
    RET

PRINT_ST:
    MOV A, #0C0H
    ACALL COMNWRT
    MOV A, #'S'
    ACALL DATAWRT
    MOV A, #'T'
    ACALL DATAWRT
    RET


PRINT_LAP:
    MOV A, #08DH
    ACALL COMNWRT
    MOV A, #'L'
    ACALL DATAWRT
    MOV A, #'A'
    ACALL DATAWRT
  MOV A, #'P'
    ACALL DATAWRT
    RET
; ---- LCD Command ----
COMNWRT:
    MOV P1, A
    CLR P2.1
    CLR P2.0
    SETB P2.2
    ACALL DELAY
    CLR P2.2
    RET

; ---- LCD Data ----
DATAWRT:
    MOV P1, A
    SETB P2.1
    CLR P2.0
    SETB P2.2
    ACALL DELAY
    CLR P2.2
    RET

; ---- Delay ----
DELAY:
    MOV R3, #250
HERE2:
    MOV R4, #255
HERE:
    DJNZ R4, HERE
    DJNZ R3, HERE2
    RET

;--debounce delay
DEBOUNCE_DELAY:
    MOV R3, #3
DEBOUNCE_LOOP1:
    MOV R4, #200
DEBOUNCE_LOOP2:
    DJNZ R4, DEBOUNCE_LOOP2
    DJNZ R3, DEBOUNCE_LOOP1
    RET

; ==== LCD Init Commands ====
ORG 300H
MYCOM: DB 38H, 0EH, 01H, 06H, 0

END