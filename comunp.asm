; Universal COM-files unpacker  v1.0
; Copyright (C)1995 by FRIENDS Software
; Written by Maxim Masiutin
; Example of using 386 Debug Registers
; Works under Pure DOS only  
; Rename any file you wish to unpack 
; to RABBIT.EXE, copy it in the same
; directory with COMUNP.COM and run
; COMUNP.COM

        ideal
        p386
        jumps

macro   Msg     Ofs
        mov     dx,offset Ofs
        mov     ah,9
        int     21h
        endm

StSize  equ     1000h

                   ;3333222211110000|.....EE33221100
                   ;LNRWLNRWLNRWLNRW|.....GLGLGLGLGL
dr7val  equ         00000000000000000000001100000011b


segment CODE    use16
        assume  cs:CODE,ds:CODE
        org     100h

Start:
     ; Write some useless info ----------------------------
        Msg     PrgTitle

     ; Check CPU by toggling Nested Task (NT) flag --------
        pushf
        pop     ax
        xor     ax,4000h
        push    ax
        popf
        pushf
        pop     bx
        xor     ax,4000h
        push    ax
        popf
        pushf
        pop     ax
        cmp     ax,bx
        jne     CPU386

     ; Write message that CPU is not a 386 ----------------
        mov     dx,offset Req386CPU
WriteExit:
        mov     ah,9
        int     21h
        ret

CPU386:

     ; Check the presence of 'RABBIT.EXE' file ------------
        mov     dx,offset FName
        mov     ax,3D00h
        int     21h
        jnc     FileExist
        mov     [FNameTerm],'$'
        Msg     FName
        mov     dx,offset NotFound
        jmp     WriteExit

FileExist:
        mov     bx,ax
        mov     ah,3Eh ; Close file
        int     21h

     ; Prepare stack --------------------------------------
        mov     bx,offset StackArea
        mov     sp,bx
        shr     bx,4
        inc     bx
        mov     ah,4Ah
        int     21h

     ; Create temporary file ------------------------------
        mov     ax,3C00h
        mov     cx,20h          ; Archive Flag
        mov     dx,offset TMPName
        int     21h
        mov     bx,ax
        mov     ah,40h
        mov     cx,offset TmpCE-offset TmpCOM
        mov     dx,offset TmpCOM
        int     21h
        mov     ah,3Eh
        int     21h

     ; Execute temporary file -----------------------------
        mov     dx,offset TMPName
        call    Exec

     ; Erase temporary file -------------------------------
        mov     ah,41h
        int     21h

     ; Set INT1 vector ------------------------------------
        mov     ax,2501h
        mov     dx,offset INT1
        int     21h

     ; Get initial segment --------------------------------
        push    es
        mov     ax,35CAh
        int     21h
        mov     ax,es
        pop     es
        mov     [InCS],ax

     ; Set in EAX linear addr of COM-file start -----------
        add     ax,16
        movzx   eax,ax
        shl     eax,4

     ; Set linear addr of The Breakpoint ------------------
        mov     dr0,eax

     ; Clear DR6 ------------------------------------------
        xor     eax,eax
        mov     dr6,eax

     ; Break on command execution -------------------------
        mov     eax,dr7val
        mov     dr7,eax

     ; Execute crypted file
        mov     dx,offset FName
        call    Exec

     ; Clear The Breakpoint -------------------------------
        xor     eax,eax
        mov     dr7,eax

     ; Write statistics -----------------------------------
        mov     [Dot],'$'
        Msg     CrLf
        Msg     CrackNoHi
        Msg     DumpsFlushed
     ; Exit program ---------------------------------------
        int     20h

     ; Execute file (DX=fname) ----------------------------
Exec:   pushad
        xor     eax,eax
        mov     bx,offset ExecParBlock ; Prepare Exec Parameter Block
        mov     [dword ptr bx],800000h
        mov     [bx+4],cs
        mov     [bx+6],eax
        mov     [bx+0Ah],eax
        mov     [OldSP],sp             ; Save stack pointer
        mov     ax,4B00h               ; DOS Execute command
        int     21h
        cli
        mov     ax,cs
        mov     ds,ax
        mov     es,ax
        mov     sp,0CAFEh              ; Restore stack
        org     $-2
OldSP   dw      0CAFEh
        mov     ss,ax
        sti
        popad
        ret

     ; Set RF (AMD do not set it automatically???) --------
PopAxSetRF:
        pop     ax
SetRF:  popf
        pushfd
        or      [byte ptr ss:esp+2],1
        push    large 12345678h
        org     $-4
IntCS   dw      ?,0
        push    large 12345678h
        org     $-4
IntIP   dw      ?,0
        iretd

ToIRET:
        iret

     ; The Breakpoint entry -------------------------------
INT1:
        push    eax ebx
        mov     ebx,dr6
        xor     eax,eax
        mov     dr6,eax
                  ;TSD.........3210
        and     bx,0100000000000001b
        cmp     bx,1
        pop     ebx eax
        jnz     ToIRET

        pop     [cs:IntIP]
        pop     [cs:IntCS]

        cmp     [cs:IntCS],1234h
        org     $-2
InCS    dw      ?
        jne     SetRF
        cmp     [cs:IntIP],100h
        jne     SetRF
        push    ax
        mov     ax,ds
        cmp     ax,[cs:IntCS]
        jne     PopAxSetRF
        mov     ax,es
        cmp     ax,[cs:IntCS]
        pop     ax
        jne     SetRF

     ; Save memory image to file --------------------------
SaveImage:
        pushad
        push    ds
        push    cs
        pop     ds
        xor     eax,eax
        mov     dr7,eax
        mov     ax,3C00h
        mov     cx,20h          ; Archive Flag
        mov     dx,offset GRABNm
        int     21h
        mov     bx,ax
        mov     al,[CrackNoLo]    ; Inc CrackNo
        mov     ah,[CrackNoHi]
        call    IncCrackNo
        mov     [CrackNoHi],ah
        mov     [CrackNoLo],al
        mov     ah,40h
        mov     cx,0F000h
        mov     dx,100h
        mov     ds,[InCS]
        int     21h
        mov     ah,3Eh
        int     21h
        mov     eax,dr7val
        mov     dr7,eax
        pop     ds
        popad
        jmp     SetRF

     ; Prepare a name for the next file -------------------
IncCrackNo:
        cmp     al,'9'
        jnz     NotCutLo9
        mov     al,'A'
        ret
NotCutLo9:
        cmp     al,'Z'
        jnz     NotCutLoZ
        mov     al,'0'
        cmp     ah,'Z'
        jnz     NotCutHiZ
        mov     ah,'0'
        ret
NotCutHiZ:
        cmp     ah,'9'
        jnz     NotCutHi9
        mov     ah,'A'
        ret
NotCutHi9:
        inc     ah
        ret
NotCutLoZ:
        inc     al
        ret

     ; Temporary COM-file to get child CS -----------------
TmpCOM: mov     ax,25CAh
        int     21h
        ret
TmpCE: ; End of the file ----------------------------------

GrabNm          db      'CRACK#'
CrackNoHi       db      '0'
CrackNoLo       db      '0'
Dot             db      '.'
                db      'COM',0
FName           db      'RABBIT.EXE'
FNameTerm       db      0
TMPName         db      '$CRACK$.TMP',0
PrgTitle        db      'Universal COM-files unpacker  v1.0  Copyright (C) 1995 by FRIENDS Software'
CrLf            db      13,10,10,'$'
NotFound        db      ' not found',13,10,'$'
DumpsFlushed    db      ' dump(s) flushed',13,10,'$'
Req386CPU       db      'Sorry, DR0 register is absent in your CPU',13,10,'$'
ExecParBlock:   org     $+16
                org     $+StSize
StackArea:

ends    CODE
        end  Start