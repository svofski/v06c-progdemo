;AY emulator on VI53 v0.2
;Компилировать в TASM - A Table Driven Cross Assembler for the MSDOS* Environment (tasm 3.01 или 3.2)
;ПО "Счетмаш" 1988-1990
;Вячеслав Славинский 2022
;Иван Городецкий 04.05.2009, 06.09.2022

TrshVol	.equ 3

WRTPSG:
;		mov	a,c	;только для RMPPlayer!!!
;		push	psw
		push	h
		push	d
;		mov	e,m	;только для RMPPlayer!!!
;		mov	m,b	;только для RMPPlayer!!!
		lxi	h, AYmainJmpTable

;A - номер регистра
;E - записываемое в регистр значение
WRTPSG_dispatch:
		ani	0Fh
		add	a
		call add_hl_a
		mov a,m
		inx	h
		mov	h,m
		mov	l,a
		mov a,e
		pchl
; End of function WRTPSG

; ---------------------------------------------------------------------------
AYmainJmpTable:
			.dw AY00,AY01,AY02,AY03
			.dw AY04,AY05,AY1415,AY07
			.dw AY08,AY09,AY10,AY1415
			.dw AY12,AY13,AY1415,AY1415
; ---------------------------------------------------------------------------
;нижние	8 бит частоты канала A
AY00:
		sta	AY_R0
		call SetFreqTimerCh0
		jmp	AY1415
; ---------------------------------------------------------------------------
;верхние 4 бита	частоты	канала A
AY01:
		sta	AY_R1
		call SetFreqTimerCh0
		jmp	AY1415

;Задаем	частоту	для канала 0 таймера
; =============== S U B	R O U T	I N E =======================================
SetFreqTimerCh0:
		lda AY_R8
		cpi TrshVol
		jc MuteCh0
		lda AY_R7
		ani 001b
		jnz MuteCh0

AY_R0	.equ $+1
AY_R1	.equ $+2
		lxi	h,0
		call FreqAY_to_VI53
		out	0Bh
		mov	a,h
		out	0Bh
		ret
MuteCh0:
		mvi	a,36h		; выключаем канал 0 таймера
		out	8
		ret
; End of function SetFreqTimerCh0

;Преобразуем частоту для AY в частоту для ВИ53
; =============== S U B	R O U T	I N E =======================================
FreqAY_to_VI53:
		mvi	a,00001111b
		ana	h
		mov	h,a
		mov	d,h
		mov	e,l
		dad	h
		dad	h
		dad	d
		dad d
		dad	h	;*12
		dad	d	;*13
		mov a,d
;CY=0
		rar
		mov	d,a
		mov	a,e
		rar
		mov	e,a
		dad	d	;*13.5
		mov a,l
		ret
; End of function FreqAY_to_VI53

; ---------------------------------------------------------------------------
;нижние	8 бит частоты канала B
AY02:
		sta	AY_R2
		call SetFreqTimerCh1
		jmp	AY1415
; ---------------------------------------------------------------------------
;верхние 4 бита	частоты	канала B
AY03:
		sta	AY_R3
		call SetFreqTimerCh1
		jmp	AY1415

; =============== S U B	R O U T	I N E =======================================

SetFreqTimerCh1:
		lda AY_R9
		cpi TrshVol
		jc MuteCh1
		lda AY_R7
		ani 010b
		jnz MuteCh1

AY_R2	.equ $+1
AY_R3	.equ $+2
		lxi	h,0
		call FreqAY_to_VI53
		out	0Ah
		mov	a,h
		out	0Ah
		ret
MuteCh1:
		mvi	a,76h		; выключаем канал 0 таймера
		out	8
		ret

; ---------------------------------------------------------------------------
;нижние	8 бит частоты канала C
AY04:
		sta	AY_R4
		call SetFreqTimerCh2
		jmp	AY1415
; ---------------------------------------------------------------------------
;верхние 4 бита	частоты	канала C
AY05:
		sta	AY_R5
		call SetFreqTimerCh2
		jmp	AY1415

;Задаем	частоту	для канала 2 таймера
; =============== S U B	R O U T	I N E =======================================


SetFreqTimerCh2:
		lda AY_R10
		cpi TrshVol
		jc MuteCh2
		lda AY_R7
		ani 100b
		jnz MuteCh2

AY_R4	.equ $+1
AY_R5	.equ $+2
		lxi	h,0
		call FreqAY_to_VI53
		out	9
		mov	a,h
		out	9
		ret
MuteCh2:
		mvi	a,0B6h		; выключаем канал 0 таймера
		out	8
		ret
; End of function SetFreqTimerCh2


; ---------------------------------------------------------------------------
;Верхние 8 бит управления периодом огибающей
AY12:
		sta	AY_R12
		jmp	AY1415
; ---------------------------------------------------------------------------
;Выбор формы огибающей
AY13:
		ani 00001111b
		sta	AY_R13
		jmp	AY1415
; ---------------------------------------------------------------------------
;Микшер
AY07:
		call	AY07sub
;Регистры портов ввода/вывода
AY1415:
		pop	d
		pop	h
;		pop	psw
;		jmp	0A18Ah	;только для RMPPlayer!!!
subAY07_000:
		ret

; =============== S U B	R O U T	I N E =======================================
AY07sub:
		ani 111b
		mov e,a
		lda	AY_R7
		mov d,a
		mov a,e
		sta AY_R7
		xra	d		; смотрим, какие каналы	изменились
		lxi	h, AY07JmpTab
		ani	111b
		jmp	WRTPSG_dispatch
; ---------------------------------------------------------------------------
AY07JmpTab:
		.dw subAY07_000,SetFreqTimerCh0,SetFreqTimerCh1,subAY07_011
		.dw SetFreqTimerCh2,subAY07_101,subAY07_110,subAY07_111

; ---------------------------------------------------------------------------
subAY07_011:
		call SetFreqTimerCh0
		jmp	SetFreqTimerCh1
; ---------------------------------------------------------------------------

subAY07_101:
		call SetFreqTimerCh0
		jmp	SetFreqTimerCh2
; ---------------------------------------------------------------------------

subAY07_110:
		call SetFreqTimerCh1
		jmp	SetFreqTimerCh2
; ---------------------------------------------------------------------------

subAY07_111:
		call SetFreqTimerCh0
		jmp	subAY07_110
; ---------------------------------------------------------------------------

;Громкость канала A
AY08:
		sta	AY_R8
		ani	10000b	; проверка установки огибающей для канала A
		jnz	Envelope	; переход на обработку огибающей
		call SetFreqTimerCh0
		jmp	AY1415
; ---------------------------------------------------------------------------

Envelope:
		lda	AY_R12
		rrc
		rrc
		rrc
		ani	11110b		; сдвинули и выделили старшие 4	бита периода огибающей
		inr	a
		sta	EnvPeriod
		sta	EnvPeriodCount
		call	SetFreqTimerCh0
		jmp	AY1415

;Звуковая процедура, вызываемая по прерываниям
; =============== S U B	R O U T	I N E =======================================
SoundProcInt:
;проверяем тип огибающей
		lda	AY_R13
		ani	00001111b
		lxi	h,Env
		call	add_hl_a
		mov	a,m
		ora	a
		rnz
		lda	EnvPeriod
		ora	a
		rz
		lxi	h, EnvPeriodCount
		dcr	m
		rnz
		xra	a
		sta	EnvPeriod	; обнуляем период огибающей
		lda	AY_R8
		ani 10000b
		jz	EnvCh1
		mvi	a, 36h	;гасим канал 0
		out	8
EnvCh1:
		lda	AY_R9
		ani 10000b
		jz	EnvCh2
		mvi	a, 76h	;гасим канал 1
		out	8
EnvCh2:
		lda	AY_R10
		ani 10000b
		rz
		mvi	a, 0B6h	;гасим канал 2
		out	8
		ret


;табличка, в которой "конечным" огибающим соответствует 0
Env:
		.db 0,0,0,0
		.db 0,0,0,0
		.db 1,0,1,1
		.db 1,1,1,0

; End of function SoundProcInt

; ---------------------------------------------------------------------------
;Громкость канала B
AY09:
		sta	AY_R9
		ani	10000b
		jnz	Envelope
		call SetFreqTimerCh1
		jmp	AY1415
; ---------------------------------------------------------------------------
;Громкость канала C
AY10:
		sta	AY_R10
		ani	10000b
		jnz	Envelope
		call SetFreqTimerCh2
		jmp	AY1415
; ---------------------------------------------------------------------------
AY_R6:		.db 1
AY_R7:		.db 0FFh
AY_R8:		.db 0
AY_R9:		.db 0
AY_R10:		.db 0
AY_R12:		.db 1
AY_R13:		.db 0
EnvPeriod:		.db 0
EnvPeriodCount:	.db 0

; =============== S U B	R O U T	I N E =======================================
add_hl_a:
		add	l
		mov	l, a
		rnc
		inr	h
		ret
; End of function add_hl_a


		.end
