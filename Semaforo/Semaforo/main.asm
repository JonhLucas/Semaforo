;Nomes:
;		Jonh Lucas
;		João Paulo
;		Antônio Alef
;		Período: 2021.2

.def current_delay = r8	;tempo no estado atual
.def part1 = r9			; semaforo 1 e 2
.def part2 = r10		; semaforo 3 e 4
.def temp = r16
.def leds = r17			;valor atual dos LED
.def alternador = r18	; define o digito a ser aceso 
.def count = r19		;contador do tempo no estado atual
.def index_string = r20	; indice do caracter da string referente ao estado atual
.def dig1 = r21			; valor de dezena
.def dig2 = r25			; valor de unidade
.def index = r23		;contador de estado
.def zero = r24

.equ num_state = 7
;16 mhz clock speed, 9600 baud UBRR = 103
.equ UBRRvalue = 103

.cseg

jmp reset

.org OC1Aaddr
jmp OCI1A_Interrupt

.org OC0Baddr
jmp OCI0B_Interrupt

delays:
	.db 21, 20, 4, 51, 4, 20, 4; tempos dos estados
	;.db 5, 5, 5, 5, 5, 5, 5, 5; tempos dos estados

state:
		;R1:1 Y1:0 G1:0 R2:1 Y2:0 G2: 0 ---- R3:1 Y3:0 G3:0 R4:1 P G4: 0 
	.dw 0b1001000011100110; estado 1
	.dw 0b1000010011001100; estado 2
	.dw 0b1000100011001100; estado 3
	.dw 0b1001000011001001; estado 4
	.dw 0b1001000011010000; estado 5
	.dw 0b0011000011100100; estado 6
	.dw 0b0101000011100100; estado 7

logs:
	.db 'E','0',':',' ','R',',',' ','R',',',' ','R',',',' ','R',',',' ','G', 0b1010
	.db 'E','1',':',' ','R',',',' ','G',',',' ','G',',',' ','R',',',' ','R', 0b1010
	.db 'E','2',':',' ','R',',',' ','Y',',',' ','G',',',' ','R',',',' ','R', 0b1010
	.db 'E','3',':',' ','R',',',' ','R',',',' ','G',',',' ','G',',',' ','R', 0b1010
	.db 'E','4',':',' ','R',',',' ','R',',',' ','Y',',',' ','Y',',',' ','R', 0b1010
	.db 'E','5',':',' ','G',',',' ','R',',',' ','R',',',' ','R',',',' ','R', 0b1010
	.db 'E','6',':',' ','Y',',',' ','R',',',' ','R',',',' ','R',',',' ','R', 0b1010

OCI1A_Interrupt:
	push r16
	in r16, SREG
	push r16
	
	inc count			;adiciona 1 seg a contagem do estado atual
	cpi dig1, 9
	breq restart
	inc dig1			;incrementa a unidade
	jmp continue

restart:
	ldi dig1, $00		;zera a unidade
	inc dig2			;incrementa a dezena

continue:
	pop r16
	out SREG, r16
	pop r16
	reti

OCI0B_Interrupt:
	push r16
	in r16, SREG
	push r16
	; alterna entre 0 e 1 a cada chamada da interrupção
	inc alternador
	andi alternador, 0b1	;considera apenas o último bit

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

	;habilitando porta de saída dos semáforos 1 e 2
	ldi temp, 0b11111100
	out DDRD, temp
	out PORTD, part2 ;
	;habilitando porta de saída dos semáforos 3, 4 e pedestre
	ldi temp, 0b00111111
	out DDRB, temp
	out PORTB, part1

	;habilitando porta de saída do bcd
	ldi temp, 0b00111111	;00|d2|d1|valor
	out DDRC, temp
	out PORTC, zero

	#define CLOCK 16.0e6 ;clock speed
	#define DELAY 1;0.001 ;seconds
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

	lds r16, TIFR1
	sbr r16, 1 << 1
	sts TIFR1, r16

	;you must ensure this value is between 0 and 255
	#define DELAY_2 0.001 ;seconds
	.equ PRESCALE2 = 0b100 ;/256 prescale
	.equ PRESCALE_DIV2 = 256
	.equ TOP2 = int(0.5 + ((CLOCK/PRESCALE_DIV2)*DELAY_2));63
	.if TOP2 > 255
	.error "TOP2 is out of range"
	.endif

	.equ new_WGM = 0b0010		;CTC to TC0

	ldi temp, ((new_WGM & 0b11) << WGM00)
	out TCCR0A, temp

	ldi temp, ((new_WGM >> 2) << WGM02)|(PRESCALE2 << CS00)
	out TCCR0B, temp ;start counter

	ldi temp, TOP2 ;initialize
	out OCR0A, temp

	lds r16, TIMSK0
	sbr r16, 1 <<OCIE0A
	sts TIMSK0, r16

	lds r16, TIFR0
	sbr r16, 1 << OCF0A
	out TIFR0, r16

	;initialize USART
	ldi temp, high (UBRRvalue) ;baud rate
	sts UBRR0H, temp
	ldi temp, low (UBRRvalue)
	sts UBRR0L, temp
	;URSEL 0 = UBRRH, 1 = UCSRC (shared port address)
	;UMSEL 0 = Asynchronous, 1 = Synchronous
	;USBS 0 = One stop bit, 1 = Two stop bits
	;UCSZ0:1 Character Size: 0 = 5, 1 = 6, 2 = 7, 3 = 8
	;UPM0:1 0 = none, 1 = reserved, 2 = Even, 3 = Odd

	;8 bits, 1 stop, no parity
	ldi temp, (3<<UCSZ00)
	sts UCSR0C, temp
	ldi temp, (1<<RXEN0)|(1<<TXEN0)
	sts UCSR0B, temp; enable receive and transmit
	;USART initialization complete


	;configurando registradores
	ldi alternador, $00
	ldi dig1, $00
	ldi dig2, $00
	ldi index, $00
	ldi count, $00
	ldi index_string, $00

	rcall transmit

	sei

main_lp:
;Ativação dos digitos do display
	cpi alternador, $00		;verifica o digito a ser aceso
	brne aciona_dig2		;
	mov temp, dig1
	sbr temp, 1 << 4		;ativa flag do digito 1
	out PORTC, temp
	jmp compara
aciona_dig2:
	mov temp, dig2
	sbr temp, 1 << 5		;ativa flag do digito 2
	out PORTC, temp

compara:
	cp current_delay, count	; compara tempo do estado com tempo atual
	breq change_state ;
	rjmp main_lp			; continua no estado
change_state:
	ldi count, 0		; reiniciar o temporizador do estado
	inc index			;avança ao estado seguinte
	cpi index, num_state;compara se chegou ao fim
	brne progress		;
	ldi index, 0;		;volta ao estado inicial
	ldi index_string, 0
	
progress:
	;configurando delay
	ldi ZL, low(delays << 1)
	ldi ZH, high(delays << 1)
	ldi zero, 0	
	;Cálculo da posição na memória	
	add ZL, index	
	adc ZH, zero
	lpm current_delay, Z	;atualiza o temporizador
	;configurando estado atual
	;Cálculo da posição na memória	
	ldi ZL, low(state << 1)
	ldi ZH, high(state << 1)
	mov r0, index
	lsl r0
	add ZL, r0
	adc ZH, zero

	mov temp, part2			;armazena estado atual do semaforo 1
	andi temp, 0b11100000	;mascara para semaforo 1

	lpm part1, Z+			;atualizando estado dos semaforos 3 e 4
	lpm part2, Z			;atualizando estado dos semaforos 1 e 2

	and temp, part2			;comparando novo estado com o anterior
	cpi temp, $00
	brne saida			;em caso de alteração:
	ldi dig1, $00		;reinicia digito da unidade
	ldi dig2, $00		;reinicia digito da dezena

saida:	;atualização dos leds
	out PORTD, part2		
	out PORTB, part1
	rcall transmit		;inicia a transmissão do log
	rjmp main_lp


transmit:
	lds temp, ucsr0a		;carregango o estado do buffer
	sbrs temp, udre0		;Verifica bit 5 (disponibilidade do buffer)
	rjmp transmit			;buffer ocupado

	;Cálculo da posição na memória	
	ldi ZL, low(logs << 1)
	ldi ZH, high(logs << 1)
	add ZL, index_string
	adc ZH, zero
	lpm temp, Z		;carregando caracter a ser transmitido
	sts udr0, temp	;enviando caracter

	inc index_string	;avança para o próximo caracter
	cpi temp, 0b1010	;Verifica se é o final da string
	brne transmit		;
	ret					;fim da transmissão
