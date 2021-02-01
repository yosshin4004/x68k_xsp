/*
	XSP 利用サンプルプログラム

	1) 各種割り込み処理の実行
	2) 単体スプライトの表示
	3) 複合スプライトの表示
	4) PCM8A との割り込み衝突の回避
	の 4 点を行なっています。

	プログラムを起動するといろいろ尋ねてきますが、何も入力せずそのままリ
	ターンキーを押すと省略したと見なされ、デフォルト値が設定されます。

	数値の入力を済ませると、画面上を指定枚数のパネルが動き回るデモが始ま
	ります（その半数は単体スプライトのパネル、残りの半数は複合スプライト
	のパネルです）。パネルに書かれている番号は表示優先度を表します。優先
	度破綻軽減モードでは、異なる優先度のパネル間の表示優先度が保護されま
	す（同一優先度のパネル間の表示優先度は保護されません）。XSP_MODE の
	デフォルト値は 3、つまり優先度破綻軽減モードです。これに 2 を指定す
	ると、優先度破綻軽減が行われなくなります。3 を指定した場合と 2 を指
	定した場合の動作の違いを、パネル間の表示優先度に注目しながら確認して
	みて下さい。

	また、PCM8A 使用時でも衝突することなく動作していることを確認するため
	PCM8A 常駐下、PCM ドラムを多チャンネル用いた曲を演奏した状態でも実行
	してみて下さい。その場合、ミュージックドライバーには MCDRV か ZMUSIC
	を用い、ZMUSIC では常駐時にスイッチ -M を指定してラスタ割り込みを許
	可して下さい。MXDRV はラスタ割り込みを許可していないので使用不可です。

	画面左端に表示されている矢印は、スプライトダブラー処理のラスタ分割位
	置を示しています。起動時に、ラスタ分割 Y 座標自動調整に on を指定し
	た場合、表示数の多いラインを探索して動的に更新される様子を矢印の位置
	から確認できます。
*/

#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <doslib.h>
#include <iocslib.h>
#include <graph.h>
#include <math.h>
#include "../../XSP/XSP2lib.H"
#include "../../PCM8Afnc/PCM8Afnc.H"

int		input2(char *mes, int def);
void	ras_scroll();
void	ras_scroll_init();

/* スプライト PCG パターン最大使用数 */
#define	PCG_MAX		256


/*------------------------------------[ XSP 関連 ]------------------------------------*/

/*
	XSP 用 PCG 配置管理テーブル
	スプライト PCG パターン最大使用数 + 1 バイトのサイズが必要。
*/
char	pcg_alt[PCG_MAX + 1];

/* PCG データファイル読み込みバッファ */
char	pcg_dat[PCG_MAX * 128];

/* XSP 複合スプライトフレームデータ */
XOBJ_FRM_DAT	frm_dat[512];

/* XSP 複合スプライトリファレンスデータ */
XOBJ_REF_DAT	ref_dat[512];

/* ユーザー側ラスタ割り込みタイムチャート */
XSP_TIME_CHART	time_chart[512];

/* パレットデータファイル読み込みバッファ */
unsigned short	pal_dat[256];


/*------------------------[ ラスタスクロール用 sin テーブル ]-------------------------*/

/* sin テーブル */
short	wave[256];

/* sin テーブル読み出し位置のインデックス */
short	wave_ptr = 0;

/* sin テーブル読み出し位置のインデックスの初期値 */
short	wave_ptr_00 = 0;


/*-----------------------------[ キャラクタ管理構造体 ]-------------------------------*/

/* 512 個分のキャラクタを扱う構造体 */
struct {
	short	x, y;		/* 座標 */
	short	pt;			/* スプライトパターン No. */
	short	info;		/* 反転コード・色・優先度を表すデータ */
	short	vx, vy;		/* 移動量 */
	int		dummy;		/* 高速化のため構造体サイズをパディング */
} SP[512];


/*-------------------------------------[ MAIN ]---------------------------------------*/
void main()
{
	int		i, j;
	int		panel_max;
	int		mode;
	int		crt;
	int		adjust_divy;
	int		min_divh;
	int		ras_int;
	FILE	*fp;


	mode		= input2("	XSP_MODE ", 3);
	crt			= input2("	CRT_MODE [1]=31Khz : [2]=15Khz ", 1);
	adjust_divy	= input2("	ラスタ分割 Y 座標自動調整  [1]=ON : [2]=OFF ", 1);
	min_divh	= input2("	ラスタ分割ブロック縦幅最小値 ", 32);
	ras_int		= input2("	ラスタスクロール  [1]=ON : [2]=OFF ", 1);
	panel_max	= input2("	パネル枚数 ", 32);
	if (panel_max > 512) panel_max = 512;


	/*---------------------[ 画面を初期化 ]---------------------*/

	if (crt == 1) {
		/* 256x256 dot 16 色グラフィックプレーン 4 枚 31KHz */
		CRTMOD(6);
	} else {
		/* 256x256 dot 16 色グラフィックプレーン 4 枚 15KHz */
		CRTMOD(7);
	}

	/* グラフィック表示 ON */
	G_CLR_ON();

	/* スプライト表示を ON */
	SP_ON();

	/* BG0 表示 OFF */
	BGCTRLST(0, 0, 0);

	/* BG1 表示 OFF */
	BGCTRLST(1, 1, 0);

	/* グラフィックパレット 1 番を真っ白にする */
	GPALET(1, 0xFFFF);

	/* カーソル表示 OFF */
	B_CUROFF();


	/*------------------[ PCG データ読み込み ]------------------*/

	fp = fopen("../PANEL.SP", "rb");
	fread(
		pcg_dat,
		128,		/* 1PCG = 128byte */
		256,		/* 256PCG */
		fp
	);
	fclose(fp);


	/*--------[ スプライトパレットデータ読み込みと定義 ]--------*/

	fp = fopen("../PANEL.PAL", "rb");
	fread(
		pal_dat,
		2,			/* 1color = 2byte */
		256,		/* 16color * 16block */
		fp
	);
	fclose(fp);

	/* スプライトパレットに転送 */
	for (i = 0; i < 256; i++) {
		SPALET((i & 15) | (1 << 0x1F), i / 16, pal_dat[i]);
	}


	/*-----------[ 複合スプライトの形状データを作成 ]-----------*/

	j = 0;

	for (i = 0; i < 16; i++) {
		ref_dat[i].num	= 16;			/* 合成スプライト数 */
		ref_dat[i].ptr	= &frm_dat[j];	/* 参照するフレームデータへのポインタ */

		frm_dat[j].vx	= -0x18;
		frm_dat[j].vy	= -0x18;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;


		frm_dat[j].vx	= -0x30;
		frm_dat[j].vy	=  0x10;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;


		frm_dat[j].vx	= -0x30;
		frm_dat[j].vy	=  0x10;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;


		frm_dat[j].vx	= -0x30;
		frm_dat[j].vy	=  0x10;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;

		frm_dat[j].vx	=  0x10;
		frm_dat[j].vy	=  0;
		frm_dat[j].pt	=  i;
		frm_dat[j].rv	=  0;
		j++;
	}


	/*---------------------[ XSP を初期化 ]---------------------*/

	/* XSP の初期化 */
	xsp_on();

	/* 動作モード設定 */
	xsp_mode(mode);

	/* ラスタ分割 Y 座標の自動調整 */
	if (adjust_divy == 1) {
		xsp_auto_adjust_divy(1);
		xsp_min_divh_set(min_divh);
	} else {
		xsp_auto_adjust_divy(0);
	}

	/* PCG データと PCG 配置管理をテーブルを指定 */
	xsp_pcgdat_set(pcg_dat, pcg_alt, sizeof(pcg_alt));

	/* 複合スプライト形状データを指定 */
	xsp_objdat_set(ref_dat);

	/* PCM8A との衝突を回避 */
	pcm8a_vsyncint_on();


	/*--------------[ キャラクタ 512 個分初期化 ]---------------*/

	for (i = 0; i < 512; i++) {
		SP[i].x		= ((rand() / 16 & 255) + 8) * 64;	/* X 座標初期化 */
		SP[i].y		= ((rand() / 16 & 255) + 8) * 64;	/* Y 座標初期化 */
		SP[i].pt	= i & 7;							/* スプライトパターン No. を初期化 */
		SP[i].info	= 0x138 + (i & 7) * 0x101;			/* カラー 1、優先度 0x38 ～ 0x3F */
		SP[i].vx	= (rand() / 16 & 127) - 64;			/* X 方向移動量 */
		SP[i].vy	= (rand() / 16 & 127) - 64;			/* Y 方向移動量 */
	}


	/*------[ ユーザー側ラスタ割り込みタイムチャート作成 ]------*/

	i = 0;
	for (j = 0; j < 256; j += 4) {
		time_chart[i].ras_no	= j * 2 + 32;
		time_chart[i].proc		= ras_scroll;
		i++;
	}

	time_chart[i].ras_no = -1;		/* エンドマーク */


	/*----------[ ラスタスクロール用 sin テーブル作成 ]---------*/

	for (i = 0; i < 256; i++) {
		wave[i] = sin( 3.1415926535898 * (double)i / 128 ) * 64;
	}


	/*-------------------[ 割り込み処理設定 ]-------------------*/

	if (ras_int == 1) {
		/* フォント表示 */
		symbol(0, 0x10, "ラスタスクロールと", 1, 4, 2, 1, 0);
		symbol(0, 0x90, "スプライトダブラ混在", 1, 4, 2, 1, 0);

		/* 帰線期間割り込み開始 */
		xsp_vsyncint_on(ras_scroll_init);

		/* ラスタ割り込み開始 */
		xsp_hsyncint_on(time_chart);
	}


	/*============================[ キャラが跳ね回るデモ ]==============================*/

	while (INPOUT(0xFF) == 0) {
		/* 垂直同期 */
		xsp_vsync(1);

		/* 半分は単体スプライトで表示 */
		for (i = 0; i < panel_max / 2; i++) {
			SP[i].x += SP[i].vx;
			SP[i].y += SP[i].vy;
			xsp_set(SP[i].x >> 6, SP[i].y >> 6, SP[i].pt, SP[i].info);
			if (SP[i].x <= 0 || 0x110 * 64 <= SP[i].x) SP[i].vx =- SP[i].vx;
			if (SP[i].y <= 0 || 0x110 * 64 <= SP[i].y) SP[i].vy =- SP[i].vy;
		}

		/* 半分は複合スプライトで表示 */
		for (i = panel_max / 2; i < panel_max; i++) {
			SP[i].x += SP[i].vx;
			SP[i].y += SP[i].vy;
			xobj_set(SP[i].x >> 6, SP[i].y >> 6, SP[i].pt, SP[i].info);
			if (SP[i].x <= 0 || 0x110 * 64 <= SP[i].x) SP[i].vx =- SP[i].vx;
			if (SP[i].y <= 0 || 0x110 * 64 <= SP[i].y) SP[i].vy =- SP[i].vy;
		}

		/* ラスタ分割 Y 座標に矢印表示（デバッグ用）*/
		xsp_set(16, xsp_divy_get(0), 9, 0x13F);
		xsp_set(16, xsp_divy_get(1), 9, 0x13F);
		xsp_set(16, xsp_divy_get(2), 9, 0x13F);
		xsp_set(16, xsp_divy_get(3), 9, 0x13F);
		xsp_set(16, xsp_divy_get(4), 9, 0x13F);
		xsp_set(16, xsp_divy_get(5), 9, 0x13F);
		xsp_set(16, xsp_divy_get(6), 9, 0x13F);

		/* スプライトを一括表示する */
		xsp_out();
	}


	/*-----------------------[ 終了処理 ]-----------------------*/

	/* XSP の終了処理 */
	xsp_off();

	/* 画面モードを戻す */
	CRTMOD(0x10);
}


/*
	デフォルト値有りの input() 関数
*/
int input2(
	char *mes,	/* メッセージ */
	int def		/* デフォルト値 */
){
	char	str[35];
	int		tmp;

	printf("%s[ 省略=%d ]=", mes, def);
	str[0] = 32;
	tmp = atoi(cgets(str));
	printf("\n");
	if (tmp == 0) tmp = def;
	return(tmp);
}


/*
	帰線期間割り込みサブルーチン
*/
void ras_scroll_init()
{
	wave_ptr	= wave_ptr_00;
	wave_ptr_00	=(wave_ptr_00 + 1) & 255;
}


/*
	ラスタ割り込みサブルーチン
*/
void ras_scroll()
{
	*(short *)(0xE80018) = wave[wave_ptr];	/* グラフィックプレーン0 X座標 */
	wave_ptr = (wave_ptr + 1) & 255;
}


