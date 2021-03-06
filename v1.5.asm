;;------------------------
;;TrafLight v1.5
;;by SN icetiny@gmail.com
;;2011-6-10
;;完成键盘基本功能
;;
;;------------------------
;;R0	 R1			  R2			  R3 			R6		  R7	  R5			 R4
;;灯状态 临时使用 2红灯倒计时	  1绿灯倒计时    秒状态数码	 分状态	  空	 屏状态（0开1选段2调时间3调高位时间）
;;------------------------
;;30H  31H  32H-35H	   36H            37H			38H		 39H	  			 3AH         3BH     3CH			位7F	   3DH
;;绿灯 红灯	灯状态地址 减一用  当前小时状态码  LED显示寄存器 数码管地址高八位	 屏段(HEX码) 屏绿灯 屏红灯（BCD码）	选位标志   BCDINC和BCDDEC子程序的操作位
;;------------------------
;;50H-7FH			  40H 41H
;;用户定义灯状态	  delay10中用到的变量
;;------------------------
;;键盘 1        2       3          4  5
;;	  on/off   ok/next	<>选位	   +  -
;;------------------------


		ORG 0000H
		AJMP MAIN
;----------------INTERRUPT VECTORS--------------------------
		;ORG 0003H ;外部中断0
		ORG 000BH							
		AJMP INT_TO							
		ORG 0013H ;外部中断1						
		AJMP INT_EX1							
		ORG 001BH							
		AJMP INT_C1							
;------------DEFINE CONSTANT VALUE--------------------------
		LDD1 EQU 0f8H ;数码管地址
		LDD2 EQU 0f9H
		LDD3 EQU 0faH
		LDD4 EQU 0fbH
		LDD5 EQU 0fcH
		LDD6 EQU 0fdH
		LED  EQU 0feH ;灯地址
		G_R1 EQU 1100B
		Y_R2 EQU 1010B
		R_G3 EQU 100001B
		R_Y4 EQU 10001B
		SECS_PER_MIN EQU 2  ;每分中的秒数，调试用
		MINS_PER_HOUR EQU 3 ;每小时中的分数，调试用																							
;-----------------------------------------------------------	
;;--------------MAIN PROGRAM BEGIN---------------------------
		ORG 0030H				 
MAIN:	
		MOV SP,#10H
		MOV 32H,#G_R1
		MOV 33H,#Y_R2
		MOV 34H,#R_G3
		MOV 35H,#R_Y4
		MOV TMOD,#61H	;初始化计时器 定时器0方式1 计数器1方式2
		MOV TH0,#1FH	;2^16-57600 = 7936 = 1F00 12*2*8*57600=11.0592MHz
		MOV TL0,#00H
		MOV TH1,#0F8H
		MOV TL1,#0F8H	;8. 1S ;	
		MOV R6,#SECS_PER_MIN ;每分中的秒数，调试用
		MOV R7,#MINS_PER_HOUR ;每小时中的分数，调试用
		MOV 37H,#23	;初始化当前时间（小时状态）
		MOV 7EH,#03H	;测试RAM中红绿灯时间表用
		MOV 7FH,#00H
		LCALL GET_LIGHT_TIME ;获取倒计时时间
		MOV R0,#32H	;R0记录信号灯寄存器状态
		MOV R3,30H
		MOV R2,31H
		LCALL CHANGE_LIGHT	;开信号灯
		MOV 38H,R3	   ;送显示，开数码管
		MOV 39H,#LDD2
		LCALL DISPLAY_NUMBER
		MOV 38H,R2
		MOV 39H,#LDD4
		LCALL DISPLAY_NUMBER
		;中断优先级处理，待完成
		MOV IP,#00001010B
		SETB ET0
		SETB ET1
		SETB EX1
		SETB IT1
		SETB EA
		SETB TR0
		SETB TR1
		;初始化完毕，开始计时
		SJMP $
;;-------------- END OF MAIN -----------------
INT_TO:								;计时器0中断处理程序
		MOV TH0,#1FH 
		MOV TL0,#00H
		CPL P3.5 
		RETI
		
INT_C1:								;计数器1中断处理程序
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
		MOV 38H,R3	   ;送显示
		MOV 39H,#LDD2
		LCALL DISPLAY_NUMBER
		MOV 38H,R2
		MOV 39H,#LDD4
		LCALL DISPLAY_NUMBER
		DJNZ R6,INT_C1_EXIT1
		MOV R6,#SECS_PER_MIN
		DJNZ R7,INT_C1_EXIT1
		MOV R7,#MINS_PER_HOUR
		INC 37H
		MOV A,37H
		CJNE A,#24,INT_C1_EXIT0
		MOV 37H,#0
INT_C1_EXIT0:
		LCALL GET_LIGHT_TIME
INT_C1_EXIT1:
		POP ACC
		RETI
;-------------按键中断处理程序----------------
INT_EX1:							;外部中断1处理，键盘
		PUSH PSW
		PUSH ACC
		MOV A,P2   ;判断是否有键按下
		ANL A,#0F8H
		XRL A,#0F8H
		JZ INT_EX1_EXIT 
		LCALL DELAY10
		MOV A,P2   ;再次判断是否有键按下,消除前沿抖动
		ANL A,#0F8H
		XRL A,#0F8H
		JZ INT_EX1_EXIT
		JB ACC.3,KEY01
		JB ACC.4,KEY02
		JB ACC.5,KEY03
		JB ACC.6,KEY04
		JB ACC.7,KEY05
		KEY01:LJMP KEY1
		KEY02:LJMP KEY2		
		KEY03:LJMP KEY3
		KEY04:LJMP KEY4
		KEY05:LJMP KEY5
INT_EX1_EXIT:
		LCALL DELAY10
		MOV A,P2   ;判断是否有键按下，消除后沿抖动
		ANL A,#0F8H
		XRL A,#0F8H
		JZ INT_EX1_EXIT_1
		SJMP INT_EX1_EXIT
INT_EX1_EXIT_1:
		POP ACC
		POP PSW
		RETI

KEY1: ;开关键
		CJNE R4,#00,KEY1_NEXT1
		MOV R4,#1		 ;开启屏
		MOV 3AH,37H 
		MOV 38H,3AH
		LCALL HEX2BCD
		MOV 39H,#LDD6
		LCALL DISPLAY_NUMBER
		LJMP INT_EX1_EXIT
KEY1_NEXT1:
		MOV R4,#0		 ;关闭屏  
		MOV 3AH,#0
		MOV 3BH,#0
		MOV 3CH,#0
		MOV 38H,#0FFH
		MOV 39H,#LDD6
		LCALL DISPLAY_NUMBER 
		LJMP INT_EX1_EXIT

KEY2:	;确认键，OK键
		MOV A,R4
		MOV R1,A
		CJNE R1,#0,KEY2_R01
 		LJMP INT_EX1_EXIT
KEY2_R01:		DJNZ R1,KEY2_R02
				LJMP KEY2_R1
KEY2_R02:		DJNZ R1,KEY2_R03
				LJMP KEY2_R2
KEY2_R03:		DJNZ R1,INT_EX1_EXIT
				LJMP KEY2_R3
KEY2_R1:
		INC R4
		MOV 38H,3BH
		MOV 39H,#LDD6
		LCALL DISPLAY_NUMBER
		LJMP INT_EX1_EXIT
KEY2_R2:
		INC R4
		MOV 38H,3CH
		MOV 39H,#LDD6
		LCALL DISPLAY_NUMBER
		LJMP INT_EX1_EXIT
KEY2_R3:
		MOV R4,#1
		MOV 38H,3AH
		LCALL HEX2BCD
		MOV 39H,#LDD6
		LCALL DISPLAY_NUMBER
		MOV A,3AH
		RL A
		ADD A,#50H
		XCH A,R1
		MOV @R1,3BH
		INC R1
		MOV @R1,3CH
		LJMP INT_EX1_EXIT

KEY3:	CPL 7FH						;选位数
		LJMP INT_EX1_EXIT

KEY4:			         ;加一
		MOV A,R4		
		MOV R1,A
		CJNE R1,#0,KEY4_R01
 		LJMP INT_EX1_EXIT
KEY4_R01:		DJNZ R1,KEY4_R02
				INC 3AH
				MOV A,3AH
				CJNE A,#24,KEY4_R01_next
				MOV 3AH,#0
KEY4_R01_next:	MOV 38H,3AH
				LCALL HEX2BCD
				MOV 39H,#LDD6
				LCALL DISPLAY_NUMBER
				LJMP INT_EX1_EXIT
KEY4_R02:		DJNZ R1,KEY4_R03
				MOV 3DH,3BH
				LCALL BCDINC
				MOV 3BH,3DH
				MOV 38H,3BH
				MOV 39H,#LDD6
				LCALL DISPLAY_NUMBER
				LJMP INT_EX1_EXIT
KEY4_R03:		DJNZ R1,KEY4_EXIT
				MOV 3DH,3CH
				LCALL BCDINC
				MOV 3CH,3DH
				MOV 38H,3CH
				MOV 39H,#LDD6
				LCALL DISPLAY_NUMBER
KEY4_EXIT:		LJMP INT_EX1_EXIT				  		

KEY5: 			MOV A,R4		;减一
				MOV R1,A
				CJNE R1,#0,KEY5_R01
 				LJMP INT_EX1_EXIT
KEY5_R01:		DJNZ R1,KEY5_R02
				MOV A,3AH
				CJNE A,#0,KEY5_R01_next
				MOV 3AH,#24
KEY5_R01_next:	DEC 3AH
				MOV 38H,3AH
				LCALL HEX2BCD
				MOV 39H,#LDD6
				LCALL DISPLAY_NUMBER
				LJMP INT_EX1_EXIT
KEY5_R02:		DJNZ R1,KEY5_R03
				MOV 3DH,3BH
				LCALL BCDDEC
				MOV 3BH,3DH
				MOV 38H,3BH
				MOV 39H,#LDD6
				LCALL DISPLAY_NUMBER
				LJMP INT_EX1_EXIT
KEY5_R03:		DJNZ R1,KEY5_EXIT
				MOV 3DH,3CH
				LCALL BCDDEC
				MOV 3CH,3DH
				MOV 38H,3CH
				MOV 39H,#LDD6
				LCALL DISPLAY_NUMBER
KEY5_EXIT:		LJMP INT_EX1_EXIT

BCDINC:	PUSH ACC
		MOV A,3DH
		JB 7FH,BCDINC_HIGH
		ANL A,#0FH
		CJNE A,#09H,BCDINC_LOW1
		ANL 3DH,#0F0H
		LJMP BCDINC_EXIT
BCDINC_LOW1:
		INC 3DH
		LJMP BCDINC_EXIT
BCDINC_HIGH:
		ANL A,#0F0H
		CJNE A,#90H,BCDINC_HIGH1
		ANL 3DH,#0FH
		LJMP BCDINC_EXIT
BCDINC_HIGH1:
		MOV A,3DH
		ADD A,#10H
		MOV 3DH,A
BCDINC_EXIT:		
		POP ACC
		RET
		
BCDDEC:	PUSH ACC
		MOV A,3DH
		JB 7FH,BCDDEC_HIGH
		ANL A,#0FH
		CJNE A,#00H,BCDDEC_LOW1
		ORL 3DH,#09H
		LJMP BCDDEC_EXIT
BCDDEC_LOW1:
		DEC 3DH
		LJMP BCDDEC_EXIT
BCDDEC_HIGH:
		ANL A,#0F0H
		CJNE A,#00H,BCDDEC_HIGH1
		ORL 3DH,#90H
		LJMP BCDDEC_EXIT
BCDDEC_HIGH1:
		MOV A,3DH
		SUBB A,#10H
		MOV 3DH,A
BCDDEC_EXIT:
		POP ACC	
		RET
;-------------END OF 按键中断处理程序----------------

DELAY10:
		NOP
		MOV 40H,#9
DL10_1: MOV 41H,#255
DL10_2: NOP
		NOP
		DJNZ 41H,DL10_2
		DJNZ 40H,DL10_1
		NOP
		RET

HEX2BCD:			  ;将38H中的16进制数转为BCD码
		PUSH ACC
		MOV A,38H
		MOV B,#10
		DIV AB
		SWAP A
		ORL A,B
		MOV 38H,A
		POP ACC
		RET

GET_LIGHT_TIME:							;获取当前红绿灯时间子程序，存入30h和31h
		PUSH DPH
		PUSH DPL
		PUSH ACC
		PUSH PSW
		SETB RS0		         
		MOV DPTR,#TAB_LIGHT_TIME ;读入信号灯延时信息,30H为绿灯，31H为红灯
		MOV A,37H
		RL A
		MOVC A,@A+DPTR
		MOV 30H,A
		MOV A,37H
		RL A
		INC A
		MOVC A,@A+DPTR
		MOV 31H,A	
		;检查是否有用户自定义数据
		MOV A,37H
		RL A
		ADD A,#50H
		MOV R0,A
		INC A
		MOV R1,A
		MOV A,@R0  
		ORL A,@R1
		JZ GET_LIGHT_TIME_EXIT ;若全为零，说明无用户定义数据，直接跳出
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
		MOV A,@R0 ;检查用户定义数据是否完整，不完整则以默认数据补充(默认为，红灯比绿灯长3秒) 
		ANL A,@R1
		JNZ GET_LIGHT_TIME_EXIT	;若有一个为零，则更改其为默认值
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
		RET
;--------------------
CHANGE_LIGHT:				;开信号灯子程序
		PUSH DPH
		PUSH ACC
		MOV DPH,#LED
		MOV A,@R0
		MOVX @DPTR,A
		POP ACC
		POP DPH
		RET
;-------------------------
DISPLAY_NUMBER:				;显示倒计时数字子程序，显示38H中的数字到39H指定的地址中 先显示低位，再显示高位
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
;-----------------------------
GETDIGIT:					;取段码子程序
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
;--------------------------------				
DISDIGIT:					;送数码管显示子程序
		PUSH ACC
		MOV	A,38H
		MOVX @DPTR,A
		POP ACC 
		RET
;------------------------------
SUBBCD:						;BCD码减一,对36H中的数做BCD码减1
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
		RET
;;------------TABLES----------------			                 
DIGIT:							;LED数码管段码表
		DB 3FH,06H,5BH,4FH,66H
		DB 6DH,7DH,07H,7FH,6FH
		DB 77H,7CH,39H,5EH,79H,00H
TAB_LIGHT_TIME:  				;预设的信号灯时间常数，共24行，48个值
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
;----------- END --------------------
END