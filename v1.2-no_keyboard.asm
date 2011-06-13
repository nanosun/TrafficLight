;;------------------------
;;TrafLight v1.3
;;by SN icetiny@gmail.com
;;2011-6-8
;;����ʾ����Ҳ��Ϊͨ�ó���ֵ�洢��38H,��ַ�洢��39H
;;------------------------
;;R0	 R1			  R2			  R3 			R6		  R7
;;��״̬ ��ʱʹ�� 2��Ƶ���ʱ	  1�̵Ƶ���ʱ    ��״̬����	 ��״̬
;;------------------------
;;30H  31H  32H-35H	   36H            37H			38H		 39H	  
;;�̵� ���	��״̬��ַ ��һ��  ��ǰСʱ״̬��  LED��ʾ�Ĵ��� ����ܵ�ַ�߰�λ
;;------------------------
;;40H-6FH
;;�û������״̬
;;------------------------
		ORG 0000H
		AJMP MAIN
;INTERRUPT VECTORS
		ORG 000BH							
		AJMP INT_TO							
		;ORG 0013H							
		;AJMP INT_EX1							
		ORG 001BH							
		AJMP INT_C1							
;DEFINE CONSTANT VALUE
		LDD1 EQU 00H ;����ܵ�ַ
		LDD2 EQU 01H
		LDD3 EQU 02H
		LDD4 EQU 03H
		LDD5 EQU 04H
		LDD6 EQU 05H
		LED  EQU 06H ;�Ƶ�ַ
		G_R1 EQU 1100B
		Y_R2 EQU 1010B
		R_G3 EQU 100001B
		R_Y4 EQU 10001B
		SECS_PER_MIN EQU 2 ;ÿ���е�������������
		MINS_PER_HOUR EQU 5 ;ÿСʱ�еķ�����������																							
	
;MAIN PROGRAM BEGIN
		ORG 0030H
MAIN:	
		MOV SP,#10H
		MOV 32H,#G_R1
		MOV 33H,#Y_R2
		MOV 34H,#R_G3
		MOV 35H,#R_Y4
		
		MOV TMOD,#61H	;��ʼ����ʱ�� ��ʱ��0��ʽ1 ������1��ʽ2
		MOV TH0,#1FH	;2^16-57600 = 7936 = 1F00
		MOV TL0,#00H
		MOV TH1,#0F8H
		MOV TL1,#0F8H	;8. 12*2*8*57600=11.0592MHz ;	

		MOV 37H,#0	;��ʼ����ǰʱ�䣨Сʱ״̬��
		;MOV 6EH,#52H	;����RAM�к��̵�ʱ�����
		;MOV 6FH,#00H
		LCALL GET_LIGHT_TIME
		MOV R0,#32H	;R0��¼�źŵƼĴ���״̬
		MOV R3,30H
		MOV R2,31H
		LCALL CHANGE_LIGHT	;���źŵ�
		SETB ET0
		SETB ET1
		SETB EA
		SETB TR0
		SETB TR1
		SJMP $

INT_TO:								;��ʱ��0�жϴ�������
		MOV TH0,#1FH 
		MOV TL0,#00H
		CPL P3.5 
		RETI
		
INT_C1:								;������1�жϴ�������
		PUSH ACC
		MOV 36H,R3
		LCALL SUBBCD
		MOV R3,36H
		MOV 36H,R2
		LCALL SUBBCD
		MOV R2,36H
		CJNE R2,#0F9H,INT_C1_NEXT2
		INC R0
		CJNE R0,#36H,INT_C1_NEXT0
		MOV R0,#32H
		LCALL CHANGE_LIGHT
		MOV R3,30H
		MOV R2,31H
		SJMP INT_C1_EXIT
INT_C1_NEXT0:
		CJNE R0,#34H,INT_C1_NEXT1
		LCALL CHANGE_LIGHT
		MOV R3,31H
		MOV R2,30H
		SJMP INT_C1_EXIT
INT_C1_NEXT1:
		CJNE R0,#35H,INT_C1_NEXT2
		LCALL CHANGE_LIGHT
		MOV A,R3
		XCH A,R2
		SJMP INT_C1_EXIT
INT_C1_NEXT2:
		CJNE R3,#0F9H,INT_C1_EXIT
		INC R0
		LCALL CHANGE_LIGHT
		MOV A,R2
		XCH A,R3
INT_C1_EXIT:
		MOV 38H,R3	   ;����ʾ
		MOV 39H,#LDD2
		LCALL DISPLAY_NUMBER
		MOV 38H,R2
		MOV 39H,#LDD4
		LCALL DISPLAY_NUMBER
		INC R6	 ;����
		CJNE R6,#SECS_PER_MIN,INT_C1_EXIT1
		MOV R6,#00H
		INC R7
INT_C1_EXIT1:
		CJNE R7,#MINS_PER_HOUR,INT_C1_EXIT2
		MOV R7,#00H
		INC 37H
		LCALL GET_LIGHT_TIME
INT_C1_EXIT2:
		POP ACC
		RETI

GET_LIGHT_TIME:							;��ȡ��ǰ���̵�ʱ���ӳ��򣬴���30h��31h
		PUSH DPH
		PUSH DPL
		PUSH ACC
		PUSH PSW
		SETB RS0		         
		MOV DPTR,#TAB_LIGHT_TIME ;�����źŵ���ʱ��Ϣ,30HΪ�̵ƣ�31HΪ���
		MOV A,37H
		RLC A
		MOVC A,@A+DPTR
		MOV 30H,A
		MOV A,37H
		RLC A
		INC A
		MOVC A,@A+DPTR
		MOV 31H,A	
		;����Ƿ����û��Զ�������
		MOV A,37H
		RLC A
		ADD A,#40H
		MOV R0,A
		INC A
		MOV R1,A
		MOV A,@R0  
		ORL A,@R1
		JZ GET_LIGHT_TIME_EXIT ;��ȫΪ�㣬˵�����û��������ݣ�ֱ������
		CJNE @R0,#00H,GET_LIGHT_TIME_NEXT1
		AJMP GET_LIGHT_TIME_NEXT2
GET_LIGHT_TIME_NEXT1:
		MOV 30H,@R0
GET_LIGHT_TIME_NEXT2:
		CJNE @R1,#00H,GET_LIGHT_TIME_NEXT3
		AJMP GET_LIGHT_TIME_FILL1
GET_LIGHT_TIME_NEXT3:
		MOV 31H,@R1
GET_LIGHT_TIME_FILL1:
		MOV A,@R0 ;����û����������Ƿ�����������������Ĭ�����ݲ���(Ĭ��Ϊ����Ʊ��̵Ƴ�3��) 
		ANL A,@R1
		JNZ GET_LIGHT_TIME_EXIT	;����һ��Ϊ�㣬�������ΪĬ��ֵ
		CJNE @R0,#00H,GET_LIGHT_TIME_FILL2
		MOV 36H,@R1
		LCALL SUBBCD
		LCALL SUBBCD
		LCALL SUBBCD
		MOV 30H,36H
GET_LIGHT_TIME_FILL2:
		CJNE @R1,#00H,GET_LIGHT_TIME_EXIT
		MOV A,@R0
		CLR CY
		ADD A,#3
		DA A
		MOV 31H,A
GET_LIGHT_TIME_EXIT:
		CLR RS0
		POP PSW
		POP ACC
		POP DPL
		POP DPH
		RETI

CHANGE_LIGHT:				;���źŵ��ӳ���
		PUSH DPH
		PUSH ACC
		MOV DPH,#LED
		MOV A,@R0
		MOVX @DPTR,A
		POP ACC
		POP DPH
		RET

DISPLAY_NUMBER:				;��ʾ����ʱ�����ӳ�����ʾ38H�е����ֵ�39Hָ���ĵ�ַ�� ����ʾ��λ������ʾ��λ
		PUSH ACC
		MOV A,38H
		ANL 38H,#0FH
		LCALL GETDIGIT
		MOV DPH,39H
		LCALL DISDIGIT
		SWAP A
		MOV 38H,A
		ANL 38H,#0FH
		LCALL GETDIGIT
		DEC 39H
		MOV DPH,39H
		LCALL DISDIGIT
		POP ACC
		RET

GETDIGIT:					;ȡ�����ӳ���
		PUSH DPH
		PUSH DPL
		PUSH ACC
		MOV DPTR,#DIGIT
		MOV A,38H
		MOVC A,@A+DPTR
		XCH A,38H
		POP ACC
		POP DPL
		POP DPH
		RET
				
DISDIGIT:					;���������ʾ�ӳ���
		PUSH ACC
		MOV	A,38H
		MOVX @DPTR,A
		POP ACC 
		RET

SUBBCD:						;BCD���һ,��36H�е�����BCD���1
		PUSH ACC
		PUSH PSW
		DEC 36H
		MOV A,36H
		ANL A,#0FH
		CJNE A,#0FH,SUBBCD_EXIT
		CLR CY
		MOV A,36H
		SUBB A,#06
		MOV 36H,A
SUBBCD_EXIT:
		POP PSW
		POP ACC
		RETI
			                 
DIGIT:							;LED����ܶ����
		DB 3FH,06H,5BH,4FH,66H
		DB 6DH,7DH,07H,7FH,6FH
		DB 77H,7CH,39H,5EH,79H,71H
TAB_LIGHT_TIME:  				;Ԥ����źŵ�ʱ�䳣������24�У�48��ֵ
		DB 02H, 05H
		DB 11H, 14H
		DB 03H, 06H
		DB 04H, 07H
		DB 05H, 08H
		DB 06H, 09H
		DB 01H, 10H
		DB 02H, 11H
		DB 03H, 05H
		DB 04H, 06H
		DB 05H, 07H
		DB 06H, 08H
		DB 01H, 03H
		DB 02H, 04H
		DB 03H, 05H
		DB 04H, 06H
		DB 05H, 07H
		DB 06H, 08H
		DB 01H, 03H
		DB 02H, 04H
		DB 03H, 05H
		DB 04H, 06H
		DB 05H, 07H
		DB 24H, 26H
;end-----------------------------
END