*==========================================================================
*
*	xsp_set_asm
*
*	引数：
*		d0.w = SP_x : スプライト X 座標
*		d1.w = SP_y : スプライト Y 座標
*		d2.w = SP_pt : スプライト PCG パターン No.（0～0x7FFF）
*		d3.w = SP_info : 反転コード・色・表示優先度を表すデータ
*
*	破壊：
*		d0 a0
*
*	戻り値：
*		d0.w
*			スプライト座標が画面外だったなら 0
*			それ以外の場合は 0 以外の値
*
*==========================================================================

_xsp_set_asm:
					* d0.w = SP_x
					* d1.w = SP_y
					* d2.w = SP_pt
					* d3.w = SP_info

	cmpi.w	#(XY_MAX<<SHIFT),d0	*[ 8]	X 座標画面外チェック
	bcc.b	XSP_SET_ASM_CANCEL	*[8,10]	XY_MAX <= SP_x ならキャンセル

	cmpi.w	#(XY_MAX<<SHIFT),d1	*[ 8]	Y 座標画面外チェック
	bcc.b	XSP_SET_ASM_CANCEL	*[8,10]	XY_MAX <= SP_y ならキャンセル

	movea.l	buff_pointer(pc),a0	*[16]	a0.l = 仮バッファポインタ
	tst.w	(a0)			*[ 8]	符号チェック
	bmi.b	XSP_SET_ASM_RETURN	*[8,10]	負ならバッファ終点と見なし終了

	*-------[ PUSH ]
		.if	SHIFT<>0
						*	d1 をビットシフトしないことで
						*	破壊レジスタを減らすことができる。
			swap	d0		*[ 4]	d0.l = SP_x,????
			move.w	d1,d0		*[ 4]	d0.l = SP_x,SP_y
			lsr.l	#SHIFT,d0	*[8+2n]	固定小数ビット数分のシフト
						*	SP_x の下位ビットが SP_y 上位ビットに
						*	漏れだすので注意。
			move.l	d0,(a0)+	*[12]	SP_x,SP_y を転送
			.if	COMPATIBLE<>0
						*	d0.l = SP_x,SP_y
						* 過去の動作との互換にするには swap が必要
				swap	d0	*[ 4]	d0.l = SP_y,SP_x
			.endif
		.else
			move.w	d0,(a0)+	*[ 8]	SP_x を転送
			move.w	d1,(a0)+	*[ 8]	SP_y を転送
		.endif
		move.w	d2,(a0)+		*[ 8]	SP_pt を転送
		move.w	d3,(a0)+		*[ 8]	SP_info を転送

		move.l	a0,buff_pointer		*[12]	仮バッファポインタの保存

XSP_SET_ASM_RETURN:
						* d0.w = SP_x
	rts

XSP_SET_ASM_CANCEL:
	moveq	#0,d0			*[ 4]	画面外なので、戻り値 = 0
	rts




*==========================================================================
*
*	xsp_set_st_asm
*
*	引数：
*		a0.l = パラメータ構造体のポインタ
*
*	戻り値：
*		d0.w
*			スプライト座標が画面外だったなら 0
*			それ以外の場合は 0 以外の値
*
*	破壊：
*		a0 a1
*
*	パラメータ構造体
*	+0.w : スプライト x 座標
*	+2.w : スプライト y 座標
*	+4.w : スプライト PCG パターン No.（0～0x7FFF）
*	+6.w : 反転コード・色・表示優先度を表すデータ（xsp_set 関数の、
*	       引数 info に相当）
*
*==========================================================================

_xsp_set_st_asm:
						* a0.l = 構造体アドレス

	move.l	(a0)+,d0			*[12]	d0.l = SP_x,SP_y

	cmpi.l	#(XY_MAX<<(SHIFT+16)),d0	*[14]	X 座標画面外チェック
	bcc.b	XSP_SET_ST_ASM_CANCEL		*[8,10]	XY_MAX <= SP_x ならキャンセル
	cmpi.w	#(XY_MAX<<SHIFT),d0		*[ 8]	Y 座標画面外チェック
	bcc.b	XSP_SET_ST_ASM_CANCEL		*[8,10]	XY_MAX <= SP_y ならキャンセル

	movea.l	buff_pointer(pc),a1		*[16]	a1.l = 仮バッファポインタ
	tst.w	(a1)				*[ 8]	符号チェック
	bmi.b	XSP_SET_ST_ASM_RETURN		*[8,10]	負ならバッファ終点と見なし終了

	*-------[ PUSH ]
		.if	SHIFT<>0
			lsr.l	#SHIFT,d0	*[8+2n]	固定小数ビット数分のシフト
						*	SP_x の下位ビットが SP_y 上位ビットに
						*	漏れだすので注意。
		.endif

		move.l	d0,(a1)+		*[12]	SP_x,SP_y を転送
		move.l	(a0)+,(a1)+		*[20]	SP_pt,info を転送

		move.l	a1,buff_pointer		*[20]	仮バッファポインタの保存

XSP_SET_ST_ASM_RETURN:
	.if	COMPATIBLE<>0
					*	d0.l = SP_x,SP_y
					* 過去の動作との互換にするには swap が必要
		swap	d0		*[ 4]	d0.w = SP_x
	.endif
					* d0.w = SP_x
	rts

XSP_SET_ST_ASM_CANCEL:
	moveq	#0,d0			*[ 4]	画面外なので、戻り値 = 0
	rts




*==========================================================================
*
*	xobj_set_asm
*
*	引数：
*		d0.w = SP_x : 複合スプライトの X 座標
*		d1.w = SP_y : 複合スプライトの Y 座標
*		d2.w = SP_pt : 複合スプライトの形状パターン No.（0～0x0FFF）
*		d3.w = SP_info : 反転コード・色・表示優先度を表すデータ
*
*	破壊：
*		d0 d1 d2 d3 d4 a0 a1 a2
*
*	戻り値：無し
*
*==========================================================================
*
*	xobj_set_st_asm
*
*	引数：
*		a0.l = パラメータ構造体のポインタ
*
*	破壊：
*		d0 d1 d2 d3 d4 a0 a1 a2
*
*	戻り値：無し
*
*	パラメータ構造体
*	+0.w : 複合スプライトの x 座標
*	+2.w : 複合スプライトの y 座標
*	+4.w : 複合スプライトの形状パターン No.
*	+6.w : 反転コード・色・表示優先度を表すデータ
*
*==========================================================================


*-------[ マクロの定義 ]

OBJ_WRITE_ASM:	.macro	RV10,RV01
		.local	OBJ_LOOP
		.local	NEXT_OBJ
		.local	EXIT_OBJ_LOOP
		.local	SKIP_OBJ_PUSH_1
		.local	SKIP_OBJ_PUSH_2

					* さり気なくループ 2 倍展開
		lsr.w	#1,d4
		bcc.b	NEXT_OBJ

OBJ_LOOP:
		.if	RV01=0
			add.w	(a1)+,d0	* SP_x += vx
		.else
			sub.w	(a1)+,d0	* SP_x -= vx
		.endif

		.if	RV10=0
			add.w	(a1)+,d1	* SP_y += vy
		.else
			sub.w	(a1)+,d1	* SP_y -= vy
		.endif

		cmp.w	a2,d0
		bcc.b	SKIP_OBJ_PUSH_1		* MAX座標 <= SP_x なら push せず
		cmp.w	a2,d1
		bcc.b	SKIP_OBJ_PUSH_1		* MAX座標 <= SP_y なら push せず

		move.w	d0,(a0)+		* SP_x を転送
		move.w	d1,(a0)+		* SP_y を転送

		move.l	(a1)+,d2		*[12] d2.l = PT RV
		eor.w	d3,d2			*[ 4] d2.w = 反転加工済 info
		move.l	d2,(a0)+		*[12] PT RV を転送

	NEXT_OBJ:

		.if	RV01=0
			add.w	(a1)+,d0	* SP_x += vx
		.else
			sub.w	(a1)+,d0	* SP_x -= vx
		.endif

		.if	RV10=0
			add.w	(a1)+,d1	* SP_y += vy
		.else
			sub.w	(a1)+,d1	* SP_y -= vy
		.endif

		cmp.w	a2,d0
		bcc.b	SKIP_OBJ_PUSH_2		* MAX座標 <= SP_x なら push せず
		cmp.w	a2,d1
		bcc.b	SKIP_OBJ_PUSH_2		* MAX座標 <= SP_y なら push せず

		move.w	d0,(a0)+		* SP_x を転送
		move.w	d1,(a0)+		* SP_y を転送

		move.l	(a1)+,d2		*[12] d2.l = PT RV
		eor.w	d3,d2			*[ 4] d2.w = 反転加工済 info
		move.l	d2,(a0)+		*[12] PT RV を転送

		dbra.w	d4,OBJ_LOOP

EXIT_OBJ_LOOP:
	*-------[ 終了 ]
		move.l	a0,buff_pointer		* バッファポインタ保存
		rts


SKIP_OBJ_PUSH_1:
	addq.w	#4,a1
	bra.b	NEXT_OBJ

SKIP_OBJ_PUSH_2:
	addq.w	#4,a1
	dbra.w	d4,OBJ_LOOP
	bra.b	EXIT_OBJ_LOOP

		.endm

*------------------------



OBJ_SET_ASM_RETURN:
	rts


_xobj_set_st_asm:
					*	a0.l = 構造体アドレス
	movem.w	(a0),d0-d3		*[8+4n]	d0.w = SP_x
					*	d1.w = SP_y
					*	d2.w = 複合スプライトpt
					*	d3.w = SP_info
					*	a0.l は用済み

_xobj_set_asm:
					* d0.w = SP_x
					* d1.w = SP_y
					* d2.w = 複合スプライト pt
					* d3.w = SP_info


*-------[ 参照すべき sp_ref のアドレスを求める ]
	lsl.w	#3,d2			* d2.w *= 8
	movea.l	sp_ref_adr(pc),a1	* a1.l = sp_ref_adr
	adda.w	d2,a1			* a1.w += pt*8
					* a1.l = 参照すべき sp_ref のアドレス
					* d2.w は 用済み


*-------[ 必要合成スプライト数を求める ]
	movea.l	buff_pointer(pc),a0
	move.l	#buff_end_adr_no_pc,d4	* d4.l = #buff_end_adr_no_pc（move.w が使えると良いが・・・）
	sub.w	a0,d4			* d4.w -= a0.w
	asr.w	#3,d4			* d4.w /= 8
					* d4.w = push可能スプライト数(1～)
	cmp.w	(a1)+,d4		* 
	ble.b	@F			* 必要合成スプライト数 >= d4 なら bra
		move.w	-2(a1),d4	* d4.w = 必要合成スプライト数
@@:
	sub.w	#1,d4			* d4.w を dbra カウンタとするため -1 する。
	bmi.b	OBJ_SET_ASM_RETURN	* 必要合成スプライト数 <= 0 なら強制終了する


*-------[ その他の初期化 ]
	.if	SHIFT<>0
		asr.w	#SHIFT,d0
		asr.w	#SHIFT,d1
	.endif
					*------------------------------------------------------
					* d0.w = SP_x
					* d1.w = SP_y
					* d2.l = temp
					* d3.w = SP_info
					* d4.w = 必要合成スプライト数 - 1（dbra カウンタとする）
					*------------------------------------------------------
					* a0.l = push 先
	movea.l	(a1),a1			* a1.l = sp_frm 読み出し開始アドレス
	move.w	#XY_MAX,a2		* a2.l = XY 座標上限値
					*------------------------------------------------------


*=======[ スプライト合成 ]

	move.w	d3,d2
	bmi	RV_1x_asm			* 上下反転：１ なので bra

	*=======[ 上下反転：0  左右反転：? ]
RV_0x_asm:	add.w	d2,d2
		bmi.b	RV_01_asm		* 左右反転：1 なので bra

		*-------[ 上下反転：0  左右反転：0 ]
	RV_00_asm:	OBJ_WRITE_ASM	0,0

		*-------[ 上下反転：0  左右反転：1 ]
	RV_01_asm:	OBJ_WRITE_ASM	0,1

	*=======[ 上下反転：1  左右反転：? ]
RV_1x_asm:	add.w	d2,d2
		bmi.b	RV_11_asm			* 左右反転：1 なので bra

		*-------[ 上下反転：1  左右反転：0 ]
	RV_10_asm:	OBJ_WRITE_ASM	1,0

		*-------[ 上下反転：1  左右反転：1 ]
	RV_11_asm:	OBJ_WRITE_ASM	1,1


