/*
	XSP 利用サンプルプログラム

	[動作]
		プログラムを起動すると、動作条件を要求してきますのでキーボードから
		数値を入力してください。何も入力せずそのままリターンキーを押すと、
		デフォルト値が適用されます。数値の入力を済ませると、サンプルプログ
		ラムが開始します。

		画面上を指定枚数のパネルが動き回るデモが動作します。指定枚数のうち
		半分が単体スプライトで、残りの半数が複合スプライトで表示されます。
		画面左端に、スプライトダブラー処理のラスタ分割位置を "→" で表示し
		ます。

	[解説]
		XSP システムを用いたより実践的なプログラムの例です。

		以下の 4 点を行なっています。

			1) 各種割り込み処理の実行
			2) 単体スプライトの表示
			3) 複合スプライトの表示
			4) PCM8A との割り込み衝突の回避

		パネルに書かれている番号は表示優先度を表します。優先度破綻軽減モー
		ドでは、異なる優先度のパネル間の表示優先度が保護されます。同一優先
		度のパネル間の表示優先度は保護されません。XSP_MODE 2 が優先度破綻を
		軽減しないモード、XSP_MODE 3 優先度破綻を軽減するモードです。
		XSP_MODE 2 と 3 の違いを、パネル間の表示優先度に注目しながら確認し
		てみて下さい。

		また、PCM8A 使用時でも衝突することなく動作していることを確認するた
		め PCM8A 常駐下、PCM ドラムを多チャンネル用いた曲を演奏した状態でも
		実行してみて下さい。その場合、ミュージックドライバーには MCDRV か 
		ZMUSIC を用い、ZMUSIC では常駐時にスイッチ -M を指定してラスタ割り
		込みを許可して下さい。MXDRV はラスタ割り込みを許可していないので使
		用不可です。

		起動時に、ラスタ分割 Y 座標自動調整に on を指定した場合、表示数の
		多いラインを探索して動的にラスタ分割が更新されます。
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>
#include <doslib.h>
#include <iocslib.h>
#include <graph.h>
#include <math.h>
#include "../../XSP/XSP2lib.H"
#include "../../PCM8Afnc/PCM8Afnc.H"

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
} panel[512];


/*----------------------------[ コンソールから数値入力 ]------------------------------*/

int input2(
	char *mes,	/* メッセージ */
	int def		/* デフォルト値 */
){
	char	str[0x100] = {0};
	int		tmp;

	printf("%s (default=%d) :", mes, def);
	tmp = atoi(gets(str));
	printf("\n");
	if (tmp == 0) tmp = def;
	return(tmp);
}


/*-------------------------[ 帰線期間割り込みサブルーチン ]---------------------------*/

void ras_scroll_init()
{
	wave_ptr	= wave_ptr_00;
	wave_ptr_00	=(wave_ptr_00 + 1) & 255;
}


/*--------------------------[ ラスタ割り込みサブルーチン ]----------------------------*/

void ras_scroll()
{
	*(short *)(0xE80018) = wave[wave_ptr];	/* グラフィックプレーン0 X座標 */
	wave_ptr = (wave_ptr + 1) & 255;
}


/*-------------------------------------[ MAIN ]---------------------------------------*/

void main()
{
	int		i, j;
	int		panel_max;
	int		mode;
	int		crt;
	int		vsync_interval;
	int		max_delay;
	int		adjust_divy;
	int		min_divh;
	int		raster_ofs;
	int		raster_scroll_test;
	FILE	*fp;


	mode			= input2("	XSP_MODE", 3);
	crt				= input2("	CRT_MODE [1]=31Khz [2]=15Khz", 1);
	vsync_interval	= input2("	垂直同期の間隔", 1);
	max_delay		= input2("	バッファ数 [1]=ダブルバッファ相当 [2]=トリプルバッファ相当", 2) - 1;
	adjust_divy		= input2("	ラスタ分割 Y 座標自動調整 [1]=ON [2]=OFF", 1);
	min_divh		= input2("	ラスタ分割ブロック縦幅最小値", 24);
	if (crt == 1) {
		raster_ofs	= input2("	スプライト転送ラスタオフセット (31Khz)", xsp_raster_ofs_for31khz_get());
	} else {
		raster_ofs	= input2("	スプライト転送ラスタオフセット (15Khz)", xsp_raster_ofs_for15khz_get());
	}
	raster_scroll_test	= input2("	ラスタスクロールテスト [1]=ON [2]=OFF", 1);
	panel_max			= input2("	パネル枚数", 32);
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

	/* 簡易説明 */
	printf("何かキーを押すと終了します。\n");

	/* カーソル表示 OFF */
	B_CUROFF();


	/*------------------[ PCG データ読み込み ]------------------*/

	fp = fopen("../PANEL.SP", "rb");
	if (fp == NULL) {
		CRTMOD(0x10);
		printf("../PANEL.SP が open できません。\n");
		exit(1);
	}
	fread(
		pcg_dat,
		128,		/* 1PCG = 128byte */
		256,		/* 256PCG */
		fp
	);
	fclose(fp);


	/*--------[ スプライトパレットデータ読み込みと定義 ]--------*/

	fp = fopen("../PANEL.PAL", "rb");
	if (fp == NULL) {
		CRTMOD(0x10);
		printf("../PANEL.PAL が open できません。\n");
		exit(1);
	}
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

	/* 垂直同期の間隔を指定 */
	xsp_vsync_interval_set(vsync_interval);

	/* ラスタ分割 Y 座標の自動調整 */
	if (adjust_divy == 1) {
		xsp_auto_adjust_divy(1);
		xsp_min_divh_set(min_divh);
	} else {
		xsp_auto_adjust_divy(0);
	}

	/* スプライト転送ラスタオフセットの設定 */
	if (crt == 1) {
		xsp_raster_ofs_for31khz_set(raster_ofs);
	} else {
		xsp_raster_ofs_for15khz_set(raster_ofs);
	}

	/* PCG データと PCG 配置管理をテーブルを指定 */
	xsp_pcgdat_set(pcg_dat, pcg_alt, sizeof(pcg_alt));

	/* 複合スプライト形状データを指定 */
	xsp_objdat_set(ref_dat);

	/* PCM8A との衝突を回避 */
	pcm8a_vsyncint_on();


	/*--------------[ キャラクタ 512 個分初期化 ]---------------*/

	for (i = 0; i < 512; i++) {
		panel[i].x		= ((rand() / 16 & 255) + 8) * 64;	/* X 座標初期化 */
		panel[i].y		= ((rand() / 16 & 255) + 8) * 64;	/* Y 座標初期化 */
		panel[i].pt		= i & 7;							/* スプライトパターン No. を初期化 */
		panel[i].info	= 0x138 + (i & 7) * 0x101;			/* カラー 1、優先度 0x38 ～ 0x3F */
		panel[i].vx		= (rand() / 16 & 127) - 64;			/* X 方向移動量 */
		panel[i].vy		= (rand() / 16 & 127) - 64;			/* Y 方向移動量 */
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
		wave[i] = sin(3.1415926535898 * (double)i / 128) * 64;
	}


	/*-------------------[ 割り込み処理設定 ]-------------------*/

	if (raster_scroll_test == 1) {
		/* フォント表示 */
		symbol(0, 0x10, "ラスタスクロールと", 1, 4, 2, 1, 0);
		symbol(0, 0x90, "スプライトダブラ混在", 1, 4, 2, 1, 0);

		/* 帰線期間割り込み開始 */
		xsp_vsyncint_on(ras_scroll_init);

		/* ラスタ割り込み開始 */
		xsp_hsyncint_on(time_chart);
	}


	/*============================[ キャラが跳ね回るデモ ]==============================*/

	/* 何かキーを押すまでループ */
	while (INPOUT(0xFF) == 0) {
		/* 垂直同期 */
		xsp_vsync2(max_delay);

		/* 半分は単体スプライトで表示 */
		for (i = 0; i < panel_max / 2; i++) {
			panel[i].x += panel[i].vx;
			panel[i].y += panel[i].vy;
			xsp_set(panel[i].x >> 6, panel[i].y >> 6, panel[i].pt, panel[i].info);
			if (panel[i].x <= 0 || 0x110 * 64 <= panel[i].x) panel[i].vx =- panel[i].vx;
			if (panel[i].y <= 0 || 0x110 * 64 <= panel[i].y) panel[i].vy =- panel[i].vy;
		}

		/* 半分は複合スプライトで表示 */
		for (i = panel_max / 2; i < panel_max; i++) {
			panel[i].x += panel[i].vx;
			panel[i].y += panel[i].vy;
			xobj_set(panel[i].x >> 6, panel[i].y >> 6, panel[i].pt, panel[i].info);
			if (panel[i].x <= 0 || 0x110 * 64 <= panel[i].x) panel[i].vx =- panel[i].vx;
			if (panel[i].y <= 0 || 0x110 * 64 <= panel[i].y) panel[i].vy =- panel[i].vy;
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


