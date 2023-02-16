/*
	XSP 利用サンプルプログラム

	[動作]
		プログラムを起動すると、動作条件を要求してきますのでキーボードから
		数値を入力してください。何も入力せずそのままリターンキーを押すと、
		デフォルト値が適用されます。数値の入力を済ませると、サンプルプログ
		ラムが開始します。

		画面上にスプライトが 1 枚表示されます。ジョイスティックで 8 方向に
		移動可能です。

		画面左側に、1 フレームの処理にかかった時間を示す処理負荷ゲージを表
		示します。画面左上に、スプライトの表示リクエストから実際に画面に表
		示されるまでの遅延フレーム数を表示します。

		トリガで、メインループの処理負荷を増減させることができます。処理負
		荷が 1 フレームの許容時間を越えると処理落ちが発生し、許容遅延フレー
		ム数のポリシーに従った処理落ち動作が発生する様子が確認できます。

	[解説]
		スプライトの表示リクエストから実際に画面に表示されるまでの遅延の影
		響を、実際にジョイスティック操作しながら体感で確認するサンプルプロ
		グラムです。

		許容遅延フレーム数をどのように制御するか、ポリシーと動作仕様は以下
		のようになっています。

		モード 1 : 許容遅延フレーム数 0 で固定
			遅延は少なくなりますが、処理落ちが発生すると、フレームレートが
			半分に低下します。

		モード 2 : 許容遅延フレーム数 1 で固定
			遅延はやや大きくなりますが、処理落ちが発生しても、フレームレー
			トが半分に低下しません。1 フレーム先行して描画リクエストを蓄積
			できるので、急激なフレームレート変化を安定化させる効果がありま
			す。

		モード 3 : 許容遅延フレーム数を動的に変更
			処理落ちが発生しない時はモード 1、処理落ちが発生する時はモード
			2 相当の動作になるように動的に調整します。モード 1 の低遅延と、
			モード 2 のフレームレート安定化の両方の長所を取り入れたような
			動作となります。ただし、モード 2 よりもフレームレート安定化の
			効果は下がります。
*/

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <doslib.h>
#include <iocslib.h>
#include <stdlib.h>
#include <basic0.h>
#include "../../XSP/XSP2lib.H"

int input2(char *mes, int def);

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

/* 処理負荷をかけるためアクセスするダミー変数 */
volatile int g_dummy = 0;

/* VSYNC カウンタ */
static volatile short s_vsync_count = 0;

/*------------------------[ 帰線期間割り込み関数に与える引数 ]------------------------*/

/* フレーム番号 */
static short s_frame_count = 0;
static volatile short s_flipped_frame_count = 0;

typedef struct {
	short scroll_x;
	short scroll_y;
	int frame_count;
} VSYNC_INT_ARG;

#define NUM_VSYNC_INT_ARGS	(4)
VSYNC_INT_ARG vsync_int_args[NUM_VSYNC_INT_ARGS] = {0};


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


/*------------------------------[ 帰線期間割り込み関数 ]------------------------------*/

void vsync_int(const VSYNC_INT_ARG *arg)
{
	if (arg != NULL) {
		/* VSYNC カウンタ */
		s_vsync_count++;

		/* グラフィクス画面 0 を設定 */
		SCROLL(0, arg->scroll_x, arg->scroll_y);
		s_flipped_frame_count = arg->frame_count;
	}
}


/*-------------------------------------[ MAIN ]---------------------------------------*/

void main()
{
	int		i;
	FILE	*fp;
	int		delay_policy;

	delay_policy = input2("	遅延対策の方針 [1]=0フレーム固定, [2]=1フレーム固定, [3]=可変", 3);


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

	/* 簡易説明 */
	B_LOCATE(0, 0);
	printf(
		"   ジョイスティックでスプライト\n"
		"   を移動できます。トリガで処理\n"
		"   負荷を増減できます。\n"
		"   何かキーを押すと終了します。\n"
	);
	B_LOCATE(3, 5);
	printf("delay _ frames");

	/* カーソル消去 */
	B_CUROFF();			/* X68000 EnvironmentHandBook p.312 */

	/* グラフィクスプレーン 0 に格子模様を描画 */
	GPALET(1, 0xFFFF);
	APAGE(0);
	WINDOW(0, 0, 511, 511);
	for (i = 0; i < 512; i+=32) {
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

	/* グラフィクスプレーン 1 に処理負荷ゲージを描画 */
	GPALET(2, 0xFFFF);
	APAGE(1);
	WINDOW(0, 0, 511, 511);
	{
		struct FILLPTR arg;
		arg.x1 = 0;
		arg.y1 = 0;
		arg.x2 = 16;
		arg.y2 = 511;
		arg.color = 2;
		FILL(&arg);
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


	/*===========================[ スティックで操作するデモ ]=============================*/

	{
		/* 処理負荷 */
		int workload = 100;

		/* キャラクタ管理構造体 */
		struct {
			short	x, y;		/* 座標 */
			short	pt;			/* スプライトパターン No. */
			short	info;		/* 反転コード・色・優先度を表すデータ */
		} player;
		player.x	= 0x88;		/* X 座標初期値 */
		player.y	= 0x88;		/* Y 座標初期値 */
		player.pt	= 0;		/* スプライトパターン No. */
		player.info	= 0x013F;	/* 反転コード・色・優先度を表すデータ */

		/* 何かキーを押すまでループ */
		while (INPOUT(0xFF) == 0) {
			VSYNC_INT_ARG *arg;

			/* 垂直同期 */
			switch (delay_policy) {
				/* 遅延 0 フレーム固定 */
				case 1:{
					xsp_vsync2(0);
				} break;

				/* 遅延 1 フレーム固定 */
				case 2:{
					xsp_vsync2(1);
				} break;

				/* 遅延フレーム数可変 */
				case 3:{
					static short s_prev_vsync_count = 0;
					short max_delay = 0;
					if (s_prev_vsync_count == s_vsync_count) {
						/*
							前回から 1 フレームの時間が経過していない。
							描画リクエストが蓄積しすぎるので、max_delay を少なくする。
						*/
						max_delay = 0;
					} else {
						/*
							前回から 1 フレームの時間が経過している。
							処理落ちを回避するため、max_delay を緩和する。
						*/
						max_delay = 1;
					}
					xsp_vsync2(max_delay);
					s_prev_vsync_count = s_vsync_count;
				} break;
			}
			GPALET(2, 0xFFFF);
			B_LOCATE(9, 5);
			printf("%d", s_frame_count - s_flipped_frame_count);

			/* スティック操作 */
			{
				/* スティックの入力に合せて移動 */
				int	stk = JOYGET(0);
				if ((stk & 1) == 0  &&  player.y > 0x010) player.y -= 4;	/* 上に移動 */
				if ((stk & 2) == 0  &&  player.y < 0x100) player.y += 4;	/* 下に移動 */
				if ((stk & 4) == 0  &&  player.x > 0x010) player.x -= 4;	/* 左に移動 */
				if ((stk & 8) == 0  &&  player.x < 0x100) player.x += 4;	/* 右に移動 */

				/* トリガで処理負荷変更 */
				if ((stk & 0x20) == 0)                 workload++;			/* トリガー 2 */
				if ((stk & 0x40) == 0 && workload > 0) workload--;			/* トリガー 1 */
			}

			/* 処理負荷をかける */
			for (i = 0; i < workload * 16; i++) {
				g_dummy++;
			}

			/* スプライトの表示登録 */
			xsp_set_st(&player);

			/* 帰線期間割り込み関数の引数作成 */
			arg = &vsync_int_args[s_frame_count % NUM_VSYNC_INT_ARGS];
			arg->scroll_x = s_frame_count * 2 & 511;
			arg->scroll_y = s_frame_count * 2 & 511;
			arg->frame_count = s_frame_count;

			/* スプライトを一括表示する */
			GPALET(2, 16<<11);	/* 処理負荷ゲージに緑を設定 */
			xsp_out2(arg);
			GPALET(2, 0);		/* 処理負荷ゲージに黒を設定 */

			/* フレームカウント更新 */
			s_frame_count++;
		}
	}

	/* XSP の終了処理 */
	xsp_off();


	/* 画面モードを戻す */
	CRTMOD(0x10);
}


