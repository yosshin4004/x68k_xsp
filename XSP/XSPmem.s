
	.text
	.even

vector_118_bak:	dc.l	0			* 変更前の V-disp ベクタ
vector_138_bak:	dc.l	0			* 変更前の CRT-IRQ ベクタ
raster_No_bak:	dc.w	0			* 変更前の CRT-IRQ ラスタ No.
MFP_bak:	dcb.b	$18,0			* 変更前の MFP

	.even


*--------------[ スプライト仮バッファのポインタ ]
buff_pointer:
		dc.l	buff_top_adr_no_pc

*--------------[ ユーザー指定帰線期間割り込み ]
vsyncint_sub:	dc.l	dummy_proc		* 割り込み処理サブルーチンアドレス（初期値はダミー）

*--------------[ ラスタ割り込み関係 ]
hsyncint_sub:	dc.l	dummy_proc		* 割り込み処理サブルーチンアドレス（初期値はダミー）
xsp_chart_ptr:	dc.l	dummy_chart		* XSP 側チャートへのポインタ（初期値はダミー）
usr_chart_ptr:	dc.l	dummy_chart		* USR 側チャートへのポインタ（初期値はダミー）
usr_chart:	dc.l	dummy_chart		* USR 側チャートへのポインタ初期値（USR 指定可能）

*----------------[ ラスタ分割 Y 座標 ]
divy_AB:	dc.w	36			* ラスタ分割バッファAB 境界 Y
divy_BC:	dc.w	36+32			* ラスタ分割バッファBC 境界 Y
divy_CD:	dc.w	36+32+36		* ラスタ分割バッファCD 境界 Y
divy_DE:	dc.w	36+32+36+32		* ラスタ分割バッファDE 境界 Y
divy_EF:	dc.w	36+32+36+32+36		* ラスタ分割バッファEF 境界 Y
divy_FG:	dc.w	36+32+36+32+36+32	* ラスタ分割バッファFG 境界 Y
divy_GH:	dc.w	36+32+36+32+36+32+36	* ラスタ分割バッファGH 境界 Y

*--------------[ その他 ]
sp_mode:	dc.w	2			* XSP のモード（1～3）

R65535:		dc.w	0			* システム内部カウンタ

write_struct:		dc.l	XSP_STRUCT_no_pc+STRUCT_SIZE	* 書換用バッファ管理構造体アドレス
disp_struct:		dc.l	XSP_STRUCT_no_pc		* 表示用バッファ管理構造体アドレス
penging_disp_count:	dc.w	0				* 保留状態の表示リクエスト数

vsync_count:	dc.w	0			* 帰線期間の度にインクリメントされる

vsync_interval_count_max:	dc.w	1	* vsync_interval カウンタ max 値
vsync_interval_count_down:	dc.w	1	* vsync_interval カウントダウン

sp_ref_adr:	dc.l	0			* 複合スプライトのリファレンスデータへのポインタ

pcg_alt_adr:	dc.l	0			* pcg_alt のポインタ（ユーザー指定）

pcg_dat_adr:	dc.l	0			* PCG データのポインタ（ユーザー指定）

OX_level:	dc.b	0			* OX_tbl 水位
	.even
OX_mask_renew:	dc.w	0			* OX_mask 更新があったことを示すフラグ（非 0 で更新）
OX_chk_top:	dc.l	0			* OX_tbl 検索開始アドレス
OX_chk_ptr:	dc.l	0			* OX_tbl 検索ポインタ
OX_chk_size:	dc.w	0			* OX_tbl 検索サイズ - 1（dbra カウンタとする）

a7_bak1:	dc.l	0			* A7 レジスタを保存（レジスタ退避直後）

usp_bak:	dc.l	0			* usp 保存

XSP_flg:	dc.b	0			* XSP 初期化状態のフラグ（8 ビット）
						* bit0 = 組込み状態か？
						* bit1 = PCG_DAT,PCG_ALT 指定済か？
	.even

vertical_flg:	dc.w	0			* 縦画面モードフラグ（非 0 = 縦画面モード）

min_divh:	dc.w	32			* ラスタ分割ブロック縦幅最小値（非 0 = 自動調整）

auto_adjust_divy_flg:	dc.w	1		* ラスタ分割 Y 座標自動調整フラグ（非 0 = 自動調整）

raster_ofs_for31khz:	dc.w	16*2+8		* スプライト転送ラスタの調整値（31KHz 用）
						*	+16*2 は 31KHz 時のスプライトの縦幅ラスタ数。
						*	+24 はタイミング調整用。
						*	XSP ver2.00 互換にするには +24 とする。
						*	XM6 だと +8 が妥当。
raster_ofs_for15khz:	dc.w	16*1+0		* スプライト転送ラスタの調整値（15KHz 用）
						*	+16*1 は 15KHz 時のスプライトの縦幅ラスタ数。
						*	+0 はタイミング調整用。
						*	XSP ver2.00 互換にするには +16 とする。


*==============================================================

	.bss
	.even


*--------------[ XSP バッファ管理構造体（バッファ No. 別）]
XSP_STRUCT_no_pc:
		ds.b	STRUCT_SIZE*3
endof_XSP_STRUCT_no_pc:


*----------------[ スプライト仮バッファ & 優先度ソート関係のバッファ ]

		ds.b	8		* end_mark（pr = 0）
buff_top_adr_no_pc:
		ds.b	8*SP_MAX	* push可能枚数 x 8 バイト
buff_end_adr_no_pc:
		ds.b	8		* end_mark（8 バイトの -1）兼 終点ダミー PR ブロック
		ds.b	8*SP_MAX	* ソートチェイン作成バッファ
		ds.b	8		* 終点ダミーチェイン

pr_top_tbl_no_pc:
		ds.l	64		* PR 別先頭テーブル
		ds.l	1		* end_mark 用


*----------------[ ラスタ別分割ソート済みスプライト保存バッファ ]

*	バッファは表示用・書換用・予備用の合計 3 本（No.0～2）
*	それぞれ分割ラスタ別に 4 つに細分されます。


*	[ + $0000 = バッファNo.0 ]
div_buff_0A_no_pc:
		ds.b	8*64		* ラスタ分割バッファA
		ds.b	8		* end_mark
div_buff_0B_no_pc:
		ds.b	8*64		* ラスタ分割バッファB
		ds.b	8		* end_mark
div_buff_0C_no_pc:
		ds.b	8*64		* ラスタ分割バッファC
		ds.b	8		* end_mark
div_buff_0D_no_pc:
		ds.b	8*64		* ラスタ分割バッファD
		ds.b	8		* end_mark
div_buff_0E_no_pc:
		ds.b	8*64		* ラスタ分割バッファE
		ds.b	8		* end_mark
div_buff_0F_no_pc:
		ds.b	8*64		* ラスタ分割バッファF
		ds.b	8		* end_mark
div_buff_0G_no_pc:
		ds.b	8*64		* ラスタ分割バッファG
		ds.b	8		* end_mark
div_buff_0H_no_pc:
		ds.b	8*64		* ラスタ分割バッファH
		ds.b	8		* end_mark


*	[ + $1040 = バッファNo.1 ]
div_buff_1A_no_pc:
		ds.b	8*64		* ラスタ分割バッファA
		ds.b	8		* end_mark
div_buff_1B_no_pc:
		ds.b	8*64		* ラスタ分割バッファB
		ds.b	8		* end_mark
div_buff_1C_no_pc:
		ds.b	8*64		* ラスタ分割バッファC
		ds.b	8		* end_mark
div_buff_1D_no_pc:
		ds.b	8*64		* ラスタ分割バッファD
		ds.b	8		* end_mark
div_buff_1E_no_pc:
		ds.b	8*64		* ラスタ分割バッファE
		ds.b	8		* end_mark
div_buff_1F_no_pc:
		ds.b	8*64		* ラスタ分割バッファF
		ds.b	8		* end_mark
div_buff_1G_no_pc:
		ds.b	8*64		* ラスタ分割バッファG
		ds.b	8		* end_mark
div_buff_1H_no_pc:
		ds.b	8*64		* ラスタ分割バッファH
		ds.b	8		* end_mark


*	[ + $2080 = バッファNo.2 ]
div_buff_2A_no_pc:
		ds.b	8*64		* ラスタ分割バッファA
		ds.b	8		* end_mark
div_buff_2B_no_pc:
		ds.b	8*64		* ラスタ分割バッファB
		ds.b	8		* end_mark
div_buff_2C_no_pc:
		ds.b	8*64		* ラスタ分割バッファC
		ds.b	8		* end_mark
div_buff_2D_no_pc:
		ds.b	8*64		* ラスタ分割バッファD
		ds.b	8		* end_mark
div_buff_2E_no_pc:
		ds.b	8*64		* ラスタ分割バッファE
		ds.b	8		* end_mark
div_buff_2F_no_pc:
		ds.b	8*64		* ラスタ分割バッファF
		ds.b	8		* end_mark
div_buff_2G_no_pc:
		ds.b	8*64		* ラスタ分割バッファG
		ds.b	8		* end_mark
div_buff_2H_no_pc:
		ds.b	8*64		* ラスタ分割バッファH
		ds.b	8		* end_mark

*	[ + $30C0 = 転送チェイン情報 ]
div_buff_chain_no_pc:
		ds.b	(8*64+8)*8*3


*----------------[ PCG 配置管理（逆参照）テーブル ]

*	PCG_No.→パターンNo. 変換テーブルです。

pcg_rev_alt_no_pc:
		ds.w	256		* 逆参照 alt 初期値(-1)を書き込むこと


*----------------[ OX テーブル ]

*	各 PCG が使用されているかどうかを表すテーブルです。

OX_tbl_no_pc:
		ds.b	256		* 水位情報
		ds.w	1		* end_mark(0)を書き込むこと
OX_mask_no_pc:
		ds.b	256		* マスク情報（0:off  255:on）


