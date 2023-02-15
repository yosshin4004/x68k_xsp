/*
	XSP 利用サンプルプログラム

	[動作]
		スプライトを 1 枚表示します。スプライトの位置に合わせて、グラフィク
		スプレーンをスクロールさせます。

	[解説]
		XSP によるスプライト表示は内部でバッファリングされ、遅延して画面に
		反映されます。背景のスクロールやパレット変更を行う場合、スプライト
		表示と同期させるには、この遅延を考慮する必要があります。

		XSP はこのような利用ケースを想定し、xsp_out2 関数によるスプライト
		表示リクエスト時に、垂直帰線期間割り込み関数に与える引数を指定でき
		ます。ここで指定した引数は、スプライト表示と同じフレーム数遅延した
		のち垂直帰線期間割り込み関数に伝えられます。このサンプルプログラム
		では、この仕組みを利用して背景のスクロール座標を垂直帰線期間割り込
		み関数に与え、スプライト表示と同期したスクロールを行っています。
*/

#include <stdio.h>
#include <stdlib.h>
#include <doslib.h>
#include <iocslib.h>
#include <math.h>
#include "../../XSP/XSP2lib.H"

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

/* パレットデータファイル読み込みバッファ */
unsigned short pal_dat[256];


/*----------------------------------[ sin テーブル ]----------------------------------*/

/* sin テーブル */
#define NUM_WAVE_ELEMENTS	(512)
short	wave[NUM_WAVE_ELEMENTS];


/*----------------------[ 垂直帰線期間割り込み関数に与える引数 ]----------------------*/

typedef struct {
	short scroll_x;
	short scroll_y;
} VSYNC_INT_ARG;

#define NUM_VSYNC_INT_ARGS	(4)
VSYNC_INT_ARG vsync_int_args[NUM_VSYNC_INT_ARGS] = {0};


/*----------------------------[ 垂直帰線期間割り込み関数 ]----------------------------*/

void vsync_int(const VSYNC_INT_ARG *arg)
{
	if (arg != NULL) {
		/* グラフィクス画面 0 を設定 */
		SCROLL(0, arg->scroll_x, arg->scroll_y);
	}
}

/*-------------------------------------[ MAIN ]---------------------------------------*/
void main()
{
	int		i;
	FILE	*fp;

	/*---------------------[ 画面を初期化 ]---------------------*/

	/* 256x256 dot 16 色グラフィックプレーン 4 枚 31KHz */
	CRTMOD(6);

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
	printf(
		"何かキーを押すと終了します。\n"
	);

	/* カーソル表示 OFF */
	B_CUROFF();

	/* 格子模様を描画 */
	WINDOW(0, 0, 511, 511);
	for (i = 0; i < 512; i+=16) {
		struct LINEPTR arg;
		arg.x1 = 0;
		arg.y1 = i;
		arg.x2 = 511;
		arg.y2 = i;
		arg.color = 1;
		arg.linestyle = 0x5555;
		LINE(&arg);
		arg.x1 = i;
		arg.y1 = 0;
		arg.x2 = i;
		arg.y2 = 511;
		arg.color = 1;
		arg.linestyle = 0x5555;
		LINE(&arg);
	}


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


	/*---------------------[ XSP を初期化 ]---------------------*/

	/* XSP の初期化 */
	xsp_on();

	/* PCG データと PCG 配置管理をテーブルを指定 */
	xsp_pcgdat_set(pcg_dat, pcg_alt, sizeof(pcg_alt));

	/* 垂直帰線期間割り込み開始 */
	xsp_vsyncint_on(vsync_int);


	/*-------------------[ sin テーブル作成 ]-------------------*/

	for (i = 0; i < NUM_WAVE_ELEMENTS; i++) {
		wave[i] = sin(3.1415926535898 * 2 * (double)i / NUM_WAVE_ELEMENTS) * 64;
	}


	/*===========================[ スティックで操作するデモ ]=============================*/

	{
		/* フレームカウント */
		short frame_count = 0;

		/* 何かキーを押すまでループ */
		while (INPOUT(0xFF) == 0) {
			short x, y;

			/* 垂直帰線期間割り込み関数の引数 */
			VSYNC_INT_ARG *arg = &vsync_int_args[frame_count % NUM_VSYNC_INT_ARGS];

			/* 垂直同期 */
			xsp_vsync2(1);

			/* スプライト表示座標 */
			x = wave[frame_count * 2 % NUM_WAVE_ELEMENTS];
			y = wave[frame_count * 3 % NUM_WAVE_ELEMENTS];
			xsp_set(x + 0x80, y + 0x80, 0, 0x013F);

			/* スクロール座標 */ 
			arg->scroll_x = -x;
			arg->scroll_y = -y;

			/*
				スプライトを一括表示する。
				プライト描画に同期して設定するスクロール座標を、
				垂直帰線期間割り込み関数の引数として渡す。
			*/
			xsp_out2(arg);

			/* フレームカウント更新 */
			frame_count++;
		}
	}

	/*-----------------------[ 終了処理 ]-----------------------*/

	/* XSP の終了処理 */
	xsp_off();

	/* 画面モードを戻す */
	CRTMOD(0x10);
}




