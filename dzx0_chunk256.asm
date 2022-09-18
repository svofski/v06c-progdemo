; -----------------------------------------------------------------------------
; ZX0 8080 stream chunk256 decoder by Ivan Gorodetsky - OLD FILE FORMAT v1 
; Based on ZX0 z80 decoder by Einar Saukas
; v1 (2022-09-14) - 179 bytes forward / 181 bytes backward
; v2 (2022-09-18) - 179 bytes forward / 181 bytes backward (slightly faster, preserve BC between chunks) 
; -----------------------------------------------------------------------------
; Parameters (forward):
;   DE: source address (compressed data)
;   BC: destination buffer (decompressing)
;
; Parameters (backward):
;   DE: last source address (compressed data)
;   BC: destination buffer (decompressing)
; -----------------------------------------------------------------------------
; On exit:
;   CY=1 - decompression not finished
; -----------------------------------------------------------------------------
; compress forward with <-classic -w256> options (salvador)
;
; compress backward with <-b -classic -w256> options (salvador)
;
; Compile with The Telemark Assembler (TASM) 3.2
; ----------------------------------------------------------------------------- 


;#define BACKWARD

#ifdef BACKWARD
#define NEXT_HL dcx h
#define NEXT_DE dcx d
#define NEXT_DElo dcr e
#define NEXT_BC dcr c
#else
#define NEXT_HL inx h
#define NEXT_DE inx d
#define NEXT_DElo inr e
#define NEXT_BC inr c
#endif

;You can change dzx0_Buffer
;dzx0_Buffer	.equ 0FF00h

stream_dzx0:
		jmp stream_dzx0_Init
stream_dzx0_Init:
		mov a,b
		sta stream_dzx0_SetBC+2
		lxi h,stream_dzx0_GetChunk
		shld stream_dzx0+1
#ifdef BACKWARD
		mvi a,1
		sta stream_dzx0_offset+1
		lxi h,0
#else
		mvi a,0FFh
		sta stream_dzx0_offset+1
		lxi h,0
#endif
		mvi a,080h
stream_dzx0_literals:
		call stream_dzx0_elias
		sta stream_dzx0_ldir1_2+1
stream_dzx0_ldir1_1:
		ldax d
		stax b
		inx d ; NEXT_DE
		inr c ;NEXT_BC
		jnz stream_dzx0_ldir1_3
		shld stream_dzx0_SetHL+1
		xchg
		shld stream_dzx0_SetDE+1
		lxi h,stream_dzx0_ldir1_3
		shld stream_dzx0_SetJmp2+1
		stc
		ret
stream_dzx0_ldir1_3:
		dcx h
		mov a,h
		ora l
		jnz stream_dzx0_ldir1_1
stream_dzx0_ldir1_2:
		mvi a,0
		add a
		
		jc stream_dzx0_new_offset
		call stream_dzx0_elias
stream_dzx0_copy:
		xchg
		shld stream_dzx0_copy2+1
		xchg
		sta stream_dzx0_ldir2_2+1
stream_dzx0_offset:
		mvi a,0
		add c
		mov e,a
		mov d,b
stream_dzx0_ldir2_1:
		ldax d
		stax b
		inr e ; NEXT_DElo
		inr c ; NEXT_BC
		jnz stream_dzx0_ldir2_3
		shld stream_dzx0_SetHL+1
		xchg
		shld stream_dzx0_SetDE+1
		lxi h,stream_dzx0_ldir2_3
		shld stream_dzx0_SetJmp2+1
		stc
		ret
stream_dzx0_ldir2_3:
		dcx h
		mov a,h
		ora l
		jnz stream_dzx0_ldir2_1
stream_dzx0_ldir2_2:
		mvi a,0
		add a
stream_dzx0_copy2:
		lxi d,0
		jnc stream_dzx0_literals
stream_dzx0_new_offset:
		call stream_dzx0_elias
#ifdef BACKWARD
		dcr h
		jz stream_dzx0_exit
		dcr l
		push psw
		mov a,l
#else
		mov h,a
		xra a
		sub l
		jz stream_dzx0_exit
#endif
		rar
		ldax d
		rar
		inx d ; NEXT_DE
#ifdef BACKWARD
		inr a
#endif
		sta stream_dzx0_offset+1
		mov a,h
		lxi h,1
#ifdef BACKWARD
		cc stream_dzx0_elias_backtrack
#else
		cnc stream_dzx0_elias_backtrack
#endif
		inx h
		jmp stream_dzx0_copy
stream_dzx0_elias:
		inr l
stream_dzx0_elias_loop:	
		add a
		jnz stream_dzx0_elias_skip
		ldax d
		inx d ; NEXT_DE
		ral
stream_dzx0_elias_skip:
#ifdef BACKWARD
		rnc
#else
		rc
#endif
stream_dzx0_elias_backtrack:
		dad h
		add a
		jnc stream_dzx0_elias_loop
		jmp stream_dzx0_elias

stream_dzx0_exit:
		lxi h,stream_dzx0_Init
		shld stream_dzx0+1
		ret
		
stream_dzx0_GetChunk:
stream_dzx0_SetHL:
		lxi h,0
stream_dzx0_SetDE:
		lxi d,0
stream_dzx0_SetBC:
		lxi b,0
stream_dzx0_SetJmp2:
		jmp 0

		.end
