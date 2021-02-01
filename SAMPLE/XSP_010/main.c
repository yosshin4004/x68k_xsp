/*
	XSP 利用サンプルプログラム

	1 枚のスプライトで表示されたキャラクタを、ジョイスティックで 8 方向に
	動かすサンプルプログラムです。XSP システムを用いた最も簡単なプログラム
	の例です。
*/

#include <stdio.h>
#include <stdlib.h>
#include <doslib.h>
#include <iocslib.h>
#include "../../XSP/XSP2lib.H"

/* スプライト PCG パターン最大使用数 */
#define	PCG_MAX		256


/*
	XSP 用 PCG 配置管理テーブル
	スプライト PCG パターン最大使用数 + 1 バイトのサイズが必要。
*/
char	pcg_alt[PCG_MAX + 1];

/* PCG データファイル読み込みバッファ */
char	pcg_dat[PCG_MAX * 128];

/* パレットデータファイル読み込みバッファ */
unsigned short pal_dat[256];


/*-------------------------------------[ MAIN ]---------------------------------------*/
void main()
{
	int		i;
	FILE	*fp;

	/* キャラクタ管理構造体 */
	struct {
		short	x, y;		/* 座標 */
		short	pt;			/* スプライトパターン No. */
		short	info;		/* 反転コード・色・優先度を表すデータ */
	} MYCHARA;


	/*---------------------[ 画面を初期化 ]---------------------*/

	/* 256x256 dot 16 色グラフィックプレーン 4 枚 31KHz */
	CRTMOD(6);

	/* スプライト表示を ON */
	SP_ON();

	/* BG0 表示 OFF */
	BGCTRLST(0, 0, 0);

	/* BG1 表示 OFF */
	BGCTRLST(1, 1, 0);

	/* 簡易説明 */
	printf("ジョイスティックで移動可能");

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


	/*---------------------[ XSP を初期化 ]---------------------*/

	/* XSP の初期化 */
	xsp_on();

	/* PCG データと PCG 配置管理をテーブルを指定 */
	xsp_pcgdat_set(pcg_dat, pcg_alt, sizeof(pcg_alt));


	/*===========================[ スティックで操作するデモ ]=============================*/

	/* 初期化 */
	MYCHARA.x		= 0x88;		/* X 座標初期値 */
	MYCHARA.y		= 0x88;		/* Y 座標初期値 */
	MYCHARA.pt		= 0;		/* スプライトパターン No. */
	MYCHARA.info	= 0x013F;	/* 反転コード・色・優先度を表すデータ */

	/* 何かキーを押すまでループ */
	while (INPOUT(0xFF) == 0) {
		int	stk;

		/* 垂直同期 */
		xsp_vsync(1);

		/* スティックの入力に合せて移動 */
		stk = JOYGET(0);
		if ((stk & 1) == 0  &&  MYCHARA.y > 0x010) MYCHARA.y -= 1;	/* 上に移動 */
		if ((stk & 2) == 0  &&  MYCHARA.y < 0x100) MYCHARA.y += 1;	/* 下に移動 */
		if ((stk & 4) == 0  &&  MYCHARA.x > 0x010) MYCHARA.x -= 1;	/* 左に移動 */
		if ((stk & 8) == 0  &&  MYCHARA.x < 0x100) MYCHARA.x += 1;	/* 右に移動 */

		/* スプライトの表示登録 */
		xsp_set(MYCHARA.x, MYCHARA.y, MYCHARA.pt, MYCHARA.info);
		/*
			↑ここは、
				xsp_set_st(&MYCHARA);
			と記述すれば、より高速に実行できる。
		*/

		/* スプライトを一括表示する */
		xsp_out();
	}


	/*-----------------------[ 終了処理 ]-----------------------*/

	/* XSP の終了処理 */
	xsp_off();

	/* 画面モードを戻す */
	CRTMOD(0x10);
}




