#ifndef XSP2LIB_H
#define XSP2LIB_H

/* xsp_set_st , xobj_set_st の引数構造体 */

typedef	struct {
	short	x;				/* X 座標 */
	short	y;				/* Y 座標 */
	short	pt;				/* スプライトパターン No. */
	short	info;			/* 反転コード・色・優先度を表わすデータ */
} XSP_SET_ARG;


/* 複合スプライトのフレームデータ構造体 */

typedef	struct	{
	short	vx;				/* 相対座標データ */
	short	vy;				/* 相対座標データ */
	short	pt;				/* スプライトパターン No. */
	short	rv;				/* 反転コード */
} XOBJ_FRM_DAT;


/* 複合スプライトのリファレンスデータ構造体 */

typedef	struct	{
	short	num;			/* 合成スプライト数 */
	void	*ptr;			/* 開始位置のポインタ */
	short	unused;			/*（未使用）*/
} XOBJ_REF_DAT;


/* ラスター割り込み処理のタイムチャート */

typedef	struct	{
	short	ras_no;			/* 割り込みラスタナンバー */
	void	(* proc)();		/* 割り込み処理関数のポインタ */
} XSP_TIME_CHART;



void	xsp_on();
void	xsp_off();
void	xsp_pcgdat_set(const void *pcg_dat, char *pcg_alt, short alt_size);
void	xsp_pcgmask_on(short start_no, short end_no);
void	xsp_pcgmask_off(short start_no, short end_no);
void	xsp_mode(short mode_no);
void	xsp_objdat_set(const void *sp_ref);
short	xsp_vsync(short n);
short	xsp_set(short x, short y, short pt, short info);
void	xobj_set(short x, short y, short pt, short info);
short	xsp_set_st(const void *arg);
void	xobj_set_st(const void *arg);
short	xsp_out();
void	xsp_vertical(short flag);

void	xsp_vsyncint_on(void *proc);
void	xsp_vsyncint_off() ;
void	xsp_hsyncint_on(const void *time_chart);
void	xsp_hsyncint_off();

void	xsp_auto_adjust_divy(short flag);
void	xsp_min_divh_set(short h);
short	xsp_divy_get(short i);

#endif
