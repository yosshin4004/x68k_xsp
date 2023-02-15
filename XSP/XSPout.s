*==========================================================================
*
*	xsp_out2(void *vsyncint_arg);
*
*==========================================================================

_xsp_out2:

A7ID	=	4+0*4			*   スタック上 return先アドレス  [ 4 byte ]
					* + 退避レジスタの全バイト数     [ 0*4 byte ]

*=======[ vsyncint_arg を取得 ]
	movea.l	A7ID+arg1_l(sp),a1	* a1.l = vsyncint_arg

*=======[ xsp_out に飛ぶ ]
	bra.b	xsp_out_entry



*==========================================================================
*
*	xsp_out();
*
*==========================================================================

_xsp_out:

A7ID	=	4+11*4			*   スタック上 return先アドレス  [ 4 byte ]
					* + 退避レジスタの全バイト数     [ 11*4 byte ]

*=======[ vsyncint_arg を取得（存在しないので NULL）]
	suba.l	a1,a1			* a1.l = vsyncint_arg = NULL

xsp_out_entry:
*=======[ XSP 初期化チェック ]
	cmpi.b	#%0000_0011,XSP_flg
	beq.b	@F			* XSP が正しく初期化されているなら bra

	*-------[ 正しく初期化されていない ]
		moveq.l	#-1,d0		* 戻り値 = ｰ1
		rts			* 何もせず rts

@@:

*=======[ 書換用バッファが利用可能になるまで待つ ]
					* a1.l = vsyncint_arg
wait_until_write_struct_is_free:
	move.l	write_struct(pc),a0			* a0.l = 書換用バッファ管理構造体
	cmpa.l	disp_struct(pc),a0			* 表示用バッファ管理構造体と重なっているか？
	beq.b	wait_until_write_struct_is_free		* 重なっているなら表示用バッファが変更されるまで待つ。
	move.l	a1,vsyncint_arg(a0)			* vsyncint_arg を保存

*=======[ レジスタ退避など ]
	movem.l	d2-d7/a2-a6,-(sp)	* レジスタ退避

	move.l	a7,a7_bak1		* まず A7 を保存。本関数内では、
					* 書換要求以外のスタックpushは
					* 禁止されている。

*=======[ スーパーバイザーモードへ ]
	suba.l	a1,a1
	iocs	_B_SUPER		* スーパーバイザーモードへ
	move.l	d0,usp_bak		* 元々スーパーバイザーモードなら、d0.l = -1



*==========================================================================
*
*	初期化
*
*==========================================================================


*=======[ OX_mask 更新手続き ]
	tst.w	OX_mask_renew
	beq.b	EXIT_OX_mask_renew

		clr.w	OX_mask_renew		* 更新フラグをクリア

	*-------[ OX_mask 更新 ]
		moveq.l	#0,d0			* d0.l = 0
		move.b	OX_level(pc),d1
		sub.b	#1,d1			* d1.b = OX_tbl 水位 - 1
		moveq.l	#-1,d2			* d2.l = -1（d2.b = 255）

		move.w	#255,d7			* d7.w = dbra カウンタ 兼 PCG ナンバー
		move.w	#255*2,d6		* d6.w = d7.w * 2

		moveq.l	#0,d4			* d4.l = 0（マスク off の PCG の 最小ナンバー）
		moveq.l	#0,d5			* d5.l = 0（マスク off の PCG の 最大ナンバー）

		lea.l	OX_tbl_no_pc,a0		* a0.l = OX_tbl
		lea.l	OX_mask_no_pc,a1	* a1.l = OX_mask
		lea.l	pcg_rev_alt_no_pc,a2	* a2.l = pcg_rev_alt
		movea.l	pcg_alt_adr(pc),a3	* a3.l = pcg_alt

OX_mask_renew_LOOP:
		tst.b	(a1,d7.w)		* OX_mask onか？
		beq.b	OX_mask_off		* NO なら bra
		*-------[ OX_mask on ]
OX_mask_on:		move.b	d2,(a0,d7.w)	* 水位 = 255 とする
			move.w	(a2,d6.w),d3	* d3.w = マスクされた PCG に定義されていた pt
			move.b	d0,(a3,d3.w)	* pcg_alt クリア（定義破棄）
			move.w	d2,(a2,d6.w)	* pcg_rev_alt クリア（定義破棄の重複を回避）
			bra.b	OX_mask_NEXT

		*-------[ OX_mask off ]		* 水位 == 255 の場合のみ、水位 = 1 とする
OX_mask_off:		cmp.b	(a0,d7.w),d2	* 水位 == 255 か？
			bne.b	@f
				move.b	d1,(a0,d7.w)	* 現在の水位 - 1 を書き込む
							* (つまり最低 1 ターン待たないと
							* 使用不可。さもないと書き換えが
							* 見えてしまうのである。)
@@:
			move.w	d7,d4		* d4.w = マスク off の PCG の最小ナンバー
			tst.w	d5
			bne.b	@f		* d5.w が非 0 なら bra
						*(つまり d5.w 設定は最初の 1 回きりである)
				move.w	d7,d5	* d5.w = マスク off の PCG の最大ナンバー
@@:
OX_mask_NEXT:
		sub.w	#2,d6
		dbra	d7,OX_mask_renew_LOOP

	*-------[ 検索開始アドレスと検索サイズ - 1 を求める ]

		* マスク off の PCG が１枚も存在しなかった時、d4.w d5.w ともに 0 である。
		* よって、検索サイズ - 1 = 0 となり、1 枚限りの検索となる。
		* また、検索開始 PCG のナンバーは 0 となる。0 番 PCG は必ず「使用」である
		* から、つまり PCG 定義は実質実行されないことになる。

						* a0.l = OX_tbl
		add.w	d4,a0			* a0.l = OX_tbl 検索開始アドレス
		move.l	a0,OX_chk_top		* OX_tbl 検索開始アドレスに保存
		move.l	a0,OX_chk_ptr		* OX_tbl 検索ポインタに保存
		sub.w	d4,d5			* d5.w = 検索サイズ - 1
		move.w	d5,OX_chk_size		* OX_tbl 検索サイズ - 1 に保存

EXIT_OX_mask_renew:



*=======[ OX_tbl 水位調整 ]
OX_level_INC:
	lea.l	OX_level(pc),a0		* (a0).b = OX_level.b
	addq.b	#1,(a0)			* OX_level.b++
	cmpi.b	#255,(a0)
	bne	OX_level_INC_END	* (#255 != OX_level) なら bra

	*-------[ 水位の引き下げ処理 ]
		move.b	#4,(a0)		* OX_level.b = 4

		lea.l	OX_tbl_no_pc,a0	* a0.l = OX_tbl
		moveq.l	#0,d0		* d0.l = 0
		moveq.l	#31,d1		* d1.l = 31（dbra カウンタ）
@@:
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		move.b	(a0),d0
		move.b	OX_tbl_INIT_TBL(pc,d0.w),(a0)+
		dbra	d1,@B

		bra	OX_level_INC_END


OX_tbl_INIT_TBL:
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01

	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01

	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01

	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01
	dc.b	$01,$01,$01,$01 , $01,$01,$01,$01 , $01,$01,$01,$01 , $01,$02,$03,$FF


OX_level_INC_END:



*=======[ 使用スプライト数などを求める ]
	lea	buff_top_adr_no_pc,a0		* a0.l = #buff_top_adr_no_pc
	move.l	buff_pointer(pc),d0
	sub.l	a0,d0			* d0.w =（仮バッファ上の）スプライト数 x 8

	move.w	sp_mode(pc),d1		* d1.w = sp_mode
	cmpi.w	#1,d1			* 128 枚モードか？
	bne.b	@F			* NO なら bra
		cmpi.w	#384*8,d0
		ble.b	EXIT_GET_TOTAL_SP	* #384*8 >= d0 なら bra
			move.w	#384*8,d0	* 384 枚以下に修正
			move.l	#buff_top_adr_no_pc+384*8,buff_pointer
			bra.b	EXIT_GET_TOTAL_SP
@@:
	cmpi.w	#128*8,d0
	bgt.b	@F			* #128*8 < d0 なら bra
		moveq	#1,d1		* 128 枚以下の場合は一時的に 128 枚モード
		bra.b	EXIT_GET_TOTAL_SP
@@:
	move.w	sp_mode(pc),d1		* 512 枚モードにする

EXIT_GET_TOTAL_SP:
					* d0.w = 加工済使用スプライト数 x 8
					* d1.w = 加工済sp_mode


*=======[ その他 ]
	move.l	write_struct(pc),a1	* a1.l = 書換用バッファ管理構造体
	move.w	d1,buff_sp_mode(a1)	* バッファナンバー別 sp_mode保存
	move.w	d0,buff_sp_total(a1)	* バッファナンバー別 スプライト数 x 8 保存

					*--------------------------
					* d0.w = スプライト数 x 8
					* a0.l = #buff_top_adr
					*--------------------------



*==========================================================================
*
*	スプライト加工 ＆ チェイン作成
*
*==========================================================================

					* d0.w = スプライト数 x 8
					* a0.l = #buff_top_adr

	clr.w	-2(a0)			* 仮バッファ end_mark（PR が 0）

*-------[ レジスタ初期化 ]
					*---------------------------------------------
	adda.w	d0,a0			* a0.l = 仮バッファスキャン（末端より）
	lea.l	pr_top_tbl_no_pc,a1	* a1.l = PR 別先頭テーブル
					* a2.l = 
	movea.l	pcg_alt_adr(pc),a3	* a3.l = pcg_alt
					* a4.l = 
					* a5.l = 
	lea.l	OX_tbl_no_pc,a6		* a6.l = OX_tbl
					* a7.l = PCG 定義要求バッファ
					*---------------------------------------------

*-------[ PCG 定義要求バッファに end_mark ]
	move.w	#-1,-(a7)		* pt に負
	subq.w	#4,a7			* ポインタ補正

*-------[ PR 別先頭テーブル[32].l の初期化 ]
	move.l	#buff_end_adr_no_pc,d0	* d0.l = 終点ダミー PR ブロックのアドレス
	move.l	d0,d1
	move.l	d0,d2
	move.l	d0,d3
	move.l	d0,d4
	move.l	d0,d5
	move.l	d0,d6
	move.l	d0,d7

					*	a1.l = PR 別先頭テーブル
	lea.l	$40*4(a1),a1		*[8]	a1.l = PR 別先頭テーブルの末端
	movem.l	d0-d7,-(a1)		*[8+4n]
	movem.l	d0-d7,-(a1)		*[8+4n]
	movem.l	d0-d7,-(a1)		*[8+4n]
	movem.l	d0-d7,-(a1)		*[8+4n]
	movem.l	d0-d7,-(a1)		*[8+4n]
	movem.l	d0-d7,-(a1)		*[8+4n]
	movem.l	d0-d7,-(a1)		*[8+4n]
	movem.l	d0-d7,-(a1)		*[8+4n]
					* 合計 64.l 初期化


*=======[ スプライト加工 & チェイン作成（非縦画面モード）]
					*---------------------------------------------
					* d0.w = tmp（pt 読み取り & 加工）
	moveq.l	#0,d1			* d1.w = PCG_No.w（bit8～が 0）
					* d2.w = 現 info（同一 PR チェック用）
	moveq.l	#0,d3			* d3.w = 現 pr/16（bit8～が 0）
	moveq.l	#0,d4			* d4.w =(現 pr & 63) * 4（bit8～が 0）
					* d5.w = tmp（info 読み取り＆加工）
	move.b	OX_level(pc),d6		* d6.b = OX_tbl 水位
					* d7.w = 同一 PR 連鎖数
					*---------------------------------------------

	tst.w	vertical_flg		* 縦画面モードか？
	bne	VERTICAL_MODE		* YES なら bra


	move.w	-4(a0),d0		*[12]	最初の pt
	move.w	-2(a0),d5		*[12]	最初の info

	bra.b	START_MK_CHAIN		*[10]


*-------[ PCG 定義要求 ]
REQ_PCGDEF:
	move.w	d3,-(a0)		* 現 pr/16 転送
	move.w	d5,-(a0)		* [反:色:PR].w を未加工 cd として転送
	move.w	d0,-(a7)		* 定義したい pt を保存
	move.l	a0,-(a7)		* pt アドレスを保存

	addq.w	#1,d7			* 連鎖数加算
	subq.w	#8,a0			* スキャンポインタ移動

	move.w	(a0)+,d0		* d0.w = pt
	move.w	(a0)+,d5		* d5.w = info
	cmp.b	d2,d5			* 同一 PR か？
	bne.b	NOT_SAME_PR		* NO なら bra

*-------[ ループ ]
MK_CHAIN_LOOP:
	move.b	(a3,d0.w),d1		* d1.w = PCG_No.
	beq.b	REQ_PCGDEF		* PCG 未定義なら PCG 定義要求
	move.b	d6,(a6,d1.w)		* OX_tbl に「使用」を書込み

	move.w	d3,-(a0)		* 現 pr/16 を転送
	move.b	d1,d5			* d5.w = [反:色:PCG_No].w（= cd）
	move.w	d5,-(a0)		* 加工済 cd 転送

	addq.w	#1,d7			* 連鎖数加算
	subq.w	#8,a0			* スキャンポインタ移動

	move.w	(a0)+,d0		* d0.w = pt
	move.w	(a0)+,d5		* d5.w = info
	cmp.b	d2,d5			* 同一 PR か？
	beq.b	MK_CHAIN_LOOP		* YES なら bra（高確率で bra）

*-------[ PR 変更 ]
NOT_SAME_PR:
					* a0.l = 変更前 PR 鎖の先頭アドレス（SP_x の位置）
					* d4.w =(変更前 PR & 63)*4
	move.l	a0,(a1,d4.w)		* PR 別先頭テーブルへ保存
	move.w	d7,CHAIN_OFS(a0)	* 連鎖数保存

START_MK_CHAIN:
	move.w	d5,d2			* d2.w = 変更後 info（同一 PR チェック用）
	move.b	d5,d4
	add.b	d4,d4
	add.b	d4,d4			* d4.w = (変更後 PR * 4) & 255 = (変更後 PR & 63) * 4
	move.l	(a1,d4.w),CHAIN_OFS-4(a0)	* NEXT ポインタに PR 別先頭アドレスを書き込む

	moveq.l	#-1,d7			* 連鎖数クリア
	move.b	d5,d3
	asr.w	#4,d3			* d3.w = 次pr/16
	bne.b	MK_CHAIN_LOOP		* 非 0 なら繰り返し

*-------[ 0 なので end_mark の可能性有り ]
	move.b	#$10,d2			* pr = 0 が連鎖すると end_mark を取りこぼすので無理やり補正

	cmpa.l	#buff_top_adr_no_pc,a0	* 本当に終点までスキャンしたか？
	bne.b	MK_CHAIN_LOOP		* NO なら繰り返し

	bra	PCG_DEF_1



*=======[ スプライト加工 & チェイン作成（縦画面モード）]
VERTICAL_MODE:

	move.w	#XY_MAX,a2		*[ 8]	a2.l = XY_MAX（縦画面 x,y 加工用）

	subq.w	#8,a0
	move.l	(a0),d0			*[12]	d0.l = 最初の x , y
	neg.w	d0			*[ 4]	d0.w =- d0.w
	add.w	a2,d0			*[ 4]	d0.w += XY_MAX
	.if	SHIFT<>0
					*	SHIFT が 0 で無いとき、xsp_set 系関数にて、
					*	スプライト座標の固定少数のシフトを 32bit 長で
					*	行う最適化の都合、元の x 座標の下位ビットが
					*	y 座標の上位ビットに漏れ出し、y 座標に負の値が
					*	生じる。この状態のまま縦画面モードの x y 軸
					*	交換をすると、x 座標に負の値が生じ、end mark
					*	と誤認識される。これを回避するため、y 座標上位
					*	ビットのクリアが必要になる。
					*	このオーバーヘッドは、縦画面モードの時だけ
					*	生じる。
		andi.w	#511,d0		*[ 8]	y 座標上位ビットのクリア
	.endif
	swap	d0			*[ 4]	x,y 交換
	move.l	d0,(a0)+		*[12]	加工済み x,y 転送

	move.w	(a0)+,d0		*[ 8]	d0.w = 最初の pt
	move.w	(a0)+,d5		*[ 8]	d5.w = 最初の info

	bra.b	START_MK_CHAIN_v	*[10]


*-------[ PCG 定義要求 ]
REQ_PCGDEF_v:
	move.w	d0,-(a7)		*[ 8]	定義したいptを保存

	move.w	d5,d0			*[ 4]	d0.w 上位 2 ビット = 反転コード
	add.w	d0,d0			*[ 4]	上位 2 ビットが 01 又は 10 の時、V=1
	bvc.b	@f			*[8,10]	V=0 なら bra
		eor.w	#$C000,d5	*[ 8]	反転コード加工
@@:
	move.w	d3,-(a0)		*[ 8]	現pr/16 転送
	move.w	d5,-(a0)		*[ 8]	[反:色:PR].w を未加工 cd として転送
	move.l	a0,-(a7)		*[12]	pt アドレスを保存

	addq.w	#1,d7			*[ 4]	連鎖数加算
	lea.l	-12(a0),a0		*[ 8]	スキャンポインタ移動

	move.l	(a0),d0			*[12]	d0.l = x , y
	neg.w	d0			*[ 4]	d0.w = -d0.w
	add.w	a2,d0			*[ 4]	d0.w += XY_MAX
	.if	SHIFT<>0
		andi.w	#511,d0		*[ 8]	y 座標上位ビットのクリア
	.endif
	swap	d0			*[ 4]	x,y 交換
	move.l	d0,(a0)+		*[12]	加工済み x,y 転送

	move.w	(a0)+,d0		*[ 8]	d0.w = pt
	move.w	(a0)+,d5		*[ 8]	d5.w = info
	cmp.b	d2,d5			*[ 4]	同一 PR か？
	bne.b	NOT_SAME_PR_v		*[8,10]	NO なら bra

*-------[ ループ ]
MK_CHAIN_LOOP_v:
	move.b	(a3,d0.w),d1		*[14]	d1.w = PCG_No.
	beq.b	REQ_PCGDEF_v		*[8,10]
	move.b	d6,(a6,d1.w)		*[14]	OX_tbl に「使用」を書込み

	move.w	d3,-(a0)		*[ 8]	現 pr/16 を転送
	move.b	d1,d5			*[ 4]	d5.w = [反:色:PCG_No].w（＝cd）

	move.w	d5,d0			*[ 4]	d0.w 上位 2 ビット = 反転コード
	add.w	d0,d0			*[ 4]	上位 2 ビットが 01 又は 10 の時、V=1
	bvc.b	@f			*[8,10]	V=0 なら bra
		eor.w	#$C000,d5	*[ 8]	反転コード加工
@@:
	move.w	d5,-(a0)		*[ 8]	加工済 cd 転送

	addq.w	#1,d7			*[ 4]	連鎖数加算
	lea.l	-12(a0),a0		*[ 8]	スキャンポインタ移動

	move.l	(a0),d0			*[12]	d0.l = x , y
	neg.w	d0			*[ 4]	d0.w = -d0.w
	add.w	a2,d0			*[ 4]	d0.w += XY_MAX
	.if	SHIFT<>0
		andi.w	#511,d0		*[ 8]	y 座標上位ビットのクリア
	.endif
	swap	d0			*[ 4]	x,y 交換
	move.l	d0,(a0)+		*[12]	加工済み x,y 転送

	move.w	(a0)+,d0		*[ 8]	d0.w = pt
	move.w	(a0)+,d5		*[ 8]	d5.w = info
	cmp.b	d2,d5			*[ 4]	同一 PR か？
	beq.b	MK_CHAIN_LOOP_v		*[8,10]	YES なら bra（高確率で bra）

*-------[ PR 変更 ]
NOT_SAME_PR_v:
					* a0.l = 変更前 PR 鎖の先頭アドレス（SP_x の位置）
					* d4.w =(変更前 PR & 63) * 4
	move.l	a0,(a1,d4.w)		* PR 別先頭テーブルへ保存
	move.w	d7,CHAIN_OFS(a0)	* 連鎖数保存

START_MK_CHAIN_v:
	move.w	d5,d2			* d2.w = 変更後info（同一 PR チェック用）
	move.b	d5,d4
	add.b	d4,d4
	add.b	d4,d4			* d4.w = (変更後 PR * 4) & 255 = (変更後 PR & 63) * 4
	move.l	(a1,d4.w),CHAIN_OFS-4(a0)	* NEXT ポインタに PR 別先頭アドレスを書き込む

	moveq.l	#-1,d7			* 連鎖数クリア
	move.b	d5,d3
	asr.w	#4,d3			* d3.w = 次pr/16
	bne.b	MK_CHAIN_LOOP_v		* 非 0 なら繰り返し

*-------[ 0 なので end_mark の可能性有り ]
	move.b	#$10,d2			* pr = 0 が連鎖すると end_mark を取りこぼすので無理やり補正

	cmpa.l	#buff_top_adr_no_pc,a0	* 本当に終点までスキャンしたか？
	bne.b	MK_CHAIN_LOOP_v		* NO なら繰り返し




*==========================================================================
*
*	PCG 定義処理 1
*
*==========================================================================

PCG_DEF_1:
	move.l	write_struct(pc),a2	* a2.l = 書換用バッファ管理構造体
	lea.l	vsync_def(a2),a2	* a2.l = 帰線期間 PCG 定義要求バッファ
					* a3.l = pcg_alt
					* a6.l = OX_tbl
					* a7.l = PCG定義要求バッファポインタ

*-------[ 初期化 ]
					*----------------------------------------------
					* a0.l = temp
					* a1.l = temp
					* a2.l = 帰線期間 PCG 定義要求バッファ
					* a3.l = pcg_alt
	lea.l	pcg_rev_alt_no_pc,a4	* a4.l = pcg_rev_alt
	movea.l	OX_chk_ptr(pc),a5	* a5.l = OX_tbl 検索ポインタ
					* a6.l = OX_tbl
					* a7.l = PCG 定義要求バッファポインタ
					*----------------------------------------------
					* d0.w = temp（pt 読みだし）
					* d1.w = PCG_No.w（bit8～の事前の 0 クリア必要なし）
					* d2.l = temp
					* d3.l = temp
	move.l	#$EB8000,d4		* d4.l = #$EB8000（下位１バイトは 0 のかわり）
	move.l	pcg_dat_adr(pc),d5	* d5.l = PCG データアドレス
					* d6.b = OX_tbl 水位
	move.w	OX_chk_size(pc),d7	* d7.w = PCG 検索の dbcc カウンタ
					*----------------------------------------------

	move.b	d6,d2			* d2.b = OX_tbl 水位
	subq.b	#2,d2			* d2.b = OX_tbl 水位 - 2

	bra.b	PCG_DEF_1_START


*=======[ PCG 定義処理 1 完全終了 ]
PCG_DEF_1_END:
	bra	PCG_DEF_COMPLETE	* ブランチ中継


*-------[ 未処理 cd の修正ループ ]
@@:
	move.b	d1,1(a0)		* 未処理 cd 修正
PCG_DEF_1_START:
	movea.l	(a7)+,a0		* a0.l = 修正が必要な cd アドレス
	move.w	(a7)+,d0		* d0.w = 定義する pt
	bmi.b	PCG_DEF_1_END		* 負なら完全終了
PCG_DEF_1_L0:
	move.b	(a3,d0.w),d1		* d1.b = PCG_No.
	bne.b	@B			* 定義されているなら bra

	*-------[ 空き PCG 検索 ]
@@:		cmp.b	(a5)+,d2	* < d2.b なら 3 フレーム未使用
		dbhi	d7,@B		* 注：cc 成立でループを抜ける時、d7.w はデクリされない
					* (cc成立 && d7 >= 0) || (cc 不成立 && d7 < 0)
		bls	PCG_DEF_2	* cc 不成立なら (この時必ず d7 < 0 && 非終点) 不完全終了

		tst.b	-(a5)		* end_mark(0) か？
		bne.b	FOUND_PCG_1	* No なら bra
		*-------[ 未使用 PCG でなく、end_mark だった ]
			move.l	OX_chk_top(pc),a5	* OX_tbl 検索ポインタを先頭に戻す
			bra.b	@B			* ループ
							* d7.w++ 補正は不用（上記注意参照）

	*-------[ 未使用 PCG 発見 ]
FOUND_PCG_1:
		move.w	a5,d1
		sub.w	a6,d1			* d1.w = a5.w - OX_tbl.w = PCG_No.
		move.b	d1,1(a0)		* 未処理 cd 修正
		move.b	d6,(a5)+		* OX_tbl に現在の水位を書込み

	*-------[ PCG 配置管理テーブル処理 ]
						*[d0.w = 定義する pt (0～0x7FFF)]
						*[d1.w = 定義先 PCG_No.(0～255)]
		move.b	d1,(a3,d0.w)		* pcg_alt 書込み
		add.w	d1,d1			* d1.w = 定義先 PCG No.*2
						*[a4.l = pcg_rev_alt アドレス]
		move.w	(a4,d1.w),d3		* d3.w = 描き潰される pt
		move.b	d4,(a3,d3.w)		* 描き潰される pt を未定義にする
		move.w	d0,(a4,d1.w)		* 新たに pcg_rev_alt 書込み

	*-------[ PCG 定義実行 ]
		ext.l	d0			* d0.l = 定義する pt
		lsl.l	#7,d0			* d0.l = 定義する pt * 128
		add.l	d5,d0			* d0.l = PCG データアドレス + pt * 128
						*      = 転送元

		ext.l	d1			* d1.l = 定義先 PCG_No.* 2
		lsl.w	#6,d1			* d1.l = 定義先 PCG_No.* 128（.w で破綻しない）
		add.l	d4,d1			* d1.l = #$EB8000 + PCG_No.* 128
						*      = 転送先

		movea.l	d0,a0
		movea.l	d1,a1

		.rept	32
			move.l	(a0)+,(a1)+	* 1 PCG 転送
		.endm

	*-------[ 次のスプライトへ ]
		dbra	d7,PCG_DEF_1_START

						* 不完全終了
		movea.l	(a7)+,a0		* つじつま合せ
		move.w	(a7)+,d0		* つじつま合せ
		bmi	PCG_DEF_COMPLETE	* d0.w が負なら完全終了




*==========================================================================
*
*	PCG 定義処理 2（PCG が足りず帰線期間 PCG 定義要求）
*
*==========================================================================

PCG_DEF_2:
					*----------------------------------------------
					* a0.l = temp
					* a1.l = temp
					* a2.l = 帰線期間 PCG 定義要求バッファ
					* a3.l = pcg_alt アドレス
					* a4.l = pcg_rev_alt アドレス
					* a5.l = OX_tbl 検索ポインタ
					* a6.l = OX_tbl
					* a7.l = PCG 定義要求バッファポインタ
					*----------------------------------------------
					* d0.w = temp（pt 読みだし）
					* d1.w = PCG_No.w（bit8～の事前の 0 クリア必要なし）
	moveq.l	#30,d2			* d2.w = 31PCG まで検索するための dbcc カウンタ
					* d3.l = temp
					* d4.l = #$EB8000（下位１バイトは 0 のかわり）
					* d5.l = PCG データアドレス
					* d6.b = OX_tbl 水位
	move.w	OX_chk_size(pc),d7	* d7.w = PCG 検索の dbcc カウンタ
					*----------------------------------------------
					* a0.l = PCG_DEF_1 で未処理の 修正先アドレス
					* d0.w = PCG_DEF_1 で未処理の pt

	bra.b	PCG_DEF_2_L0		* a0.l d0.w の読み出し部分は飛ばす


*=======[ PCG 定義処理 1 完全終了 ]
PCG_DEF_2_END:
	bra	PCG_DEF_COMPLETE	* ブランチ中継


*-------[ 未処理 cd の修正ループ ]
@@:
	move.b	d1,1(a0)		* 未処理 cd 修正
PCG_DEF_2_START:
	movea.l	(a7)+,a0		* a0.l = 修正が必要な cd アドレス
	move.w	(a7)+,d0		* d0.w = 定義する pt
	bmi.b	PCG_DEF_2_END		* 負なら完全終了
PCG_DEF_2_L0:
	move.b	(a3,d0.w),d1		* d1.b = PCG_No.
	bne.b	@B			* 定義されているなら bra

	*-------[ 空き PCG 検索 ]
@@:		cmp.b	(a5)+,d6	* < d6.b なら今回のフレームにおいて未使用
		dbhi	d7,@B		* 注：cc 成立でループを抜ける時、d7.w はデクリされない
					* (cc 成立 && d7 >= 0) || (cc 不成立 && d7 < 0)
		bls.b	PCG_DEF_3	* cc 不成立なら (この時必ず d7 < 0 && 非終点) 不完全終了

		tst.b	-(a5)		* end_mark(0) か？
		bne.b	FOUND_PCG_2	* No なら bra
		*-------[ 未使用 PCG でなく、end_mark だった ]
			move.l	OX_chk_top(pc),a5	* OX_tbl 検索ポインタを先頭に戻す
			bra.b	@B			* ループ
							* d7.w++ 補正は不用（上記注意参照）

	*-------[ 未使用 PCG 発見 ]
FOUND_PCG_2:
		move.w	a5,d1
		sub.w	a6,d1			* d1.w = a5.w - OX_tbl.w = PCG_No.
		move.b	d1,1(a0)		* 未処理 cd 修正
		move.b	d6,(a5)+		* OX_tblに現在の水位を書込み

	*-------[ PCG 配置管理テーブル処理 ]
						*[d0.w = 定義する pt (0～0x7FFF)]
						*[d1.w = 定義先 PCG_No.(0～255)]
		move.b	d1,(a3,d0.w)		* pcg_alt 書込み
		add.w	d1,d1			* d1.w = 定義先 PCG No.*2
						*[a4.l = pcg_rev_alt アドレス]
		move.w	(a4,d1.w),d3		* d3.w = 描き潰されるpt
		move.b	d4,(a3,d3.w)		* 描き潰されるptを未定義にする
		move.w	d0,(a4,d1.w)		* 新たに pcg_rev_alt 書込み

	*-------[ PCG 定義実行 ]
		ext.l	d0			* d0.l = 定義するpt
		lsl.l	#7,d0			* d0.l = 定義するpt * 128
		add.l	d5,d0			* d0.l = PCG データアドレス + pt * 128
						*      = 転送元

		ext.l	d1			* d1.l = 定義先 PCG_No.* 2
		lsl.w	#6,d1			* d1.l = 定義先 PCG_No.* 128（.w で破綻しない）
		add.l	d4,d1			* d1.l = #$EB8000 + PCG_No.* 128
						*      = 転送先

		move.l	d1,(a2)+		* 帰線期間 PCG 定義要求バッファへ（転送先）
		move.l	d0,(a2)+		* 帰線期間 PCG 定義要求バッファへ（転送元）

	*-------[ 次のスプライトへ ]
		dbra	d2,@f
		bra.b	PCG_DEF_2_L1		* 帰線期間 PCG 定義要求バッファが足りない
@@:
		dbra	d7,PCG_DEF_2_START


PCG_DEF_2_L1:
						* 不完全終了
		movea.l	(a7)+,a0		* つじつま合せ
		move.w	(a7)+,d0		* つじつま合せ
		bmi.b	PCG_DEF_COMPLETE	* d0.wが負なら完全終了




*==========================================================================
*
*	PCG 定義処理 3（PCG が足りず定義要求取り下げ）
*
*==========================================================================

PCG_DEF_3:
	moveq.l	#0,d2			* d2.l = 0

	bra.b	PCG_DEF_3_L0		* a0.l d0.w の読み出し部分は飛ばす


*-------[ 未処理 cd の修正ループ ]
@@:
	move.b	d1,1(a0)		* 未処理 cd 修正
PCG_DEF_3_START:
	movea.l	(a7)+,a0		* a0.l = 修正が必要な cd アドレス
	move.w	(a7)+,d0		* d0.w = 定義する pt
	bmi.b	PCG_DEF_COMPLETE	* 負なら終了
PCG_DEF_3_L0:
	move.b	(a3,d0.w),d1		* d1.b = PCG_No.
	bne.b	@B			* 定義されているなら bra
	*-------[ 消去してしまう ]
		move.w	d2,2(a0)	* pr に 0（表示 off）

		movea.l	(a7)+,a0	* a0.l = 修正が必要な cd アドレス
		move.w	(a7)+,d0	* d0.w = 定義する pt
		bpl.b	PCG_DEF_3_L0	* end_mark でないなら bra


PCG_DEF_COMPLETE:
	move.l	#-1,(a2)		* 帰線期間 PCG 定義要求バッファへ end_mark 書込み
	move.l	a5,OX_chk_ptr		* OX_tbl 検索ポインタ保存




*==========================================================================
*
*	PR 別先頭アドレスの必要なものをスタックに転送
*
*==========================================================================

LINK_CHAIN:

*-------[ 初期化 ]
	lea.l	buff_end_adr_no_pc,a0	* a0.l = 終点ダミー PR ブロック
	move.w	#-1,CHAIN_OFS(a0)	* 終点ダミーチェインに、end_mark（連鎖数-1）書き込み
	move.l	a0,-(a7)		* スタックに end_mark として書き込む

	lea.l	pr_top_tbl_no_pc,a1	* a1.l = PR 別先頭テーブル
	move.l	#-1,64*4(a1)		* PR 別先頭テーブル末端に end_mark(-1)書込み
	lea.l	$10*4(a1),a1		* pr >= $10 に強制補正しているので、pr = $10 よりスキャン

*-------[ PR 別先頭検索 ]
SEARCH_PR_TOP:
	move.l	(a1)+,d0		* d0.l = PR 別先頭アドレス
	bmi.b	LINK_CHAIN_END		* end_mark(-1)なら終了
SEARCH_PR_TOP_:
	cmp.l	a0,d0			* 終点ダミー PR ブロックを指しているか？
	beq.b	SEARCH_PR_TOP		* YES ならスキップ
	move.l	d0,-(a7)		* PR 別先頭アドレスをスタックへ転送

	move.l	(a1)+,d0		* d0.l = PR 別先頭アドレス
	bpl.b	SEARCH_PR_TOP_		* end_mark(-1)でないなら繰り返し

LINK_CHAIN_END:



*==========================================================================
*
*	sp_mode 別スプライト処理（ラスタ分割等）
*
*==========================================================================

SP_RAS_SORT:

	move.l	write_struct(pc),a0	* a0.l = 書換用バッファ管理構造体
	move.w	buff_sp_mode(a0),d0	* d0.w = 加工済 sp_mode
	cmpi.w	#2,d0			* 最大 512 枚モードか？
	beq.b	SP_RAS_SORT_mode2	* YES なら bra
	cmpi.w	#3,d0			* 最大 512 枚（優先度保護）モードか？
	beq	SP_RAS_SORT_mode3	* YES なら bra

*=======[ 最大 128 枚モード ]
SP_RAS_SORT_mode1:
	.include	XSP128.s
	bra	SP_RAS_SORT_END

*=======[ 最大 512 枚モード ]
SP_RAS_SORT_mode2:
	.include	XSP512.s
	bra	SP_RAS_SORT_END

*=======[ 最大 512 枚（優先度保護）モード ]
SP_RAS_SORT_mode3:
	.include	XSP512b.s

SP_RAS_SORT_END:



*==========================================================================
*
*	書換用バッファをチェンジ
*
*==========================================================================


*=======[ 書換用バッファをチェンジ ]
	movea.l	write_struct(pc),a0	* a0.l = 書換用バッファ管理構造体アドレス
	lea.l	STRUCT_SIZE(a0),a0

	cmpa.l	#endof_XSP_STRUCT_no_pc,a0	* 終点まで達したか？
	bne.b	@F				* No なら bra
		lea.l	XSP_STRUCT_no_pc,a0	* a0.l = バッファ管理構造体 #0 アドレス
@@:
	move.l	a0,write_struct		* 書換用バッファ管理構造体アドレス 書換え
	addq.w	#1,penging_disp_count	* 保留状態の表示リクエスト数 インクリメント


*=======[ ユーザーモードへ ]
	move.l	usp_bak(pc),d0
	bmi.b	@F			* スーパーバイザーモードより実行されていたら戻す必要無し
		movea.l	d0,a1
		iocs	_B_SUPER	* ユーザーモードへ
@@:

*-------[ 戻り値 ]
	move.l	buff_pointer(pc),d0
	sub.l	#buff_top_adr_no_pc,d0
	asr.l	#3,d0				* 戻り値＝仮バッファ上のスプライト数

	move.l	#buff_top_adr_no_pc,buff_pointer	* 仮バッファのポインタを初期化

	movea.l	a7_bak1(pc),a7			* A7 復活
	movem.l	(sp)+,d2-d7/a2-a6		* レジスタ復活
						* d0.l は戻り値

	rts



