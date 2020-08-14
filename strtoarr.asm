data	segment para public 'data'
message	db 'Vvedite HEX:','$'
message_error	db 010,013,'Error! Please enter again....',010,013,'$'
mas	db 50 dup (0)
data	ends
stk	segment	stack 
	db 256 dup ('?')
stk	ends
code	segment para public 'code'
main	proc
	assume	cs:code,ds:data,ss:stk
	mov	ax,0600h	;выбор функции очистки экрана
	mov	bh,0Eh		;установка цвета 0(черный)-фон 7(белый)-текст
	mov	cx,0000h	;установка начальной точки очистки
	mov	dx,184Fh	;установка конечной точки очистки
	int	10h		;выполнить функцию очистки
	mov	ah,02h		;выбор функции установки курсора
	mov	bh,00		;установка номера страницы, 0
	mov	dh,00		;установка номера строки
	mov	dl,00		;установка номера столбца
	int	10h		;выполнить установку курсора
M0:	;Procedura vvyvoda priglasheniy vvoda
	mov	bx,0
	mov	ax,data
	mov	ds,ax
	mov	ah,9
	mov	dx,offset message
	int	21h
MEnter:
	xor	ax,ax
	mov	ah,1h
	int	21h	;al-vvedennoe znachenie
MCheck:	;Proverka na validnost
	cmp	bx,8
	je	MExit
	cmp	al,'*'
	je	MExit
	cmp	al,29h
	jle	MError
	cmp	al,67h
	jge	MError
	cmp	al,39h
	jle	M1
	cmp	al,61h
	jge	M1
	cmp	al,47h
	jge	MError
	cmp	al,41h
	jge	M1
	cmp	al,40h
	je	MError
	jmp	MError
M1:	;Vybor obrabotchika
;	sub	al,30h
	cmp	al,46h
	jle	M2
	cmp	al,61h
	jge	M3
;	sub	al,7h
	jmp	MEnter
M2:
	add	mas[bx],al
	inc	bx
	jmp	MEnter
M3:	;Esli vvedenoe a-f
	sub	al,20h
	jmp	M2
MError:	;Error
	mov	ax,0600h
	mov	bh,04h
	inc	ch
	mov	dx,184Fh	;установка конечной точки очистки
	int	10h	
	mov	ah,9
	mov	dx,offset message_error
	int	21h
;Obnulenie massiva
	mov	ax,0600h
	mov	bh,0Eh
	inc	ch
	mov	dx,184Fh	;установка конечной точки очистки
	int	10h		
	jmp	M0
MExit:	;Exit
	mov	ax,4c00h
	int	21h
main	endp
code	ends
end	main
