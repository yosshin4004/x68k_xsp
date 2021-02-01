	.globl		_pcm8a_vsyncint_on
	.globl		_pcm8a_vsyncint_off


	.include	doscall.mac
	.include	iocscall.mac


*==========================================================================
*
*	スタックフレームの作成
*
*==========================================================================

	.offset 0

arg1_l	ds.b	2
arg1_w	ds.b	1
arg1_b	ds.b	1

arg2_l	ds.b	2
arg2_w	ds.b	1
arg2_b	ds.b	1

arg3_l	ds.b	2
arg3_w	ds.b	1
arg3_b	ds.b	1

arg4_l	ds.b	2
arg4_w	ds.b	1
arg4_b	ds.b	1


	.text
	.even


*==========================================================================
*
*	書式：void pcm8a_vsyncint_on();
*
*--------------------------------------------------------------------------

_pcm8a_vsyncint_on:

A7ID	=	4+4*2			*   スタック上 return先アドレス  [ 4 byte ]
					* + 退避レジスタの全バイト数     [ 4*2 byte ]

	movem.l	d0-d1,-(sp)		* レジスタ退避

	bsr	CHK_PCM8A		* PCM8A 常駐判定
	tst.l	d0
	beq.b	@f			* d0.l==0 なら 非常駐なので強制終了

	*-------[ PCM8A 割り込みマスク加工 ]
		move.w	#$01FB,d0	* d0.w = 機能コード $01FB : MPU MFP マスク設定
		moveq.l	#-1,d1		* d1.l = 負（割り込みレベル/マスク情報取得）
		trap	#2		* 割り込みレベル/マスク情報取得
					* d0.l = 現在の割り込みレベル/マスク値
		move.l	d0,d1
		bset.l	#6,d1		* d0.l = 加工した割り込みレベル/マスク値
		move.w	#$01FB,d0	* d0.w = 機能コード $01FB : MPU MFP マスク設定
		trap	#2		* 割り込みレベル/マスク情報設定

@@:
	movem.l	(sp)+,d0-d1		* レジスタ復活
	rts




*==========================================================================
*
*	書式：void pcm8a_vsyncint_off();
*
*--------------------------------------------------------------------------

_pcm8a_vsyncint_off:

A7ID	=	4+4*2			*   スタック上 return先アドレス  [ 4 byte ]
					* + 退避レジスタの全バイト数     [ 4*2 byte ]

	movem.l	d0-d1,-(sp)		* レジスタ退避

	bsr	CHK_PCM8A		* PCM8A 常駐判定
	tst.l	d0
	beq.b	@f			* d0.l==0 なら 非常駐なので強制終了

	*-------[ PCM8A 割り込みマスク加工 ]
		move.w	#$01FB,d0	* d0.w = 機能コード $01FB / MPU MFP マスク設定
		moveq.l	#-1,d1		* d1.l = 負（割り込みレベル/マスク情報取得）
		trap	#2		* 割り込みレベル/マスク情報取得
					* d0.l = 現在の割り込みレベル/マスク値
		move.l	d0,d1
		bclr.l	#6,d1		* d0.l = 加工した割り込みレベル/マスク値
		move.w	#$01FB,d0	* d0.w = 機能コード $01FB : MPU MFP マスク設定
		trap	#2		* 割り込みレベル/マスク情報設定

@@:
	movem.l	(sp)+,d0-d1		* レジスタ復活
	rts




*==========================================================================
*
*	PAM8a 常駐判定サブルーチン
*
*	CHK_PCM8A
*
*	機能：	PCM8A の常駐判定をします。
*		ユーザーモードからでも実行できます。
*
*	破壊：	無し
*
*	戻値：	d0.l =  PCM8A のバージョン*100（10進）
*			非常駐なら 0
*
*--------------------------------------------------------------------------

CHK_PCM8A:

	movem.l	d1/a0-a1,-(sp)		* レジスタ退避


*-------[ スーパーバイザーモードへ ]
	suba.l	a1,a1
	iocs	_B_SUPER		* スーパーバイザーモードへ
	move.l	d0,-(sp)		*（もともとスーパーバイザーモードなら d0.l=-1）


*-------[ PCM8A 常駐判定 ]
	moveq.l	#0,d1			* 戻値（d1.l）を初期化

	movea.l	$0088,a0		* a0.l = 例外ベクタ $0022
	lea.l	-16(a0),a0		* a0.l = PCM8a 内ラベルアドレス
	lea.l	CHK_CODE(pc),a1		* a1.l = 常駐判定文字列アドレス

	moveq.l	#4,d0			* d0.l = dbraカウンター初期値
@@:	cmpm.b	(a0)+,(a1)+		* １文字比較
	bne.b	EXIT_CHK_PCM8A		* 異なるなら強制終了
	dbra.w	d0,@b			* ５文字比較するまで繰り返す

	addq.l	#3,a0			* a0.l を 3 文字分スキップ

	moveq.l	#7,d0			* d0.l = dbraカウンター初期値
@@:	cmpm.b	(a0)+,(a1)+		* １文字比較
	bne.b	EXIT_CHK_PCM8A		* 異なるなら強制終了
	dbra.w	d0,@b			* 8 文字比較するまで繰り返す

	move.l	#'PCMA',d1		* d1.l = 'PCMA'
	iocs	_ADPCMMOD
	move.l	d0,d1			* d1.l = バージョン*100（10進）


*-------[ ユーザーモードへ ]
EXIT_CHK_PCM8A:
	move.l	(sp)+,d0
	bmi.b	@F			* スーパーバイザーモードから実行されていたら戻す必要無し
		movea.l	d0,a1
		iocs	_B_SUPER	* ユーザーモードへ
@@:
	move.l	d1,d0			* d0.l = 戻値（バージョン*100（10進）。非常駐なら 0）
	movem.l	(sp)+,d1/a0-a1		* レジスタ復活
	rts


*-------[ 常駐判定文字列 ]
CHK_CODE:
	dc.b	'PCM8A'
	dc.b	'PCM8/048'

	.even


