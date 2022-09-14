; можно распаковывать чанками по 256 -- меньше оверхед, но мешается музону
; #define GETCHUNK256
; без дефайна чанки по 16

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
		ei
		hlt
		lxi h, pal
                call colorset

Restart:
		lxi	sp,$100
		call	Cls

                call install_gigachad
                ei

picture_again:

                call picstream_init

                ; first refinement: 32x32
                ; pixel 0 of every tile
                lxi d, $80ff  ; $8000 top row
                
                call setpixel_set8

t8_L1
                ;ldax b
                ;inx b
                call picstream_getbyte
                lxi h, pseq_yx
                call setpixel
                inr d
                lxi h, pseq_yx
                call setpixel
                inr d
                mvi a, $a0
                cmp d
                jnz t8_L1
                mvi d, $80
                mvi a, -8
                add e
                jnc t8_done
                mov e, a
                jmp t8_L1
t8_done:

                call setpixel_set4

                lxi d, $80ff
t4_L1:
                call picstream_getbyte
                lxi h, pseq_yx + 1*2
                call setpixel     ; 1
                call setpixel     ; 2
                call picstream_getbyte
                call setpixel     ; 3
                inr d
                lxi h, pseq_yx + 1*2
                call setpixel     ; 1
                call picstream_getbyte
                call setpixel     ; 2
                call setpixel     ; 3

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

                call setpixel_set2
                
                lxi d, $80ff
t2_L0:
                lxi h, pseq_yx + 4*2
                mvi a, 12
t2_L1:
                push psw
                call picstream_getbyte
                call setpixel
                call setpixel
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
                call setpixel_set1

                lxi d, $80ff
tile1_L0:
                lxi h, pseq_yx + 16*2
                mvi a, 48
tile1_L1:
                push psw
                call picstream_getbyte
                call setpixel   ; set pixel in high nybble of A
                call setpixel
                call picstream_getbyte
                call setpixel   ; set pixel in high nybble of A
                call setpixel

                pop psw
                sui 4
                jnz tile1_L1

                ; next column
                inr d
                mvi a, $a0
                cmp d
                jnz tile1_L0

                mvi d, $80
                mvi a, -8
                add e
                jnc tile1_done
                mov e, a
                jmp tile1_L0
tile1_done
		jmp picture_again




                ; d = tile addr
                ; hl = ptr to yx offsets in current tile 
                ; a = XXXXYYYY  ; XXXX =color pixel to set
                ; returns a = YYYY____  (next pixel in high nybble of A)
setpixel:       
                push d
                push b
                push h
                mov b, a      ; b = saved a, c free 

                mov a, e
                sub m
                mov e, a      ; update pixel addr 
                inx h         ; h -> pixel mask
                mov c, m      ; c = set mask
                mov h, b      ; h = pixel bits
                mov a, c
                cma
                mov b, a      ; b = clear mask

setpixel_L1
                ldax d        ; screen $8000
                ana b
                dad h
                jnc $+4
                ora c
                ;stax d
setpixel_stax:
                nop
                call stax4d

                mvi a, $20 \ add d \ mov d, a ; screen $a000, etc..
                jnc setpixel_L1

                mov a, h
                sta setpix_nexta  ; save next pixel in A on return

                pop h
                inx h \ inx h
                pop b
                pop d

setpix_nexta    equ $+1
                mvi a, 0
                ret

setpixel_set8:
                lxi h, $cd00
                shld setpixel_stax
                lxi h, stax8
                shld setpixel_stax+2
                ret
setpixel_set4:
                lxi h, $cd00
                shld setpixel_stax
                lxi h, stax4
                shld setpixel_stax+2
                ret
setpixel_set2:
                lxi h, $1d12
                shld setpixel_stax    ; stax d \ dcr e
                lxi h, $1c12          ; stax d \ inr e
                shld setpixel_stax+2
                ret
setpixel_set1:  lxi h, $1200          ; nop \ stax d
                shld setpixel_stax
                lxi h, 0
                shld setpixel_stax+2
                ret

stax8:
                stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e
                stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e \ stax d
                mvi a, 7 \ add e \ mov e, a
                ret

stax4:
                stax d \ dcr e \ stax d \ dcr e \ stax d \ dcr e \ stax d
                mvi a, 3 \ add e \ mov e, a
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

; для каждой позиции в тайле: y смещение, пиксельная маска
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

                ; h -> pic
colorset:
		mvi	a, 88h
		out	0
		mvi	c, 15
colorset1:
		mov	a, c
		out	2
		mov	a, m
		out	0Ch
		xthl
		xthl
		xthl
		xthl
		inx h
		dcr	c
		out	0Ch
		jp	colorset1
		mvi	a,255
		out	3
		

picstream_init:
                lxi h, 0
                dad sp
                shld pic_dzx0_caller_sp
                
                lxi sp, pic_dzx0_stack_end
                lxi b, pic_buffer
                lxi d, pic
                lxi h, pic_dzx0
                push h
                jmp pic_dzx0_yield

picstream_getbyte:
#ifdef GETCHUNK256
                xra a
                ora c
#else
                mvi a, 15
                ana c
#endif
                jnz ps_getbyte_L1
                ; unpack another block
                push b
                push d
                push h
                di
                call pic_dzx0_enter
                ei
                pop h
                pop d
                pop b
ps_getbyte_L1   
                ldax b
                inr c
                ret

pic_dzx0_caller_sp  dw 0
pic_dzx0_task_sp    dw 0

pic_dzx0_enter:
                lxi h, 0
                dad sp
                shld pic_dzx0_caller_sp
                lhld pic_dzx0_task_sp
                sphl
                pop h
                pop d
                pop b
                pop psw
                ret

pic_dzx0_yield:
                push psw
                push b
                push d
                push h
                lxi h, 0
                dad sp
                shld pic_dzx0_task_sp
                lhld pic_dzx0_caller_sp
                sphl
                ret
                

                ; gigachad-ful pic_dzx0

                ;; pic_dzx0()
                ;; 
                ;; Unpack zx0 stream packed with 256-byte sized window.
                ;; Yields every 16 bytes.
pic_dzx0:
		lxi h,0FFFFh            ; tos=-1 offset?
		push h
		inx h
		mvi a,080h
pic_dzx0_literals:  ; Literal (copy next N bytes from compressed file)
		call pic_dzx0_elias         ; hl = read_interlaced_elias_gamma(FALSE)
;		; for (i = 0; i < length; i++) write_byte(read_byte()
		push psw
pic_dzx0_ldir1:
		ldax d
		stax b
		inx d
		inr c           ; stay within circular buffer

#ifdef GETCHUNK256
		; yield every 256 bytes
                xra a
                ora c
#else
		; yield every 16 bytes
                mvi a, 15
                ana c
#endif
		cz pic_dzx0_yield 
		dcx h
		mov a,h
		ora l
		jnz pic_dzx0_ldir1
		pop psw
		add a

		jc pic_dzx0_new_offset      ; if (read_bit()) goto COPY_FROM_NEW_OFFSET
	
		; COPY_FROM_LAST_OFFSET
		call pic_dzx0_elias         ; hl = read_interlaced_elias_gamma(FALSE) 
pic_dzx0_copy:
		xchg                    ; hl = src, de = length
		xthl                    ; ex (sp), hl:
		                        ; tos = src
		                        ; hl = -1
		push h                  ; push -1
		dad b                   ; h = -1 + dst
		mov h, b                ; stay in the buffer!
		xchg                    ; de = dst + offset, hl = length
;		                        ; for (i = 0; i < length; i++) write_byte(dst[-offset+i]) 
		push psw
pic_dzx0_ldir_from_buf:
		ldax d
		stax b
		inr e
		inr c                   ; stay within circular buffer
		
		; yield every 256 bytes
#ifdef GETCHUNK256
                xra a
                ora c
#else
                mvi a, 15
                ana c
#endif
		cz pic_dzx0_yield 
		dcx h
		mov a,h
		ora l
		jnz pic_dzx0_ldir_from_buf
		mvi h,0
		pop psw
		add a
		                        ; de = de + length
		                        ; hl = 0
		                        ; a, carry = a + a 
		xchg                    ; de = 0, hl = de + length .. discard dst
		pop h                   ; hl = old offset
		xthl                    ; offset = hl, hl = src
		xchg                    ; de = src, hl = 0?
		jnc pic_dzx0_literals       ; if (!read_bit()) goto COPY_LITERALS
		
		; COPY_FROM_NEW_OFFSET
		; Copy from new offset (repeat N bytes from new offset)
pic_dzx0_new_offset:
		call pic_dzx0_elias         ; hl = read_interlaced_elias_gamma()
		mov h,a                 ; h = a
		pop psw                 ; drop offset from stack
		xra a                   ; a = 0
		sub l                   ; l == 0?
		;rz                      ; return
		jz pic_dzx0_ded
		push h                  ; offset = new offset
		; last_offset = last_offset*128-(read_byte()>>1);
		rar\ mov h,a            ; h = hi(last_offset*128)
		ldax d                  ; read_byte()
		rar\ mov l,a            ; l = read_byte()>>1
		inx d                   ; src++
		xthl                    ; offset = hl, hl = old offset
		
		mov a,h                 ; 
		lxi h,1                 ; 
		cnc pic_dzx0_elias_backtrack; 
		inx h
		jmp pic_dzx0_copy
pic_dzx0_elias:
		inr l
pic_dzx0_elias_loop:	
		add a
		jnz pic_dzx0_elias_skip
		ldax d
		inx d
		ral
pic_dzx0_elias_skip:
		rc
pic_dzx0_elias_backtrack:
		dad h
		add a
		jnc pic_dzx0_elias_loop
		jmp pic_dzx0_elias
pic_dzx0_ldir:
		push psw
		mov a, b
		cmp d
		jz pic_dzx0_ldir_from_buf

                ; reached the end of stream
pic_dzx0_ded       
                ; notify gigachad that this stream has finished
                ;lxi h, pic_dzx0_finish_ctr
                ;inr m
                ;; idle forever: gigachad will restart the task/stream
                ;call pic_dzx0_yield
                ;jmp $-3
                call pic_dzx0_yield


                ; ----------------------------
pic_dzx0_stack      ds 22
pic_dzx0_stack_end:
                .org     0xff00 & . + 256
pic_buffer      ds 256


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

interrupt:      push psw
                push b
                push d
                push h
                call gigachad_frame
                call ay_send_vi53
                pop h
                pop d
                pop b
                pop psw
                ei
                ret

gigachad_wrap_hook
                ora a
                ret

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
