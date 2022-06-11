;
; Semaforo
;
; Created: 08/06/2022 13:43:22
; Author : jonhl
;

.def temp = r16
.def leds = r17			;valor atual dos LED
.def index = r20		;contador de estado
.def count = r19		;contador do tempo no estado atual
.def count_global = r23	; contador do tempo desde o inicio do ciclo
.def current_delay = r8	;tempo no estado atual
.def part1 = r9			; semaforo 1 e 2
.def part2 = r10		; semaforo 3 e 4
.def zero = r22
.equ num_state = 7

.cseg

jmp reset

.org OC1Aaddr
jmp OCI1A_Interrupt

.dw $cdab
delays:
	;.db 21, 20, 4, 51, 4, 20, 4; tempos dos estados
	.db 3, 3, 3, 3, 3, 3, 3, 3; tempos dos estados

state:
		;R1:1 Y1:0 G1:0 R2:1 Y2:0 G2: 0 ---- R3:1 Y3:0 G3:0 R4:1 Y4:0 G4: 0 
	.dw 0b1001000011100100; estado 1
	.dw 0b1000010011001100; estado 2
	.dw 0b1000100011001100; estado 3
	.dw 0b1001000011001001; estado 4
	.dw 0b1001000011010010; estado 5
	.dw 0b0011000011100100; estado 6
	.dw 0b0101000011100100; estado 7

OCI1A_Interrupt:
	push r16
	in r16, SREG
	push r16
	
	inc count			;adiciona 1 seg a contagem do estado atual
	inc count_global	;adiciona 1 seg a contagem desde o inicio do ciclo
	
	pop r16
	out SREG, r16
	pop r16
	reti


reset:
	;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	;configurando delay do primeiro estado
	ldi ZL, low(delays << 1)
	ldi ZH, high(delays << 1)
	lpm current_delay, Z
	;configurando estado inicial
	ldi ZL, low(state << 1)
	ldi ZH, high(state << 1)
	lpm part1, Z+
	lpm part2, Z

	;habilitando porta de sa�da dos sem�foros 1 e 2
	ldi temp, 0b11111100
	out DDRD, temp
	out PORTD, part2 ;
	;habilitando porta de sa�da dos sem�foros 3 e 4
	ldi temp, 0b00111111
	out DDRB, temp
	out PORTB, part1 ;

	#define CLOCK 16.0e6 ;clock speed
	#define DELAY 0.001 ;seconds
	.equ PRESCALE = 0b100 ;/256 prescale
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100 ;Waveform generation mode: CTC
	;you must ensure this value is between 0 and 65535
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

	;On MEGA series, write high byte of 16-bit timer registers first
	ldi temp, high(TOP) ;initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	sts TCCR1A, temp
	;upper 2 bits of WGM and clock select
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
	; (PRESCALE << CS10) = 0b100 << 0 = 0b100
	; 0b0001000 | 0b100 = 0b0001100
	sts TCCR1B, temp ;start counter

	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A
	sts TIMSK1, r16

	sei

main_lp:
	cp current_delay, count; compara tempo do estado com tempo atual
	breq change_state ;
	rjmp main_lp; continua no estado
change_state:
	ldi count, 0		; reiniciar o temporizador do estado
	inc index			;avan�a ao estado seguinte
	cpi index, num_state;compara se chegou ao fim
	brne progress		;
	ldi index, 0;		;volta ao estado inicial
	ldi count_global, 0	;zera contagem de tempo
progress:
	;configurando delay
	ldi ZL, low(delays << 1)
	ldi ZH, high(delays << 1)
	ldi zero, 0	
	;C�lculo da posi��o na mem�ria	
	add ZL, index	
	adc ZH, zero
	lpm current_delay, Z	;atualiza o temporizador
	;configurando estado atual
	;C�lculo da posi��o na mem�ria	
	ldi ZL, low(state << 1)
	ldi ZH, high(state << 1)
	mov r0, index
	lsl r0
	add ZL, r0
	adc ZH, zero
	lpm part1, Z+
	lpm part2, Z
	;atualiza��o dos leds
	out PORTD, part2
	out PORTB, part1
	rjmp main_lp