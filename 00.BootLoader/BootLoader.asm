[ORG 0x00]   ; Code start address : 0x00
[BITS 16]    ; 16-bit environment

SECTION .text  ; text section(Segment)

jmp 0x07C0:START    ; copy 0x0C70 to cs, and goto START

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OS에 관련된 환경설장깂
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TOTALSECTORCOUNT:	dw 0x02
KERNEL32SECTORCOUNT: dw 0x02	; 보호모드 커널의 총 섹터 수

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:
	mov ax, 0x07C0 ; convert start address to 0x0C70
	mov ds, ax   ; set ds register
	mov ax, 0xB800 ; base video address
	mov es, ax   ; set es register(videos address)
    
	;  스택을 0x0000:0000 ~ 0x0000:FFFF 영역에 64kb크기로 생성
	mov ax, 0x0000	; 스택 세그먼트의 시작 어드레스(0x0000)를 세그먼트 레지스터 값으로 변환
	mov ss, ax	; SS세그먼트 레지스터에 설정
	mov sp, 0xFFFE	; SP레지스터의 어드레스를 0xFFFE로 설정
	mov bp, 0xFFFE	; BP레지스터의 어드레스를 0xFFFE로 설정

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 화면을 모두 지우고 속성값을 녹색으로 설정
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov si,	0	; SI 레지스터(문자열 원본 인덱스 레지스터)를 초기화

.SCREENCLEARLOOP:
	; es: si = es 세그먼트: 오프셋
	mov byte [ es: si ], 0		; delete character at si index
	mov byte [ es: si + 1], 0x0A	; copy 0x)A(black / gree)
	add si, 2			; go to next location
	cmp si, 80 * 25 *2		; compare si and screen size
	jl .SCREENCLEARLOOP		; end loop if si == screen size

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 화면 상단에 시작 메시지 출력
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	push MESSAGE1		; 출력할 메시지의 어드레스를 스택에 삽입
	push 0			; 화면 Y좌표(0)를 스택에 삽입
	push 0			; 화면 x좌표(0)를 스택에 삽입
	call PRINTMESSAGE	; PRINTMESSAGE 함수 호출
	add sp, 6		; 삽입한 파라미터 제거
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; OS이미지를 로딩한다는 메시지 출력
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	push IMAGELOADINGMESSAGE	; 출력할 메시지의 어드레스를 스택에 삽입
	push 1				; 화면 y좌표(1)를 스택에 삽입
	push 0				; 화면 x좌표(0)를 스택에 삽입
	call PRINTMESSAGE		; PRINTMESSAGE 함수 호출
	add sp, 6			; 삽입한 파라미터 제거

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 디스크에서 os이미지를를 로딩
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 디스크를 읽기 전에 먼저 리셋
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESETDISK:					; 디스크를 리섹하는 코드의 시작
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; BIOS Reset Function호출
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 서비스 번호 0, 드라이브 번호(0=Floppy)
	mov ax, 0
	mov dl, 0
	int 0x13
	; 에러가 발생하면 에러 처리로 이동
	jc HANDLEDISKERROR

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 디스크에서 섹터를 읽음
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 디스크의 내용을 메모리로 복사할 어드레스(ES:BX)를 0x10000으로 설정
	mov si, 0x1000				; os이미지를 복사할 어드레스(0x10000)를 세그먼트 레지스터 값으로 변환
	mov es, si				; es 세그먼트 레지스터에 값 설정
	mov bx, 0x0000				; bx레지스터에 0x0000을 설정하여 복사할 어드레스를 0x1000:0000(0x10000)으로 최종 설정

	mov di, word[ TOTALSECTORCOUNT ]	; 복사할 OS이미지의 섹터 수를 DI레지스터에 설정

READDATA:					;디스크를 읽는 코드의 시작
	; 모든 섹터를 다 읽었는지 확인
	cmp di, 0			; 복사할 os이미지의 섹터수를 0과 비교
	je READEND			; 복사할 섹터 수가 0이라면 다 복사 했으므로 READEND로 이동
	sub di, 0x1			; 복사할 섹터 수를 1감소

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; BIOS read function 호출
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov ah, 0x02			; BIOS 서비스 번호2(Read Sector)
	mov al, 0x1			; 읽을 섹터 수는 1
	mov ch, byte [ TRACKNUMBER ]	; 읽을 트랙 번호 설정
	mov cl, byte [ SECTORNUMBER ]	; 읽을 섹터 번호 설정
	mov dh, byte [ HEADNUMBER ]	; 읽을 헤드 번호 설정
	mov dl, 0x00			; 읽을 드라이브 번호(0=플로피) 설정
	int 0x13			; 인터럽트 서비스 수행
	jc HANDLEDISKERROR		; 에러가 발생했다면 HANDLEDISKERROR로 이동

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 복사할 어드레스와 트랙, 헤드, 섹터 어드레스 계산
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	add si, 0x0020			; 512(0x200)바이트만큼 읽었으므로 이를 세그먼트레지스터 값으로 변환
	mov es, si			; es세그먼트 레지스터에 더해서 어드레스를 한 섹터 만큼 증가

	; 한섹터를 읽었으므로 섹터 번호를 증가시키고 마지막 섹터(18)까지 읽었는지 판단
	; 마지막 섹터가 아니면 섹터 읽기로 이동해서 다시 섹터 읽기 수행
	mov al, byte[ SECTORNUMBER ]	; 섹터번호를 al레지스터에 설정
	add al, 0x01			; 섹터 번호를 1증가
	mov byte[ SECTORNUMBER ], al	; 증가시킨 섹터번호를 SECTORNUMBER에 다시 설정
	cmp al, 19			; 증가시킨 섹터 번호를 19와 비교
	jl READDATA			; 섹터번호가 19미만이라면 READDATA로 이동

	; 마지막 섹터까지 읽었으면(섹터 번호가 19이면) 헤드를 토글(0->1, 1->0)하고, 섹터 번호를 1로 설정
	xor byte[ HEADNUMBER ], 0x01	; 헤드 번호를 0x01과 xor하여 토글(0->1, 1->0)
	mov byte[ SECTORNUMBER ], 0x01	; 섹터 번호를 다시 1로 설정

	; 만약 헤드가 1->0으로 바뀌었으면 양쪽 헤드를 모두 읽은 것이므로 아래로 이동하여
	; 트랙번호를 1증가
	cmp byte [ HEADNUMBER ], 0x00	; 헤드 번호를 0x00과 비교
	jne READDATA			; 헤드 번호가 0이 아니면 READDATA로 이동

	; 트랙을 1증가시킨 후 다시 섹터 읽기로 이동
	add byte [ TRACKNUMBER ], 0x01	; 트랙번호를 1증가
	jmp READDATA			; READDATA로 이동

READEND:
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; os이미지가 완료되었다는 메시지를 출력
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	push LOADINGCOMPLETEMESSAGE	; 출력할 메시지의 어드레스를 스택에 삽입
	push 1				; 화면 y좌표(1)를 스택에 삽입
	push 20				; 화면 x좌표(20)를 스택에 삽입
	call PRINTMESSAGE		; PRINTMESSAGE 함수 호출
	add sp, 6			; 삽입한 파라미터 제거
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 로딩한 가상 os이미지 실행
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	jmp 0x1000:0x0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 함수코드 입력
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 디스크 에러를 처리하는 함수
HANDLEDISKERROR:
	push DISKERRORMESSAGE	; 에러 문자열의 어드레스를 스택에 삽입
	push 1			; 화면 y좌표(1)를 스택에 삽입
	push 20			; 화면 x좌표(20)를 스택에 삽입
	call PRINTMESSAGE	; PRINTMESSAGE 함수 호출
	
	jmp $			; 현재위치에서 무한 루프 수행

; 메시지를 출력하는 함수
; PARAM: x좌표, y좌표, 문자열
PRINTMESSAGE:
	push bp		; 베이스포인터레지스터(BP)를 스택에 삽입
	mov bp, sp	; bp에 sp의 값을 설정
			; bp를 이용해서 파라미터에 접근할 목적
	
	push es		; es세그먼트 레지스터부터 dx레지스터까지 스택에 삽입
	push si		; 함수에서 임시로 사용하는 레지스터로 함수의 마지막 부분에서 스택에 삽입된 값을 꺼내 원래 값으로 복원
	push di
	push ax
	push cx
	push dx

	; es에 비디오 모드 어드레스 지정
	mov ax, 0xB800	; 비디오 메모리 시작 어드레스(0x0B8000)를 세그먼트 레지스터 값으로 변환
	mov es, ax	; es세그먼트 레지스터에 설정

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; x, y좌표로 비디오 메모리의 어드레스를 계산함
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; y좌표를 이용해서 먼저 라인 어드레스를 구함
	mov ax, word [ bp + 6 ]	; 파라미터 2(화면좌표 Y)를 ax레지스터에 설정
	mov si, 160		; 한 라인의 바이트 수(2*80컬럼)를 si에 설정
	mul si			; ax와 si를 곱하여 화면 y어드레스 계산
	mov di, ax		; 계산된 화면 y어드레스를 di에 설정

	; x좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
	mov ax, word [ bp +4 ]	; 파라미터 1(화면 좌표 x)를 ax레지스터에 설정
	mov si, 2		; 한문자를 나타내는 바이트 수(2)를 si에 설정
	mul si			; ax와 si를 곱하여 화면 x어드레스를 계산
	add di, ax		; 화면 y어드레스와 계산된 x어드레스를 더해서 실제 비디오 메모리 어드레스를 계산

	; 출력할 문자열의 어드레스
	mov si, word [ bp + 8 ]	; 파라미터 3(출력할 문자열의 어드레스)
	
.MESSAGELOOP:
	mov cl, byte [ si ]		; copy charactor which is on the address SI register's value
					; cl은 cx의 하위 1바이트를 의미
					; 문자는  1바이트면 충분하므로 cx레지스터의 하위 1바이트만 사용

	cmp cl, 0			; compare the charactor and 0
	je .MESSAGEEND			; if value is 0 -> string index is out of bound -> finish the routine

	mov byte [ es : di ], cl	; 0이 아니라면 비디오 메모리 어드레스 0xB800:di에 문자를 출력
	add si, 1			; go to next index
	add di, 2			; di 레지스터에 2를 더하여 비디오 메모리의 다음 문자 위치로 이동
					; 비디오 메모리는 (문자, 속성)의 쌍으로 구성되므로 문자만 출력하려면 2를 더해야함

	jmp .MESSAGELOOP        ; loop code

.MESSAGEEND:
	pop dx		; 함수에서 사용이 끝난 dx부터 es까지를 스택에 삽입된 값을 이용해서 복원
	pop cx		; pop(제거)
	pop ax
	pop di
	pop si
	pop es
	pop bp		; bp 복원
	ret		; 함수를 호출한 다음 코드의 위치로 복귀

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 데이터 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MESSAGE1:    db 'OS Boot Loader Start!!', 0 ; define the string tha I want to print

DISKERRORMESSAGE:	db 'DISK Error!', 0
IMAGELOADINGMESSAGE:	db 'OS image loading...', 0
LOADINGCOMPLETEMESSAGE:	db 'Complete!', 0

; 디스크 읽기에 관련된 변수들
SECTORNUMBER:		db 0x02	; os이미지가 시작하는 섹터번호를 저장하는 영역
HEADNUMBER:		db 0x00	; " 헤드번호를 "
TRACKNUMBER:		db 0x00	; " 트랙번호를 "

times 510 - ($ - $$)  db   0x00	; $ : current line's address
				; $$ : current section's base address
				; $ - $$ : offset!
				; 510 - ($ - $$) : offset to addr 510
				; db - 0x00 : declare 1byte and init to 0x00
				; time : loop
				; fill 0x00 from current address to 510

db 0x55 ; declare 1byte and init to 0x55
db 0xAA ; declare 1byte and init to 0xAA
	; Address 511 : 0x55
	; 512 : 0xAA -> declare that this sector is boot sector
