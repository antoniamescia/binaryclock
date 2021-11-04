;
; ver3.asm
;
; Created: 9/30/2021 8:20:39 PM
; Author : anton
;
.include "./m328Pdef.inc"
.ORG 0x0000
	jmp		start		;direcci�n de comienzo (vector de reset)  
.ORG 0x0008
	jmp boton
.ORG 0x001C ; cuando la interrupci�n se dispare, va a venir para ac�. Ac� va a ver a d�nde ir (en este caso, lo mando a la rutina de interrupci�n que est� all� abajo)
	jmp		_tmr0_int	;salto atenci�n a rutina de comparaci�n A del timer 0.

// Importante: los ORG tienen que ir de direcciones m�s chicas a m�s grandes, si no se rompe todo. 

; ---------------------------------------------------------------------------------------
; ac� empieza el programa
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
	out		TCCR0A,	r16			;configuro para que cuente hasta OCR0A y vuelve a cero (reset on compare), ah� dispara la interrupci�n
	ldi		r16,	0b00000101	
	out		TCCR0B,	r16			;prescaler = 1024, p�gina 87 del datasheet 
	ldi		r16,	124	
	out		OCR0A,	r16			;comparo con 125
	ldi		r16,	0b00000010	
	sts		TIMSK0,	r16			;habilito la interrupci�n (falta habilitar global)
	/*
	Se configura para que el timer cuente y compare siempre con lo guardado en el registro OCR0A. Cuando alcance el valor guardado, se va a disparar la 
	interrupci�n (siempre y cuando est� habilitada). En este caso tambi�n configuramos el prescaler; el prescaler hace que el timer aumente m�s 'lento'. Puedo
	setear el prescaler en 8, 64, 256 y 1024 (ver p�g 87 del datasheet para ver qu� bits poner en 1s y 0s). Entonces: cada 'tick' del timer va a demorar, en este caso, 1024/16MHz 
	(lo que le marqu� al prescaler dividido la frecuencia del micro). Luego, hago que el timer compare con 125 guardando este valor en el registro OCR0A. Por ende, el tiempo que va 
	a demorar el timer en desbordarse es 1024/16MHz * 125.
	*/

;Configuraci�n interrupci�n del bot�n
	ldi r16, 0b00000010 ;cargo el registro 16
	sts PCICR, r16 ;cargo lo que tengo en r16 a PCICR(Pin Change Interrupt Control Register)
	ldi r16, 0b00001110 ;vuelvo a cargar r16
	sts PCMSK1, r16 ;cargo lo que tengo en r16 a Pin Change Mask Register. En este caso estoy cargando un 1 en el bit 1, 2 y 3 que corresponden a PCINT9, PCINT10, PCINT11
;-------------------------------------------------------------------------------------
;Inicializo algunos registros que voy a usar como variables.
	ldi		r24,	0x00		;inicializo r24 para un contador gen�rico
	ldi		r20,	0x00		;inicializo r20 para guardar el contexto en la interrupci�n.
	ldi		r16,	0x00		;inicializo r26 para usarlo en el contador de 30 segundos
	ldi		r29,	0xFF
	ldi		r26,	0x00
;-------------------------------------------------------------------------------------


;Programa principal ... ac� puedo hacer lo que quiero

comienzo:
	sei							;habilito las interrupciones globales(set interrupt flag)

loop1:
	nop
	nop
	nop
	nop
	ori r16, 0xFF;la instrucci�n ORI hace una comparaci�n bit a bit entre 0xFF (todos 1s) y lo que est� almacenado en r16, salta la flag Z (ahora Z = 1).
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
; Rutina de atenci�n a la interrupci�n del Timer0.
; ------------------------------------------------
; recordar que el timer 0 fue configurado para interrumpir cada 125 ciclos (5^3), y tiene un prescaler 1024 = 2^10.
; El reloj de I/O est� configurado @ Fclk = 16.000.000 Hz = 2^10*5^6; entonces voy a interrumpir 125 veces por segundo
; esto sale de dividir Fclk por el prescaler y el valor de OCR0A.
; 
; Esta rutina por ahora no hace casi nada, Ud puede ir agregando funcionalidades.
; Por ahora solo: cambia el valor de un LED en la placa, e incrementa un contador en r24.


_tmr0_int:
		in		r20, SREG		;guardo el contexto. Es decir, guardo lo que tengo en SREG (las banderas que est�n afectadas actualmente) en r20.
		inc		r24				;cuento cu�ntas veces entr� en la rutina.
		cpi		r24, 125		;comparo lo guardado en r24 con el n�mero 125.
		brbs	1, prender		;si el bit 1 del SREG (es decir, la flag Z) est� en 1, entonces salta a la etiqueta "prender". Si no, sigue a la siguiente instrucci�n/
		out		SREG, r20		;recupero el contexto. Ahora guardo en SREG lo que tengo en r20, que es justamente lo que ten�a en SREG antes de ingresar a la rutina de interrupci�n.
_tmr0_out:
	    reti					;retorno de la rutina de interrupci�n del Timer0
prender:
		//ac� vamos a tener que ver si hay alg�n bot�n activado
		//SBIS PINC,2
		//JMP pausa		
		clr r24				;limpio r24 para poder volver a contar hasta 125
		inc r26				;incremento el r26 que ser� la referencia para el contador de 15 segundos
		mov r27,r26
		EOR r27,r29			;hago un XOR entre lo que tengo en r27 y r29(tengo un FF). Esto va a hacer que se inviertan los bits en r27. Hacemos esto debido a que los LEDS se prenderan cuando el bit est� en 0.
		ROL r27				;roto todos los bits uno a la izquierda. Esto lo hacemos porque los bits que corresponden a las leds son el 2, 3, 4 y 5 (hasta ahora lo ven�amos cargando en el 0, 1, 2 y 3)
		ROL r27		
		out PORTB, r27		;le cargo el valor de r27 al portb y esto va a hacer que se prendan las luces
		cpi r26, 15			;comparo r26 con el decimal 15
		brbs 1, contador	;si Z = 1 (Z salta si r26 = 15, salta a la etiqueta "contador". Si no, contin�a a la pr�xima instrucci�n.
retornodecontador:
		out SREG, r20		;recupero el contexto. Ahora guardo en SREG lo que tengo en r20, que es justamente lo que ten�a en SREG antes de ingresar a la rutina de interrupci�n.
		reti				;retorno de la rutina de interrupci�n
contador:
	clr r26					;limpio el r26
	jmp retornodecontador	;retorno a la rutina que prende la primera LED (para recuperar el contexto y retornar de la interrupci�n)

/*
LED que parpadea:
i) Como el programa es interrumpido 125 veces por segundo, debo entrar a la rutina de atenci�n a la interrupci�n 125 veces para llegar a 1 segundo. 
Para eso, cada vez que entro a la rutina incremento en 1 el valor de r24 y lo comparo con el decimal 125 (la comparaci�n equivale a una resta entre lo guardado en el
registro y el n�mero). Cuando los valores sean iguales, la flag Z se disparar� y quedar� en 1. La instrucci�n BRBS es un branch condicional que se fija si una bandera
est� en 1 (pas�ndole el bit de la bandera correspondiente) y salta a la etiqueta que le indiques. Si no, contin�a a la siguiente instrucci�n.
Cuando r24 = 125 voy a saltar a la etiqueta "prender". En "prender" hago un toggle del pin2 del PINB, limpio el r24 para poder volver a contar hasta 125, recupero el contexto
y retorno de la rutina de i.nterrupci�n. 

ii) Las ventajas del m�todo del timer es que mi programa no est� enfocado en contar ciclos o tiempo para hacer que suceda algo. Puedo estar ejecutando otra cosa en simult�neo
y contar con ingresos a la interrupci�n. 

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