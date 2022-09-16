; progressive picture display demo for unexpanded vector-06c
; 
; svofski ivagor 2022
;
; features 
;          streaming dzx0 decompressor
;          gigachad16 player
;          ayvi53 emulator


; unroll single-pixel setpixel for slight speedup
#define UNROLL_SETPIXEL1

                .tape v06c-rom
                .project grad.rom
		.org $100
		di
		xra	a
		out	10h
		lxi	sp,$100
		mvi	a,0C3h
		sta	0
		lxi	h,Restart
		shld	1

                mvi a, $c9
                sta $38

		call	Cls

Restart:
		lxi sp,$100
                xra a
                sta int_colorset_f    ; don't set palette
                sta restart_stream_f  ; don't restart stream
		call Cls
                call install_gigachad ; init and install gigachad16 music player
                call stream_dzx0_exit ; reset streaming dzx0
                
                ; restart from the beginning of the picture stream
stream_again:
                call picstream_init   ; init picture zx0 stream

                ; show next picture from the stream
picture_again:  ; it starts with 16 palette bytes
                di
                mvi a, $ff
                sta int_colorset_f    ; colorset_f = true
                mov h, b
                mov l, c
                shld picstream_bc     ; save bc
                ei                    ; interrupt will call colorset
                hlt                   ; and set palette from the stream
                lhld picstream_bc     ; restore bc (updated by interrupt)
                mov b, h
                mov c, l

                ;
                ; progressive refinement
                ;

                ; first refinement: 8x8 tile size (32x32 tiles)
                lxi d, $80ff  ; $8000 top row
                
                ; setpixel sets 8x8 pixels
                call setpixel_set8
t8_L1
                call picstream_getbyte
                lxi h, pseq_yx        ; &pseq_yx[0] start of prog sequence
                push b
                call setpixel
                inr d
                lxi h, pseq_yx
                call setpixel
                pop b
                inr d                 ; column++
                mvi a, $a0            ; column == 0xa0?
                cmp d
                jnz t8_L1             ; no, continue
                mvi d, $80            ; reset column to 0
                mvi a, -8             ; advance 8 pixels down
                add e                 
                jnc t8_done           ; do the next line
                mov e, a
                jmp t8_L1
t8_done:

                ; setpixel sets 4x4 pixels
                call setpixel_set4

                lxi d, $80ff
t4_L1:
                call picstream_getbyte
                lxi h, pseq_yx + 1*2  ; &pseq_yx[1] 4x4 prog sequence (3/tile)
                push b
                call setpixel     ; 1
                call setpixel     ; 2
                pop b
                call picstream_getbyte
                push b
                call setpixel     ; 3
                inr d
                lxi h, pseq_yx + 1*2
                call setpixel     ; 1
                pop b
                call picstream_getbyte
                push b
                call setpixel     ; 2
                call setpixel     ; 3
                pop b

                inr d
                mvi a, $a0
                cmp d
                jnz t4_L1
                mvi d, $80
                mvi a, -8
                add e
                jnc t4_done
                mov e, a
                jmp t4_L1

t4_done:

                ; setpixel sets 2x2 pixels
                call setpixel_set2
                
                lxi d, $80ff
t2_L0:
                lxi h, pseq_yx + 4*2  ; &pseq_yx[4] 2x2 prog sequence (12/tile)
                mvi a, 12
t2_L1:
                push psw
                call picstream_getbyte
                push b
                call setpixel
                call setpixel
                pop b
                pop psw
                sui 2
                jnz t2_L1

                inr d
                mvi a, $a0
                cmp d
                jnz t2_L0
                mvi d, $80
                mvi a, -8
                add e
                jnc tile2_done
                mov e, a
                jmp t2_L0

tile2_done:

                ; final refinement, 49152 single pixels
#ifndef UNROLL_SETPIXEL1
                call setpixel_set1
#endif

                lxi d, $80ff
tile1_L0:
                lxi h, pseq_yx + 16*2 ; &pseq_yx[16] 1x1 prog sequence (48/tile)
                mvi a, 48
tile1_L1:
                push psw

                ;call picstream_getbyte  
                ldax b                ; inline getbyte + fetch
                inr c
                cz picstream_fetch
                ;--

                push b
#ifdef UNROLL_SETPIXEL1
                call setpixel1   ; set pixel in high nybble of A
                call setpixel1   ; low nybble
#else
                call setpixel
                call setpixel
#endif
                pop b

                ;call picstream_getbyte
                ldax b                ; inline getbyte + fetch
                inr c
                cz picstream_fetch
                ;--

                push b
#ifdef UNROLL_SETPIXEL1
                call setpixel1   ; set pixel in high nybble of A
                call setpixel1   ; low nybble
#else
                call setpixel
                call setpixel
#endif
                pop b
                pop psw
                sui 4
                jnz tile1_L1

                ; next column
                inr d
                mvi a, $a0
                cmp d
                jnz tile1_L0

                ; next bitplane
                mvi d, $80
                mvi a, -8
                add e
                jnc tile1_done
                mov e, a
                jmp tile1_L0
tile1_done
                ; picture finished

                ; wait 1 sec before moving on to the next picture
                mvi a, 50
picture_hold:
                ei
                hlt
                dcr a
                jnz picture_hold

restart_stream_f equ $+1  
                mvi a, 0              ; stream end flag set by picstream_fetch
                ora a
		jz picture_again
                xra a
                sta restart_stream_f
                jmp stream_again


                ; de = tile addr
                ; hl = ptr to yx offsets in current tile 
                ; a = XXXXYYYY  ; XXXX =color pixel to set
                ; returns a = YYYY____  (next pixel in high nybble of A)
setpixel:       
                push d
                ;push b       ; stream buffer ptr caller-saved
                mov b, a      ; b = saved a, c free 

                mov a, e
                sub m
                mov e, a      ; update pixel addr 

                inx h         ; hl -> pixel mask
                mov c, m      ; c = set mask
                inx h         ; hl -> next in tile sequence
                push h        ; save hl
                mov h, b      ; h = pixel bits XXXXYYYY
                
                mov a, c
                cma
                mov b, a      ; b = clear mask

setpixel_L1
                ldax d        ; screen $8000
                ana b
                dad h
                jnc $+4
                ora c
                ;  __ patch area: see setpixel_set1, _set2, _set4, _set8
                ; /
setpixel_stax:  nop
                call 0
                ; \__ patch area

                mvi a, $20 \ add d \ mov d, a ; screen $a000, etc..
                jnc setpixel_L1

                mov a, h      ; next pixel in A high nybble

                pop h
                pop d
                ret

                ; switch setpixel to 8x8
setpixel_set8:
                lxi h, $cd00          ; nop \ call ...
                shld setpixel_stax    ; ... stax8
                lxi h, stax8
                shld setpixel_stax+2
                ret

                ; switch setpixel to 4x4
setpixel_set4:
                lxi h, $cd00          ; nop \ call ...
                shld setpixel_stax
                lxi h, stax4          ; ... stax4
                shld setpixel_stax+2
                ret

                ; switch setpixel to 2x2
setpixel_set2:
                lxi h, $1d12
                shld setpixel_stax    ; stax d \ dcr e
                lxi h, $1c12          ; stax d \ inr e
                shld setpixel_stax+2
                ret

#ifndef UNROLL_SETPIXEL1
setpixel_set1:  lxi h, $1200          ; nop \ stax d
                shld setpixel_stax
                lxi h, 0
                shld setpixel_stax+2
                ret
#endif

stax8:
                mov l, e
                stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e
                stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e \ stax d
                mov e, l
                ret

stax4:
                mov l, e
                stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e \ stax d
                mov e, l
                ret


                ; unrolled version of setpixel for 1-pixel setpixels
                ; de = tile addr
                ; hl = ptr to yx offsets in current tile 
                ; a = XXXXYYYY  ; XXXX =color pixel to set
                ; returns a = YYYY____  (next pixel in high nybble of A)
setpixel1:       
                push d
                ;push b       ; stream buffer ptr caller-saved
                mov b, a      ; b = saved a, c free 

                mov a, e
                sub m
                mov e, a      ; update pixel addr 

                inx h         ; hl -> pixel mask
                mov c, m      ; c = set mask
                inx h         ; hl -> next in tile sequence

                push h        ; save hl
                mov h, b      ; h = pixel bits XXXXYYYY

                mov a, c
                cma
                mov b, a      ; b = clear mask

                ldax d        ; screen $8000
                ana b
                dad h
                jnc $+4
                ora c
                stax d
                mvi a, $20 \ add d \ mov d, a ; screen $a000

                ldax d
                ana b
                dad h
                jnc $+4
                ora c
                stax d
                mvi a, $20 \ add d \ mov d, a ; screen $c000

                ldax d
                ana b
                dad h
                jnc $+4
                ora c
                stax d
                mvi a, $20 \ add d \ mov d, a ; screen $e000

                ldax d
                ana b
                dad h
                jnc $+4
                ora c
                stax d

                mov a, h
                pop h
                pop d
                ret


; последовательность обхода тайла
;   0  18   6  27   3  54  15  63
;  16  17  25  26  52  53  61  62
;   4  21   5  24  13  57  14  60
;  19  20  22  23  55  56  58  59
;   1  30   9  39   2  42  12  51
;  28  29  37  38  40  41  49  50
;   7  33   8  36  10  45  11  48
;  31  32  34  35  43  44  46  47

; для каждой позиции в тайле: y смещение, вместо x пиксельная маска
pseq_yx:        db 0,255,                   ; 8 - толстая маска
                db 4,$f0, 4,$0f, 0,$0f      ; 4 - половинки
                db 2,$c0, 2,$30, 0,$30,     ; 2 - четвертинки
                db 6,$c0, 6,$30, 4,$30,     
                db 6,$0c, 6,$03, 4,$03, 
                db 2,$0c, 2,$03, 0,$03, 
                db 1,128, 1,64, 0,64, 3,128, 3,64, 2,64, 3,32, 3,16, 2,16, 1,32, 1,16, 0,16, 5,128, 5,64, 4,64, 7,128, 7,64, 6,64, 7,32, 7,16, 6,16, 5,32, 5,16, 4,16, 5,8, 5,4, 4,4, 7,8, 7,4, 6,4, 7,2, 7,1, 6,1, 5,2, 5,1, 4,1, 1,8, 1,4, 0,4, 3,8, 3,4, 2,4, 3,2, 3,1, 2,1, 1,2, 1,1, 0,1        ; 1 - восьмушки

Cls:
		lxi	h,08000h
		xra a
ClrScr:
		mov	m,a
		inx	h
		cmp	h
		jnz	ClrScr
		ret

                ; set palette directly from picstream
                ; h -> pic
colorset:
		mvi	a, 88h
		out	0
		mvi	l, 15
colorset1:
		mov	a, l
		out	2

                push h
                call picstream_getbyte
		out	0Ch
                pop h
		xthl
		xthl
		xthl
		xthl

                dcr l
		out	0Ch
		jp	colorset1
		mvi	a,255
		out	3
                ret
		
picstream_init:
                lxi d, pic
                lxi b, dzx0_Buffer
                push b
                call stream_dzx0
                pop b
                ret

picstream_getbyte:
                ldax b
                inr c
                rnz
picstream_fetch:
                push psw
                push b
                push d
                push h
                call stream_dzx0
                jc picstream_gb_L1
                mvi a, 1
                sta restart_stream_f
picstream_gb_L1:
                pop h
                pop d
                pop b
                pop psw
                ret
picstream_bc    dw 0

                .org     0xff00 & . + 256
dzx0_Buffer      ds 256


                ; init gigachad, install interrupt handler
install_gigachad:
                ; загружаем и прокачиваем начало песенки
                lxi h, song_1
                call gigachad_init
                call gigachad_enable
                call gigachad_precharge

                mvi a, $c3
                sta $38
                lxi h, interrupt
                shld $39
                ret

                ; frame interrupt
interrupt:      push psw
                push b
                push d
                push h
int_colorset_f  equ $+1
                mvi a, 0
                ora a               ; should set palette?
                jz interrupt_L1
                lhld picstream_bc   ; yes, load stream ptr and call colorset
                mov b, h
                mov c, l
                call colorset
                mov h, b
                mov l, c
                shld picstream_bc   ; save stream ptr
                xra a
                sta int_colorset_f  ; and reset colorset flag
interrupt_L1:
                call gigachad_frame ; update music frame
                call ay_send_vi53   ; send to vi53
                pop h
                pop d
                pop b
                pop psw
                ei
                ret

gigachad_wrap_hook
                ora a
                ret

.include dzx0_chunk256.asm

.include VI53.asm

; songe
song_1:         dw songA_00, songA_01, songA_02, songA_03, songA_04, songA_05, songA_06
                dw songA_07, songA_08, songA_09, songA_10, songA_11, songA_12, songA_13
.include songe.inc

.include gigachad16.inc

                .org gigachad_end
                .db 0
pal:
pic		.equ pal+16

		.end
