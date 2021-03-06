; Copyright (C) 2016 Jerome Shidel
;
;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 2 of the License, or
;   (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License along
;   with this program; if not, write to the Free Software Foundation, Inc.,
;   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

; NASM for DOS

%include "COMMON.INC"

    DumpKeystrokes

    FrameBounds
    WhereXY
    mov         al, [TextAttr]
    mov         [FirstAttr], al
    or          al, 0x08
    mov         [SelectedAttr], al
    and         al, 0x77
    mov         [NotAttr], al
    mov         al, [TextAttr]
    not         al
    and         al, 0x7f
    mov         [HotAttr], al

    mov         [Position], dx
    mov         ax, [WindMin]
    mov         [OptionBox], ax
    mov         ax, [WindMax]
    mov         [OptionBox + 2], ax

    mov         di, CountChoice
    call        EachChoice

    CommandLineParser       ; insert code for command line parsing

    AllocTempVideoPage

    mov         al, [TextAttr]
    mov         [SelectedAttr], al
;   mov         ah, [HotAttr]
;   cmp         ah, 0x00
;   jne         KeyBoardLoop
;   mov         al, [TextAttr]
;   not         al
;   and         al, 0x7f
;   mov         [HotAttr], al

    jmp         KeyBoardLoop

ShowChoices:
;   mov         al, [SelectedAttr]
;   mov         ah, [HotAttr]
;   cmp         al, ah
;   jne         .MultiColor
;   mov         al, [HotChoice]
;   mov         [Selected], al
;.MultiColor:
    mov         di, SelectChoice
    call        EachChoice
    mov         bl, [Selected]
    mov         [LastSelected], bl
    mov         bl, [HotChoice]
    mov         [LastHot], bl
    ret

TimedOut:
    pop         es
    mov         al, [DefaultChoice]
    mov         [Selected], al
    jmp         Chosen

ShowTimeOut:
    push        cx
    push        bx
    push        dx

    xor         dx, dx
    mov         ax, 11
    xchg        ax, cx
    mul         cx
    mov         cx, 200
    div         cx

    mov         dx, [TimeOutMax]
    cmp         ax, dx
    jb          .Smaller
    mov         ax, dx
.Smaller:
    mov         dl, [TextAttr]
    push        dx
    mov         dl, [FirstAttr]
    mov         [TextAttr], dl
    mov         dx, [WindMax]
    push        dx
    mov         bx, [ScreenMax]
    cmp         bx, dx
    je          NoDisplayTimeOut
    mov         [WindMax], bx
    inc         dh
    sub         dl, 8

    push        ax
    mov         ah, 0x02
    mov         bh, [VideoPage]
    int         0x10
    mov         ah, 0x08
    int         0x10
    mov         bx, ax

    pop         ax
    push        ax
    mov         cx, 1
    cmp         ax, 1000
    jge         .SetWidth
    inc         cx
    cmp         ax, 100
    jge         .SetWidth
    inc         cx
    cmp         ax, 10
    jge         .SetWidth
    inc         cx
.SetWidth:
    mov         al, bl
    mov         bl, [VideoPage]
    xchg        bl, bh

    inc         dl
    mov         ah, 0x02
    int         0x10
    ; mov           bl, 0x4f
    mov         ah, 0x09
    int         0x10
    add         dl, cl
    mov         ah, 0x02
    int         0x10

    mov         al, 0x20
    WriteChar   0x09

    pop         ax
    WriteInt    ax
    mov         al, 0x20
    WriteChar   0x09
NoDisplayTimeOut:
    pop         dx
    mov         [WindMax], dx
    pop         dx
    mov         [TextAttr], dl
    pop         dx
    pop         bx
    pop         cx
    ret

KeyBoardLoop:
    call        ShowChoices
    mov         cx, [TimeOut]
    push        es
    mov         bx, 0x0040
    mov         es, bx
    mov         bx, 0x006c
    mov         dx, [es:bx]
.WaitLoop:
	IdleCPU
    mov         ax, [TimeOut]
    cmp         ax, 0
    je          .NoTimeOut
    cmp         cx, 0
    je          TimedOut
    mov         ax, [es:bx]
    cmp         ax, dx
    je          .NoTimeOut
    dec         cx
    mov         dx, ax
    call        ShowTimeOut
.NoTimeOut:
    mov         ax, 0x0100
    int         0x16
    jz          .WaitLoop
    pop         es

    mov         ax, 0x0000
    int         0x16
    push		ax
    mov			ah, [ControlC]
    cmp			ax, 0x0103
    pop			ax
    je			ControlCQuit

    ; up down to navigate
    cmp         ah, 0x48
    je          .GoUp
    cmp         ah, 0x50
    je          .GoDown
    ; Space or Enter to Choose
    cmp         al, 0x20
    je          Chosen
    cmp         al, 0x0d
    je          Chosen
    ; test selection type off
    mov         bl, [SelectChars]
    cmp         bl, 0
    je          .OtherKeypress
    ; adjust upper case
    cmp         al, 0x61
    jl          .NotLowercase
    cmp         al, 0x7a
    jg          .NotLowercase
    mov         bx, ax
    xor         bh, bh
    sub         bx, 0x20
    mov         al, bl
.NotLowercase:
    ; test selection type auto
    mov         bl, [SelectChars]
    cmp         bl, 1
    je          .AutoPress
    mov         bl, [SelectChars]
    cmp         bl, 4
    je          .YesNoPress
    ; letter, number or other
    cmp         al, 0x30
    jl          .OtherKeypress
    cmp         al, 0x39
    jle         .NumberPress
    cmp         al, 0x40
    jle         .OtherKeypress
    cmp         al, 0x5a
    jg          .OtherKeypress
    jmp         .AlphaPress
.OtherKeypress:
    ; StdOutHexWord
    jmp         KeyBoardLoop

.YesNoPress:
    jmp         KeyBoardLoop
.AutoPress:
    mov         [Searching], al
    mov         di, SearchChoice
    call        EachChoice
    jmp         .Changed
.AlphaPress:
    mov         bl, [SelectChars]
    cmp         bl, 2
    jne         .Changed
    sub         al, 0x40
    jmp         .DoKeySelect
.NumberPress:
    mov         bl, [SelectChars]
    cmp         bl, 3
    jne         .Changed
    sub         al, 0x30
    cmp         al, 0
    jne         .DoKeySelect
    mov         al, 0x0a
.DoKeySelect:
    mov         ah, [Max]
    cmp         al, ah
    jle         .OkKeySelect
    mov         al, ah
.OkKeySelect:
    mov         [Selected], al
;    jmp         .Changed

.Changed:
    ; When polling exit if changed
    mov         al, [Polling]
    cmp         al, 1
    je          FakeChosen

    jmp         KeyBoardLoop

.GoUp:
    mov         al, [Selected]
    cmp         al, 1
    jle         KeyBoardLoop
    dec         al
    mov         [Selected], al
    jmp         .Changed
.GoDown:
    mov         al, [Selected]
    mov         ah, [Max]
    cmp         al, ah
    jge         KeyBoardLoop
    inc         al
    mov         [Selected], al
    jmp         .Changed

.Select:
    mov         al, [HotChoice]
    mov         ah, [Selected]
    cmp         al, ah
    je          KeyBoardLoop
    mov         [Selected], al
    jmp         .Changed

Chosen:
    xor         al, al
    mov         [Polling], al
FakeChosen:
    xor         al, al
    mov         [HotChoice], al
    mov         al, [Selected]
    mov         ah, [Polling]
    push        ax
    cmp         ah, 1
    jne         .NotPolling
    xor         al, al
    mov         [Selected], al
    mov         di, SelectChoice
.NotPolling:
    call        EachChoice
    pop         ax
    mov         [Selected], al

Done:
    push        ax

    mov         dx, [Position]
    GotoXY      dx

    mov         al, [Querying]
    cmp         al, 0
    je          NoSTDOUT
    mov         di, StdOutChoice
    call        EachChoice
    StdOutCRLF

    mov         dx, [Position]
    GotoXY      dx

NoSTDOUT:

    FreeTempVideoPage
    pop         ax

    mov         ah, [Polling]
    cmp         ah, 0
    je          .NotPolling

    add         al, 100

.NotPolling:
	mov			bl, [PostalCode]
	cmp			bl, 0
	je			.NoPostal
	cmp			bl, al
	jne			.NoPostal
	GoPostal
.NoPostal:
    Terminate   al

ControlCQuit:
    FreeTempVideoPage
    mov			al, 200
    Terminate   al

EachChoice:
    mov         cl, [OptionBox + 3]
    mov         ch, [OptionBox + 1]
    sub         cl, ch
    inc         cl
    xor         ch, ch
    xor         dx, dx
    xor         bx, bx
.CountLoop:
    push        cx
    push        dx
.CheckLoop:
    push        bx
    GotoXY      dx
    mov         ah, 0x08
    mov         bh, [VideoPage]
    int         0x10
    pop         bx
    xor         ch, ch
    mov         cl, al
    cmp         cx, 0x21
    jl          .Missing
    cmp         cx, 0xad
    jg          .Missing
    inc         bx
    call        di
    jmp         .Found
.Missing:
    inc         dl
    mov         cl, [OptionBox + 2]
    mov         ch, [OptionBox + 0]
    sub         cl, ch
    cmp         dl, cl
    jle         .CheckLoop
.Found:
    pop         dx
    pop         cx
    inc         dh
    loop        .CountLoop
    ret

CopyFromTempVideoProc

CountChoice:
    mov         al, [Max]
    inc         al
    mov         [Max], al
    ret

SearchChoice:
    push        bx
    ; adjust upper case
    cmp         al, 0x61
    jl          .NotLowercase
    cmp         al, 0x7a
    jg          .NotLowercase
    mov         bx, ax
    xor         bh, bh
    sub         bx, 0x20
    mov         al, bl
.NotLowercase:
    pop         bx
    mov         ah, [Searching]
    cmp         al, ah
    jne         .Done
    mov         [Selected], bl
.Done:
    ret

SelectChoice:
    push        bx
    push        dx
    mov         cl, [OptionBox + 2]
    mov         ch, [OptionBox + 0]
    sub         cl, ch
    inc         cl
    xor         ch, ch

    mov         bh, [VideoPage]
    xor         dl, dl
    mov         al, [HotChoice]
    cmp         al, bl
    je          .IsHot
    mov         al, [Selected]
    cmp         al, bl
    jne         .NotThis
    mov         bl, [SelectedAttr]
    mov         ax, [TempVideoPagePtr]
    cmp         ax, 0
    je          .ChangeLoop
    xor         ah, ah
    mov         al, bl
    mov         bx, [WindMin]
    add         dl, bl
    add         dh, bh
    call        CopyFromTempVideo
    jmp         .Done
.IsHot:
    mov         bl, [HotAttr]
    mov         ax, [TempVideoPagePtr]
    cmp         ax, 0
    je          .ChangeLoop
    xor         ah, ah
    mov         al, bl
    mov         bx, [WindMin]
    add         dl, bl
    add         dh, bh
    call        CopyFromTempVideo
    jmp         .Done
.NotThis:
    push        ax
    mov         ax, [TempVideoPagePtr]
    cmp         ax, 0
    pop         ax
    je          .Restore
    mov         al, [LastHot]
    cmp         al, bl
    je          .Restore
    mov         al, [LastSelected]
    cmp         al, bl
    jne         .Done
.Restore:
    mov         bl, [NotAttr]
    mov         ax, [TempVideoPagePtr]
    cmp         ax, 0
    je          .ChangeLoop
    xor         ax, ax
    mov         bx, [WindMin]
    add         dl, bl
    add         dh, bh
    call        CopyFromTempVideo
    jmp         .Done
.ChangeLoop:
    push        cx
    push        bx
    GotoXY      dx
    pop         bx
    push        bx
    mov         ah, 0x08
    int         0x10
    pop         bx
    mov         ah, 0x09
    mov         cx, 0x0001
    int         0x10
    pop         cx
    inc         dl
    loop        .ChangeLoop
.Done:
    pop         dx
    pop         bx
    ret

StdOutChoice:
    mov         al, [Selected]
    cmp         bl, al
    jne         .NotThis
    push        bx
    push        dx
    mov         cl, [OptionBox + 2]
    mov         ch, [OptionBox + 0]
    sub         cl, ch
    inc         cl
    xor         ch, ch
    mov         bh, [VideoPage]
    xor         dl, dl
.OutLoop:
    push        cx
    push        dx
    push        bx
    GotoXY      dx
    pop         bx
    push        bx
    mov         ah, 0x08
    int         0x10
    mov         ah, 0x02
    mov         dl, al
    int         0x21
    pop         bx
    pop         dx
    pop         cx
    inc         dl
    loop        .OutLoop
    pop         dx
    pop         bx
.NotThis:
    ret

; Switches
    ColorSwitchHandlers

SwitchT:
    NumberParam
    mov         [TimeOutMax], ax
    cmp         ax, 0
    je          .SwitchOff
    cmp         ax, 3600
    jle         .SwitchOK
    mov         ax, 3600
.SwitchOK:
    inc         ax
    mov         cx, 200
    mul         cx
    mov         cx, 11
    div         cx
    inc         ax
.SwitchOff:
    mov         [TimeOut], ax
    ret

SwitchD:
    mov         al, [di]
    cmp         al, 0x61
    jl          .NotLower
    cmp         al, 0x7a
    jg          .NotLower
    sub         al, 0x20
.NotLower:
    cmp         al, 0x41
    jl          .NotUpper
    cmp         al, 0x5a
    jg          .NotUpper
    sub         al, 0x40
    jmp         .ValidateP
.NotUpper:
    NumberParam
.ValidateP:
    mov         ah, [Max]
    cmp         al, ah
    jle         .Done
    mov         al, ah
.Done:
    mov         [Selected], al
    mov         [DefaultChoice], al
    ret

SwitchQ:
    mov         al, 1
    mov         [Querying], al
    ret
SwitchP:
    mov         al, [di]
    cmp         al, 0x61
    jl          .NotLower
    cmp         al, 0x7a
    jg          .NotLower
    sub         al, 0x20
.NotLower:
    cmp         al, 0x41
    jl          .NotUpper
    cmp         al, 0x5a
    jg          .NotUpper
    sub         al, 0x40
    jmp         ValidateD
.NotUpper:
    NumberParam
ValidateD:
    mov         ah, [Max]
    cmp         al, ah
    jle         .Done
    mov         al, ah
.Done:
    mov         [Selected], al
    mov         al, 1
    mov         [Polling], al
    ret

OptNone:
    mov         al, 0
    mov         [SelectChars], al
    ret
OptAuto:
    mov         al, 1
    mov         [SelectChars], al
    ret
OptAlpha:
    mov         al, 2
    mov         [SelectChars], al
    ret
OptNumber:
    mov         al, 3
    mov         [SelectChars], al
    ret
OptYesNo:
    mov         al, 4
    mov         [SelectChars], al
    ret

OptCtrlC:
    mov         al, 1
    mov         [ControlC], al
    ret

OptPostal:
    mov         al, 1
    mov         [Postal], al
    ret

NoSwitch:
    LookupParam StyleTable
    cmp         ax, 0xffff
    je          .CheckPostal
    jmp         ax
.CheckPostal:
	mov			bl, [Postal]
	cmp			bl, 0
	je			.Error
    NumberParam
	mov			[PostalCode], al
	xor			al, al
	mov			[Postal], al
	ret

.Error:
    WriteStr    CommandLineErrorMsg
    Terminate   100

    HelpSwitchHandler

CommandLineSwitches:
    SwitchData  0,  0, NoSwitch
    SwitchData  'S',  1, SwitchD
    SwitchData  'D',  1, SwitchD
    SwitchData  'T',  1, SwitchT
    SwitchData  'Q',  0, SwitchQ
    SwitchData  'P',  1, SwitchP
    ColorSwitchData
    HelpSwitchData
    SwitchData  0,  0, 0

StyleTable:
    TableData 'NONE', OptNone
    TableData 'OFF', OptNone
    TableData 'AUTO', OptAuto
    TableData 'FIRST', OptAuto
    TableData 'ALPHA', OptAlpha
    TableData 'LETTER', OptAlpha
    TableData 'NUMBER', OptNumber
    TableData 'DIGIT', OptNumber
    TableData 'YN', OptYesNo
    TableData 'YES', OptYesNo
    TableData 'YESNO', OptYesNo
    TableData 'CTRL-C', OptCtrlC
    TableData 'CTRL+C', OptCtrlC
    TableData 'POSTAL', OptPostal
    TableEnd

Querying:       db 0
Polling:        db 0
ControlC:       db 0
TimeOut:        dw 0
TimeOutMax:     dw 0
SelectChars:    db 1
Max:		    db 0
DefaultChoice:  db 0
Selected: 		db 1
LastSelected:	db 0
HotChoice:		db 0
LastHot:		db 0
SelectedAttr:	db 0
FirstAttr:		db 0
HotAttr:		db 0
NotAttr:		db 0
Position:		dw 0
OptionBox:		dw 0,0
Searching:		db 0
Postal:			db 0
PostalCode:		db 0