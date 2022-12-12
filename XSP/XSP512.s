*==========================================================================
*
*	512 枚モード・ソーティングルーチン（優先度保護機能なし）
*
*==========================================================================



*==========================================================================
*
*	マクロ定義
*
*==========================================================================

*--------------------------------------------------------------------------

SORT_512_An	.macro	An
		.local	end_mark

	*=======[ ラスタ分割バッファに登録 ]
		tst.w	(An)			*[12]	バッファチェック
		bmi.b	end_mark		*[8,10]	負なら終点なので飛ばす
		move.l	d0,(An)+		*[12]	x,y 転送
		move.l	(a0)+,(An)+		*[20]	cd,pr 転送
		dbra	d7,SORT_512_LOOP
@@:
		movea.l	CHAIN_OFS-4(a0),a0	* 次の PR 鎖アドレス
		move.w	CHAIN_OFS(a0),d7	* 連鎖数（そのまま dbcc カウンタとして使える）
		bpl	SORT_512_LOOP		* 連鎖数 >= 0 なら続行
	*-------[ PR 変更 ]
		move.l	(a7)+,a0		* 次の PR の先頭アドレス
		move.w	CHAIN_OFS(a0),d7	* 連鎖数（そのまま dbcc カウンタとして使える）
		bpl	SORT_512_LOOP		* 連鎖数 >= 0 なら続行
		bra	SORT_512_END		* 終了

	*-------[ 終点に達した ]
end_mark:	addq.w	#4,a0			* ポインタ補正（cd,pr を飛ばす）
		dbra	d7,SORT_512_LOOP
		bra.b	@B

		.endm

*--------------------------------------------------------------------------

SORT_512_Dn	.macro	Dn
		.local	end_mark

	*=======[ ラスタ分割バッファに登録 ]
		movea.l	Dn,a2			*[ 4]	a2.l = Dn.l
		tst.w	(a2)			*[12]	バッファチェック
		bmi.b	end_mark		*[8,10]	負なら終点なので飛ばす
		move.l	d0,(a2)+		*[12]	x,y 転送
		move.l	(a0)+,(a2)+		*[20]	cd,pr 転送
		move.l	a2,Dn			*[ 4]	Dn.l に戻す
		dbra	d7,SORT_512_LOOP
@@:
		movea.l	CHAIN_OFS-4(a0),a0	* 次の PR 鎖アドレス
		move.w	CHAIN_OFS(a0),d7	* 連鎖数（そのまま dbcc カウンタとして使える）
		bpl	SORT_512_LOOP		* 連鎖数 >= 0 なら続行
	*-------[ PR 変更 ]
		move.l	(a7)+,a0		* 次の PR の先頭アドレス
		move.w	CHAIN_OFS(a0),d7	* 連鎖数（そのまま dbcc カウンタとして使える）
		bpl	SORT_512_LOOP		* 連鎖数 >= 0 なら続行
		bra	SORT_512_END		* 終了

	*-------[ 終点に達した ]
end_mark:	addq.w	#4,a0			* ポインタ補正（cd,pr を飛ばす）
		dbra	d7,SORT_512_LOOP
		bra.b	@B

		.endm

*--------------------------------------------------------------------------




*==========================================================================
*
*	ソート・アルゴリズム
*
*==========================================================================

					* a0.l = 書換用バッファ管理構造体

*-------[ 初期化 1 ]
	move.l	#8*65,d0		* d0.l = 分割バッファ１個分のサイズ

	movea.l	div_buff(a0),a3		* a3.l = #ラスタ分割バッファA
	move.l	a3,d3
	add.l	d0,d3			* d3.l = #ラスタ分割バッファB
	movea.l	d3,a4
	adda.l	d0,a4			* a4.l = #ラスタ分割バッファC
	move.l	a4,d4
	add.l	d0,d4			* d4.l = #ラスタ分割バッファD
	movea.l	d4,a5
	adda.l	d0,a5			* a5.l = #ラスタ分割バッファE
	move.l	a5,d5
	add.l	d0,d5			* d5.l = #ラスタ分割バッファF
	movea.l	d5,a6
	adda.l	d0,a6			* a6.l = #ラスタ分割バッファG
	move.l	a6,d6
	add.l	d0,d6			* d6.l = #ラスタ分割バッファH

	moveq.l	#-1,d0
	move.w	d0,8*65*0+8*64(a3)	* end_mark(SP_x = -1)
	move.w	d0,8*65*1+8*64(a3)	* end_mark(SP_x = -1)
	move.w	d0,8*65*2+8*64(a3)	* end_mark(SP_x = -1)
	move.w	d0,8*65*3+8*64(a3)	* end_mark(SP_x = -1)
	move.w	d0,8*65*4+8*64(a3)	* end_mark(SP_x = -1)
	move.w	d0,8*65*5+8*64(a3)	* end_mark(SP_x = -1)
	move.w	d0,8*65*6+8*64(a3)	* end_mark(SP_x = -1)
	move.w	d0,8*65*7+8*64(a3)	* end_mark(SP_x = -1)


*-------[ 初期化 2 ]
					*---------------------------------------
					* a0.l = 仮バッファスキャンポインタ
					* a1.l = 
					* a2.l = temp
					* a3.l = #ラスタ分割バッファA
					* a4.l = #ラスタ分割バッファC
					* a5.l = #ラスタ分割バッファE
					* a6.l = #ラスタ分割バッファG
					* a7.l = PR 鎖先頭情報読み出し用
					*---------------------------------------
					* d0.l = temp（SP_x,SP_y 読みだし）
					* d1.l = temp
	move.w	#$1FC,d2		* d2.w = SP_y 下位 4 ビット切り捨て用 and値
					* d3.l = #ラスタ分割バッファB
					* d4.l = #ラスタ分割バッファD
					* d5.l = #ラスタ分割バッファF
					* d6.l = #ラスタ分割バッファH
					* d7.w = 連鎖数 dbcc カウンタ
					*---------------------------------------


	move.l	(a7)+,a0		* PR ごとの先頭アドレス
	move.w	CHAIN_OFS(a0),d7	* 連鎖数（そのまま dbcc カウンタとして使える）
	bmi	SORT_512_END		* いきなり連鎖数が負（終点）なら終了

*=======[ ソーティング処理ループ ]
SORT_512_LOOP:
	move.l	(a0)+,d0			*[12]	d0.l = x,y
	move.w	d0,d1				*[ 4]	d1.w = y
	and.w	d2,d1				*[ 4]	d1.w = y & $1FC
	movea.l	SORT_512_JPTBL(pc,d1.w),a2	*[18]	a2.l = ブランチ先アドレス
	jmp	(a2)				*[ 8]	ブランチ


*=======[ Y 座標別ジャンプテーブル ]
SORT_512_JPTBL:
	dcb.l	9,SORT_512_A		* 36dot
	dcb.l	8,SORT_512_B		* 32dot
	dcb.l	9,SORT_512_C		* 36dot
	dcb.l	8,SORT_512_D		* 32dot
	dcb.l	9,SORT_512_E		* 36dot
	dcb.l	8,SORT_512_F		* 32dot
	dcb.l	9,SORT_512_G		* 36dot
	dcb.l	8,SORT_512_H		* 32dot

	dcb.l	128-(8+9)*4,SORT_512_H	* ダミー


*=======[ ラスタ分割バッファに登録 ]
SORT_512_A:	SORT_512_An	a3
SORT_512_B:	SORT_512_Dn	d3
SORT_512_C:	SORT_512_An	a4
SORT_512_D:	SORT_512_Dn	d4
SORT_512_E:	SORT_512_An	a5
SORT_512_F:	SORT_512_Dn	d5
SORT_512_G:	SORT_512_An	a6
SORT_512_H:	SORT_512_Dn	d6


SORT_512_END:



*==========================================================================
*
*	最大 512 枚モード 分割ラスタ移動 その他
*
*==========================================================================

*-------[ チェイン情報末端に end_mark 書き込み ]

	moveq.l	#0,d0			* d0.l = 0

	move.w	d0,CHAIN_OFS_div+2(a3)	* チェイン情報に end_mark（転送数*8 = 0）書き込み
	movea.l	d3,a2
	move.w	d0,CHAIN_OFS_div+2(a2)	* チェイン情報に end_mark（転送数*8 = 0）書き込み

	move.w	d0,CHAIN_OFS_div+2(a4)	* チェイン情報に end_mark（転送数*8 = 0）書き込み
	movea.l	d4,a2
	move.w	d0,CHAIN_OFS_div+2(a2)	* チェイン情報に end_mark（転送数*8 = 0）書き込み

	move.w	d0,CHAIN_OFS_div+2(a5)	* チェイン情報に end_mark（転送数*8 = 0）書き込み
	movea.l	d5,a2
	move.w	d0,CHAIN_OFS_div+2(a2)	* チェイン情報に end_mark（転送数*8 = 0）書き込み

	move.w	d0,CHAIN_OFS_div+2(a6)	* チェイン情報に end_mark（転送数*8 = 0）書き込み
	movea.l	d6,a2
	move.w	d0,CHAIN_OFS_div+2(a2)	* チェイン情報に end_mark（転送数*8 = 0）書き込み


*-------[ 各分割ブロックの使用数を求め、チェイン情報先頭に 転送数*8 書き込み ]

	move.l	write_struct(pc),a0	* a0.l = 書換用バッファ管理構造体
	movea.l	div_buff(a0),a1		* a1.l = バッファA 先頭アドレス
	move.l	#8*65,d0		* d0.l = 分割バッファ 1 個分のサイズ

					* a1.l = バッファA 先頭アドレス
	suba.l	a1,a3			* a3.l = バッファA 使用数*8
	move.l	a3,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

	adda.l	d0,a1			* a1.l = バッファB 先頭アドレス
	sub.l	a1,d3			* d3.l = バッファB 使用数*8
	move.l	d3,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

	adda.l	d0,a1			* a1.l = バッファC 先頭アドレス
	suba.l	a1,a4			* a4.l = バッファC 使用数*8
	move.l	a4,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

	adda.l	d0,a1			* a1.l = バッファD 先頭アドレス
	sub.l	a1,d4			* d4.l = バッファD 使用数*8
	move.l	d4,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

	adda.l	d0,a1			* a1.l = バッファE 先頭アドレス
	suba.l	a1,a5			* a5.l = バッファE 使用数*8
	move.l	a5,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

	adda.l	d0,a1			* a1.l = バッファF 先頭アドレス
	sub.l	a1,d5			* d5.l = バッファF 使用数*8
	move.l	d5,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

	adda.l	d0,a1			* a1.l = バッファG 先頭アドレス
	suba.l	a1,a6			* a6.l = バッファG 使用数*8
	move.l	a6,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

	adda.l	d0,a1			* a1.l = バッファH 先頭アドレス
	sub.l	a1,d6			* d6.l = バッファH 使用数*8
	move.l	d6,CHAIN_OFS_div(a1)	* チェイン情報（使用数*8）書き込み
					* かつ、スキップ数*8 を 0 クリア

					*---------------------------------------
					* a0.l = 書換用バッファ管理構造体
					*---------------------------------------
					* a3.l = ラスタ分割バッファA 使用数*8
					* a4.l = ラスタ分割バッファC 使用数*8
					* a5.l = ラスタ分割バッファE 使用数*8
					* a6.l = ラスタ分割バッファG 使用数*8
					*---------------------------------------
					* d3.l = ラスタ分割バッファB 使用数*8
					* d4.l = ラスタ分割バッファD 使用数*8
					* d5.l = ラスタ分割バッファF 使用数*8
					* d6.l = ラスタ分割バッファH 使用数*8
					*---------------------------------------

*-------[ ラスタ分割 Y 座標の自動更新 ]
	tst.w	auto_adjust_divy_flg	* ラスタ分割 Y 座標の自動調整が有効か？
	beq	@f			* NO なら bra
		bsr AUTO_ADJUST_DIV_Y
@@:


