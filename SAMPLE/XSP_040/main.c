/*
	XSP 利用サンプルプログラム 4

	モニタを縦置きする縦画面モードの利用手順を示すサンプルプログラムです。
*/

#include <stdio.h>
#include <stdlib.h>
#include <doslib.h>
#include <iocslib.h>
#include "../../XSP/XSP2lib.H"
#include "../../PCG90/PCG90.H"

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
	} player;


	/*---------------------[ 画面を初期化 ]---------------------*/

	/* 256x256dot 16 色グラフィックプレーン 4 枚 31KHz */
	CRTMOD(6);

	/* スプライト表示を ON */
	SP_ON();

	/* BG0 表示 OFF */
	BGCTRLST(0, 0, 0);

	/* BG1 表示 OFF */
	BGCTRLST(1, 1, 0);

	/* 簡易説明 */
	printf("縦画面モードのテスト\nジョイスティックで移動可能");

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

	/*-----------[ PCG データを縦画面用に 90 度回転 ]-----------*/

	for (i = 0; i < 256; i++) {
		pcg_roll90(&pcg_dat[i * 128], 1);
	}

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


	/*---------------------[ XSP を初期化 ]---------------------*/

	/* XSP の初期化 */
	xsp_on();

	/* PCG データと PCG 配置管理をテーブルを指定 */
	xsp_pcgdat_set(pcg_dat, pcg_alt, sizeof(pcg_alt));

	/* 縦画面モード */
	xsp_vertical(1);


	/*===========================[ スティックで操作するデモ ]=============================*/

	/* 初期化 */
	player.x	= 0x88;		/* X 座標初期値 */
	player.y	= 0x88;		/* Y 座標初期値 */
	player.pt	= 0;		/* スプライトパターン No. */
	player.info	= 0x013F;	/* 反転コード・色・優先度を表すデータ */

	/* 何かキーを押すまでループ */
	while (INPOUT(0xFF) == 0) {
		int	stk;

		/* 垂直同期 */
		xsp_vsync(1);

		/* スティックの入力に合せて移動 */
		stk = JOYGET(0);
		if ((stk & 1) == 0  &&  player.y > 0x010) player.y -= 1;	/* 上に移動 */
		if ((stk & 2) == 0  &&  player.y < 0x100) player.y += 1;	/* 下に移動 */
		if ((stk & 4) == 0  &&  player.x > 0x010) player.x -= 1;	/* 左に移動 */
		if ((stk & 8) == 0  &&  player.x < 0x100) player.x += 1;	/* 右に移動 */

		/* スプライトの表示登録 */
		xsp_set(player.x, player.y, player.pt, player.info);
		/*
			↑ここは、
				xsp_set_st(&player);
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



