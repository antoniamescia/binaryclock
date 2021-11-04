;
; ver3.asm
;
; Created: 9/30/2021 8:20:39 PM
; Author : anton
;
.include "./m328Pdef.inc"
.ORG 0x0000
	jmp		start		;dirección de comienzo (vector de reset)  
.ORG 0x0008
	jmp boton
.ORG 0x001C ; cuando la interrupción se dispare, va a venir para acá. Acá va a ver a dónde ir (en este caso, lo mando a la rutina de interrupción que está allá abajo)
	jmp		_tmr0_int	;salto atención a rutina de comparación A del timer 0.

// Importante: los ORG tienen que ir de direcciones más chicas a más grandes, si no se rompe todo. 

; ---------------------------------------------------------------------------------------
; acá empieza el programa
start:
;configuro los puertos:
;	PB2 PB3 PB4 PB5	- son los LEDs del shield
    ldi		r16,	0b00111100	
	out		DDRB,	r16			;4 LEDs del shield son salidas
	out		PORTB,	r16			;apago los LEDs

	ldi		r16,	0b00000000	
	out		DDRC,	r16			;3 botones del shield son entradas
;-------------------------------------------------------------------------------------

;Configuro el TMR0 y su interrupcion.
	ldi		r16,	0b00000010	
	out		TCCR0A,	r16			;configuro para que cuente hasta OCR0A y vuelve a cero (reset on compare), ahí dispara la interrupción
	ldi		r16,	0b00000101	
	out		TCCR0B,	r16			;prescaler = 1024, página 87 del datasheet 
	ldi		r16,	124	
	out		OCR0A,	r16			;comparo con 125
	ldi		r16,	0b00000010	
	sts		TIMSK0,	r16			;habilito la interrupción (falta habilitar global)
	/*
	Se configura para que el timer cuente y compare siempre con lo guardado en el registro OCR0A. Cuando alcance el valor guardado, se va a disparar la 
	interrupción (siempre y cuando esté habilitada). En este caso también configuramos el prescaler; el prescaler hace que el timer aumente más 'lento'. Puedo
	setear el prescaler en 8, 64, 256 y 1024 (ver pág 87 del datasheet para ver qué bits poner en 1s y 0s). Entonces: cada 'tick' del timer va a demorar, en este caso, 1024/16MHz 
	(lo que le marqué al prescaler dividido la frecuencia del micro). Luego, hago que el timer compare con 125 guardando este valor en el registro OCR0A. Por ende, el tiempo que va 
	a demorar el timer en desbordarse es 1024/16MHz * 125.
	*/

;Configuración interrupción del botón
	ldi r16, 0b00000010 ;cargo el registro 16
	sts PCICR, r16 ;cargo lo que tengo en r16 a PCICR(Pin Change Interrupt Control Register)
	ldi r16, 0b00001110 ;vuelvo a cargar r16
	sts PCMSK1, r16 ;cargo lo que tengo en r16 a Pin Change Mask Register. En este caso estoy cargando un 1 en el bit 1, 2 y 3 que corresponden a PCINT9, PCINT10, PCINT11
;-------------------------------------------------------------------------------------
;Inicializo algunos registros que voy a usar como variables.
	ldi		r24,	0x00		;inicializo r24 para un contador genérico
	ldi		r20,	0x00		;inicializo r20 para guardar el contexto en la interrupción.
	ldi		r16,	0x00		;inicializo r26 para usarlo en el contador de 30 segundos
	ldi		r29,	0xFF
	ldi		r26,	0x00
;-------------------------------------------------------------------------------------


;Programa principal ... acá puedo hacer lo que quiero

comienzo:
	sei							;habilito las interrupciones globales(set interrupt flag)

loop1:
	nop
	nop
	nop
	nop
	ori r16, 0xFF;la instrucción ORI hace una comparación bit a bit entre 0xFF (todos 1s) y lo que esté almacenado en r16, salta la flag Z (ahora Z = 1).
	nop
	nop
	nop
	brne	loop1
loop2:
	nop
	nop
	nop
fin:
	rjmp loop2

;RUTINAS
;-------------------------------------------------------------------------------------

; ------------------------------------------------
; Rutina de atención a la interrupción del Timer0.
; ------------------------------------------------
; recordar que el timer 0 fue configurado para interrumpir cada 125 ciclos (5^3), y tiene un prescaler 1024 = 2^10.
; El reloj de I/O está configurado @ Fclk = 16.000.000 Hz = 2^10*5^6; entonces voy a interrumpir 125 veces por segundo
; esto sale de dividir Fclk por el prescaler y el valor de OCR0A.
; 
; Esta rutina por ahora no hace casi nada, Ud puede ir agregando funcionalidades.
; Por ahora solo: cambia el valor de un LED en la placa, e incrementa un contador en r24.


_tmr0_int:
		in		r20, SREG		;guardo el contexto. Es decir, guardo lo que tengo en SREG (las banderas que están afectadas actualmente) en r20.
		inc		r24				;cuento cuántas veces entré en la rutina.
		cpi		r24, 125		;comparo lo guardado en r24 con el número 125.
		brbs	1, prender		;si el bit 1 del SREG (es decir, la flag Z) está en 1, entonces salta a la etiqueta "prender". Si no, sigue a la siguiente instrucción/
		out		SREG, r20		;recupero el contexto. Ahora guardo en SREG lo que tengo en r20, que es justamente lo que tenía en SREG antes de ingresar a la rutina de interrupción.
_tmr0_out:
	    reti					;retorno de la rutina de interrupción del Timer0
prender:
		//acá vamos a tener que ver si hay algún botón activado
		//SBIS PINC,2
		//JMP pausa		
		clr r24				;limpio r24 para poder volver a contar hasta 125
		inc r26				;incremento el r26 que será la referencia para el contador de 15 segundos
		mov r27,r26
		EOR r27,r29			;hago un XOR entre lo que tengo en r27 y r29(tengo un FF). Esto va a hacer que se inviertan los bits en r27. Hacemos esto debido a que los LEDS se prenderan cuando el bit está en 0.
		ROL r27				;roto todos los bits uno a la izquierda. Esto lo hacemos porque los bits que corresponden a las leds son el 2, 3, 4 y 5 (hasta ahora lo veníamos cargando en el 0, 1, 2 y 3)
		ROL r27		
		out PORTB, r27		;le cargo el valor de r27 al portb y esto va a hacer que se prendan las luces
		cpi r26, 15			;comparo r26 con el decimal 15
		brbs 1, contador	;si Z = 1 (Z salta si r26 = 15, salta a la etiqueta "contador". Si no, continúa a la próxima instrucción.
retornodecontador:
		out SREG, r20		;recupero el contexto. Ahora guardo en SREG lo que tengo en r20, que es justamente lo que tenía en SREG antes de ingresar a la rutina de interrupción.
		reti				;retorno de la rutina de interrupción
contador:
	clr r26					;limpio el r26
	jmp retornodecontador	;retorno a la rutina que prende la primera LED (para recuperar el contexto y retornar de la interrupción)

/*
LED que parpadea:
i) Como el programa es interrumpido 125 veces por segundo, debo entrar a la rutina de atención a la interrupción 125 veces para llegar a 1 segundo. 
Para eso, cada vez que entro a la rutina incremento en 1 el valor de r24 y lo comparo con el decimal 125 (la comparación equivale a una resta entre lo guardado en el
registro y el número). Cuando los valores sean iguales, la flag Z se disparará y quedará en 1. La instrucción BRBS es un branch condicional que se fija si una bandera
está en 1 (pasándole el bit de la bandera correspondiente) y salta a la etiqueta que le indiques. Si no, continúa a la siguiente instrucción.
Cuando r24 = 125 voy a saltar a la etiqueta "prender". En "prender" hago un toggle del pin2 del PINB, limpio el r24 para poder volver a contar hasta 125, recupero el contexto
y retorno de la rutina de i.nterrupción. 

ii) Las ventajas del método del timer es que mi programa no está enfocado en contar ciclos o tiempo para hacer que suceda algo. Puedo estar ejecutando otra cosa en simultáneo
y contar con ingresos a la interrupción. 

iii) 
*/
boton:
	in r28, SREG			;guardo el contexto
	SBIS PINC,1
	RJMP reset		
	SBIS PINC,2
	jmp pausa
	out SREG, r28
	reti
reset:
	clr r26
	out SREG,r28
	reti
pausa:
	SBIS PINC,3
	JMP prender
	rjmp pausa