/*----------------------------------------------------------------------------/
/  Petit FatFs - FAT file system module  R0.01a                (C)ChaN, 2009
/-----------------------------------------------------------------------------/
/ Petit FatFs module is an open source software to implement FAT file system to
/ small embedded systems. This is a free software and is opened for education,
/ research and commercial developments under license policy of following trems.
/
/  Copyright (C) 2009, ChaN, all right reserved.
/
/ * The Petit FatFs module is a free software and there is NO WARRANTY.
/ * No restriction on use. You can use, modify and redistribute it for
/   personal, non-profit or commercial use UNDER YOUR RESPONSIBILITY.
/ * Redistributions of source code must retain the above copyright notice.
/
/-----------------------------------------------------------------------------/
/ Jun 15,'09 R0.01a  Branched from FatFs R0.07b
/----------------------------------------------------------------------------*/

#include "pff.h"		/* Petit FatFs configurations and declarations */
#include "diskio.h"		/* Declarations of low level disk I/O functions */
#include "string.h"

/*--------------------------------------------------------------------------

   Private Work Area

---------------------------------------------------------------------------*/

//static
FATFS *FatFs;	/* Pointer to the file system object (logical drive) */

//static
WCHAR LfnBuf[_MAX_LFN + 1];
#define	NAMEBUF(sp,lp)	BYTE sp[12]; WCHAR *lp = LfnBuf
#define INITBUF(dj,sp,lp)	dj.fn = sp; dj.lfn = lp


/* Name status flags */
#define NS			11		/* Offset of name status byte */
#define NS_LOSS		0x01	/* Out of 8.3 format */
#define NS_LFN		0x02	/* Force to create LFN entry */
#define NS_LAST		0x04	/* Last segment */
#define NS_BODY		0x08	/* Lower case flag (body) */
#define NS_EXT		0x10	/* Lower case flag (ext) */
#define NS_DOT		0x20	/* Dot entry */



DWORD pffbcs;
WORD pffclst;


/*--------------------------------------------------------------------------

   Private Functions

---------------------------------------------------------------------------*/


/*-----------------------------------------------------------------------*/
/* String functions                                                      */
/*-----------------------------------------------------------------------*/

/* Fill memory */
static
void mem_set (void* dst, int val, int cnt) {
	char *d = (char*)dst;
	while (cnt--) *d++ = (char)val;
}

/* Compare memory to memory */
static
int mem_cmp (const void* dst, const void* src, int cnt) {
	const char *d = (const char *)dst, *s = (const char *)src;
	int r = 0;
	while (cnt-- && (r = *d++ - *s++) == 0) ;
	return r;
}

/* Check if chr is contained in the string */
static
int chk_chr (const char* str, int chr) {
	while (*str && *str != chr) str++;
	return *str;
}



/*-----------------------------------------------------------------------*/
/* FAT access - Read value of a FAT entry                                */
/*-----------------------------------------------------------------------*/

//static
CLUST get_fat (	/* 1:IO error, Else:Cluster status */
	CLUST clst	/* Cluster# to get the link information */
)
{
	static WORD wc, bc, ofs;
	static BYTE buf[4];
	FATFS *fs = FatFs;


	if (clst < 2 || clst >= fs->max_clust)	/* Range check */
		return 1;

	switch (fs->fs_type) {
	case FS_FAT12 :
		bc = (WORD)clst;
		bc += bc >> 1;
		ofs = bc & 511;
		bc >>= 9;
		if (ofs != 511) {
			if (disk_readp(buf, fs->fatbase + bc, ofs, 2)) break;
		} else {
			if (disk_readp(buf, fs->fatbase + bc, 511, 1)) break;
			if (disk_readp(buf+1, fs->fatbase + bc + 1, 0, 1)) break;
		}
		wc = LD_WORD(buf);
		return (clst & 1) ? (wc >> 4) : (wc & 0xFFF);

	case FS_FAT16 :
		if (disk_readp(buf, fs->fatbase + (clst >> 8), (WORD)(((WORD)clst & 255) << 1), 2)) break;
		return LD_WORD(buf);
#if _FS_FAT32
	case FS_FAT32 :
		if (disk_readp(buf, fs->fatbase + (clst >> 7), (WORD)(((WORD)clst & 127) << 2), 4)) break;
		return LD_DWORD(buf) & 0x0FFFFFFF;
#endif
	}

	return 1;	/* An error occured at the disk I/O layer */
}




/*-----------------------------------------------------------------------*/
/* Get sector# from cluster#                                             */
/*-----------------------------------------------------------------------*/

// Optimized version implemented in pff_asm.asm

//static
//DWORD clust2sect (	/* !=0: Sector number, 0: Failed - invalid cluster# */
//	CLUST clst		/* Cluster# to be converted */
//)
//{
//	FATFS *fs = FatFs;
//
//
//	clst -= 2;
//	if (clst >= (fs->max_clust - 2)) return 0;		/* Invalid cluster# */
//	return (DWORD)clst * fs->csize + fs->database;
//}




#if _USE_LFN

#define ff_convert(wc, x) ((char)wc)

static WCHAR ff_wtoupper(WCHAR wc) {
	char c = (char)wc;
	if (c >= 'a' && c <= 'z') wc -= ' ';
	return wc;
}


static
const BYTE LfnOfs[] = {1,3,5,7,9,14,16,18,20,22,24,28,30};	/* Offset of LFN chars in the directory entry */


static
BOOL cmp_lfn (			/* TRUE:Matched, FALSE:Not matched */
	WCHAR *lfnbuf,		/* Pointer to the LFN to be compared */
	BYTE *dir			/* Pointer to the directory entry containing a part of LFN */
)
{
	int i, s;
	WCHAR wc, uc;


	i = ((dir[LDIR_Ord] & 0xBF) - 1) * 13;	/* Get offset in the LFN buffer */
	s = 0; wc = 1;
	do {
		uc = LD_WORD(dir+LfnOfs[s]);	/* Pick an LFN character from the entry */
		if (wc) {	/* Last char has not been processed */
			wc = ff_wtoupper(uc);		/* Convert it to upper case */
			if (i >= _MAX_LFN || wc != ff_wtoupper(lfnbuf[i++]))	/* Compare it */
				return FALSE;			/* Not matched */
		} else {
			if (uc != 0xFFFF) return FALSE;	/* Check filler */
		}
	} while (++s < 13);				/* Repeat until all chars in the entry are checked */

	if ((dir[LDIR_Ord] & 0x40) && wc && lfnbuf[i])	/* Last segment matched but different length */
		return FALSE;

	return TRUE;					/* The part of LFN matched */
}



static
BOOL pick_lfn (			/* TRUE:Succeeded, FALSE:Buffer overflow */
	WCHAR *lfnbuf,		/* Pointer to the Unicode-LFN buffer */
	BYTE *dir			/* Pointer to the directory entry */
)
{
	int i, s;
	WCHAR wc, uc;


	i = ((dir[LDIR_Ord] & 0x3F) - 1) * 13;	/* Offset in the LFN buffer */

	s = 0; wc = 1;
	do {
		uc = LD_WORD(dir+LfnOfs[s]);			/* Pick an LFN character from the entry */
		if (wc) {	/* Last char has not been processed */
			if (i >= _MAX_LFN) return FALSE;	/* Buffer overflow? */
			lfnbuf[i++] = wc = uc;				/* Store it */
		} else {
			if (uc != 0xFFFF) return FALSE;		/* Check filler */
		}
	} while (++s < 13);						/* Read all character in the entry */

	if (dir[LDIR_Ord] & 0x40) {				/* Put terminator if it is the last LFN part */
		if (i >= _MAX_LFN) return FALSE;	/* Buffer overflow? */
		lfnbuf[i] = 0;
	}

	return TRUE;
}

static
BYTE sum_sfn (
	const BYTE *dir		/* Ptr to directory entry */
)
{
	BYTE sum = 0;
	int n = 11;

	do sum = (sum >> 1) + (sum << 7) + *dir++; while (--n);
	return sum;
}
#endif



/*-----------------------------------------------------------------------*/
/* Directory handling - Rewind directory index                           */
/*-----------------------------------------------------------------------*/

static
FRESULT dir_rewind (
	DIR *dj			/* Pointer to directory object */
)
{
	CLUST clst;
	FATFS *fs = FatFs;


	dj->index = 0;
	clst = dj->sclust;
	if (clst == 1 || clst >= fs->max_clust)	/* Check start cluster range */
		return FR_DISK_ERR;
#if _FS_FAT32
	if (!clst && fs->fs_type == FS_FAT32)	/* Replace cluster# 0 with root cluster# if in FAT32 */
		clst = fs->dirbase;
#endif
	dj->clust = clst;						/* Current cluster */
	dj->sect = clst ? clust2sect(clst) : fs->dirbase;	/* Current sector */

	return FR_OK;	/* Seek succeeded */
}




/*-----------------------------------------------------------------------*/
/* Directory handling - Move directory index next                        */
/*-----------------------------------------------------------------------*/

static
FRESULT dir_next (	/* FR_OK:Succeeded, FR_NO_FILE:End of table, FR_DENIED:EOT and could not streach */
	DIR *dj			/* Pointer to directory object */
)
{
	CLUST clst;
	WORD i;
	FATFS *fs = FatFs;


	i = dj->index + 1;
	if (!i || !dj->sect)	/* Report EOT when index has reached 65535 */
		return FR_NO_FILE;

	if (!(i & (16-1))) {	/* Sector changed? */
		dj->sect++;			/* Next sector */

		if (dj->clust == 0) {	/* Static table */
			if (i >= fs->n_rootdir)	/* Report EOT when end of table */
				return FR_NO_FILE;
		}
		else {					/* Dynamic table */
			if (((i >> 4) & (fs->csize-1)) == 0) {	/* Cluster changed? */
				clst = get_fat(dj->clust);		/* Get next cluster */
				if (clst <= 1) return FR_DISK_ERR;
				if (clst >= fs->max_clust)		/* When it reached end of dynamic table */
					return FR_NO_FILE;			/* Report EOT */
				dj->clust = clst;				/* Initialize data for new cluster */
				dj->sect = clust2sect(clst);
			}
		}
	}

	dj->index = i;

	return FR_OK;
}




/*-----------------------------------------------------------------------*/
/* Directory handling - Find an object in the directory                  */
/*-----------------------------------------------------------------------*/

static
FRESULT dir_find (
	DIR *dj			/* Pointer to the directory object linked to the file name */
)
{
	FRESULT res;
	BYTE c, *dir;
#if _USE_LFN
	BYTE a, ord, sum;
#endif

	res = dir_rewind(dj);			/* Rewind directory object */
	if (res != FR_OK) return res;

pffclst = 4;

	dir = FatFs->buf;
#if _USE_LFN
	ord = sum = 0xFF;
#endif
	do {
		res = disk_readp(dir, dj->sect, (WORD)((dj->index & 15) << 5), 32)	/* Read an entry */
			? FR_DISK_ERR : FR_OK;
		if (res != FR_OK) break;
	pffclst = 5;
		c = dir[DIR_Name];	/* First character */
		if (c == 0) { res = FR_NO_FILE; break; }	/* Reached to end of table */

#if _USE_LFN	/* LFN configuration */
		a = dir[DIR_Attr] & AM_MASK;
		if (c == 0xE5 || ((a & AM_VOL) && a != AM_LFN)) {	/* An entry without valid data */
			ord = 0xFF;
		} else {
			if (a == AM_LFN) {			/* An LFN entry is found */
				if (dj->lfn) {
					if (c & 0x40) {		/* Is it start of LFN sequence? */
						sum = dir[LDIR_Chksum];
						c &= 0xBF; ord = c;	/* LFN start order */
						dj->lfn_idx = dj->index;
					}
					/* Check validity of the LFN entry and compare it with given name */
					ord = (c == ord && sum == dir[LDIR_Chksum] && cmp_lfn(dj->lfn, dir)) ? ord - 1 : 0xFF;
				}
			} else {					/* An SFN entry is found */
				if (!ord && sum == sum_sfn(dir)) break;	/* LFN matched? */
				ord = 0xFF; dj->lfn_idx = 0xFFFF;	/* Reset LFN sequence */
				if (!(dj->fn[NS] & NS_LOSS) && !mem_cmp(dir, dj->fn, 11)) break;	/* SFN matched? */
			}
		}
#else
		if (!(dir[DIR_Attr] & AM_VOL) && !mem_cmp(dir, dj->fn, 11)) /* Is it a valid entry? */
			break;
#endif
		res = dir_next(dj);							/* Next entry */
	} while (res == FR_OK);

	return res;
}




/*-----------------------------------------------------------------------*/
/* Read an object from the directory                                     */
/*-----------------------------------------------------------------------*/
#if _USE_DIR
static
FRESULT dir_read (
	DIR *dj			/* Pointer to the directory object to store read object name */
)
{
	FRESULT res;
	BYTE a, c, *dir;
#if _USE_LFN
	BYTE ord = 0xFF, sum = 0xFF;
#endif

	res = FR_NO_FILE;
	while (dj->sect) {
		dir = FatFs->buf;
		res = disk_readp(dir, dj->sect, (WORD)((dj->index & 15) << 5), 32)	/* Read an entry */
			? FR_DISK_ERR : FR_OK;
		if (res != FR_OK) break;
		c = dir[DIR_Name];
		if (c == 0) { res = FR_NO_FILE; break; }	/* Reached to end of table */
		a = dir[DIR_Attr] & AM_MASK;
		//if (c != 0xE5 && c != '.' && !(a & AM_VOL))	/* Is it a valid entry? */
		//	break;

#if _USE_LFN	/* LFN configuration */
		a = dir[DIR_Attr] & AM_MASK;
		if (c == 0xE5 || (!_FS_RPATH && c == '.') || ((a & AM_VOL) && a != AM_LFN)) {	/* An entry without valid data */
			ord = 0xFF;
		} else {
			if (a == AM_LFN) {			/* An LFN entry is found */
				if (c & 0x40) {			/* Is it start of LFN sequence? */
					sum = dir[LDIR_Chksum];
					c &= 0xBF; ord = c;
					dj->lfn_idx = dj->index;
				}
				/* Check LFN validity and capture it */
				ord = (c == ord && sum == dir[LDIR_Chksum] && pick_lfn(dj->lfn, dir)) ? ord - 1 : 0xFF;
			} else {					/* An SFN entry is found */
				if (ord || sum != sum_sfn(dir))	/* Is there a valid LFN? */
					dj->lfn_idx = 0xFFFF;		/* It has no LFN. */
				break;
			}
		}
#else		/* Non LFN configuration */
		if (c != 0xE5 &&  (_FS_RPATH || c != '.') && !(a & AM_VOL))	/* Is it a valid entry? */
			break;
#endif

		res = dir_next(dj);				/* Next entry */
		if (res != FR_OK) break;
	}

	if (res != FR_OK) dj->sect = 0;

	return res;
}
#endif



/*-----------------------------------------------------------------------*/
/* Pick a segment and create the object name in directory form           */
/*-----------------------------------------------------------------------*/


static
FRESULT create_name (
	DIR *dj,			/* Pointer to the directory object */
	const XCHAR **path	/* Pointer to pointer to the segment in the path string */
)
{

#if _USE_LFN	/* LFN configuration */
	BYTE b, cf;
	WCHAR w, *lfn;
	int i, ni, si, di;
	const XCHAR *p;

	/* Create LFN in Unicode */
	si = di = 0;
	p = *path;
	lfn = dj->lfn;
	for (;;) {
		w = p[si++];					/* Get a character */
		if (w < ' ' || w == '/' || w == '\\') break;	/* Break on end of segment */
		if (di >= _MAX_LFN)				/* Reject too long name */
			return FR_INVALID_NAME;
//#if !_LFN_UNICODE
		w &= 0xFF;
		if (IsDBCS1(w)) {				/* If it is a DBC 1st byte */
			b = p[si++];				/* Get 2nd byte */
			if (!IsDBCS2(b))			/* Reject invalid code for DBC */
				return FR_INVALID_NAME;
			w = (w << 8) + b;
		}
		w = ff_convert(w, 1);			/* Convert OEM to Unicode */
		if (!w) return FR_INVALID_NAME;	/* Reject invalid code */
//#endif
		if (w < 0x80 && chk_chr("\"*:<>\?|\x7F", w)) /* Reject illegal chars for LFN */
			return FR_INVALID_NAME;
		lfn[di++] = w;					/* Store the Unicode char */
	}
	*path = &p[si];						/* Rerurn pointer to the next segment */
	cf = (w < ' ') ? NS_LAST : 0;		/* Set last segment flag if end of path */
#if _FS_RPATH
	if ((di == 1 && lfn[di - 1] == '.') || /* Is this a dot entry? */
		(di == 2 && lfn[di - 1] == '.' && lfn[di - 2] == '.')) {
		lfn[di] = 0;
		for (i = 0; i < 11; i++)
			dj->fn[i] = (i < di) ? '.' : ' ';
		dj->fn[i] = cf | NS_DOT;		/* This is a dot entry */
		return FR_OK;
	}
#endif
	while (di) {						/* Strip trailing spaces and dots */
		w = lfn[di - 1];
		if (w != ' ' && w != '.') break;
		di--;
	}
	if (!di) return FR_INVALID_NAME;	/* Reject null string */

	lfn[di] = 0;						/* LFN is created */

	/* Create SFN in directory form */
	mem_set(dj->fn, ' ', 11);
	for (si = 0; lfn[si] == ' ' || lfn[si] == '.'; si++) ;	/* Strip leading spaces and dots */
	if (si) cf |= NS_LOSS | NS_LFN;
	while (di && lfn[di - 1] != '.') di--;	/* Find extension (di<=si: no extension) */

	b = i = 0; ni = 8;
	for (;;) {
		w = lfn[si++];					/* Get an LFN char */
		if (!w) break;					/* Break on enf of the LFN */
		if (w == ' ' || (w == '.' && si != di)) {	/* Remove spaces and dots */
			cf |= NS_LOSS | NS_LFN; continue;
		}

		if (i >= ni || si == di) {		/* Extension or end of SFN */
			if (ni == 11) {				/* Long extension */
				cf |= NS_LOSS | NS_LFN; break;
			}
			if (si != di) cf |= NS_LOSS | NS_LFN;	/* Out of 8.3 format */
			if (si > di) break;			/* No extension */
			si = di; i = 8; ni = 11;	/* Enter extension section */
			b <<= 2; continue;
		}

		if (w >= 0x80) {				/* Non ASCII char */
#ifdef _EXCVT
			w = ff_convert(w, 0);		/* Unicode -> OEM code */
			if (w) w = cvt[w - 0x80];	/* Convert extended char to upper (SBCS) */
#else
			w = ff_convert(ff_wtoupper(w), 0);	/* Upper converted Unicode -> OEM code */
#endif
			cf |= NS_LFN;				/* Force create LFN entry */
		}

		if (_DF1S && w >= 0x100) {		/* Double byte char */
			if (i >= ni - 1) {
				cf |= NS_LOSS | NS_LFN; i = ni; continue;
			}
			dj->fn[i++] = (BYTE)(w >> 8);
		} else {						/* Single byte char */
			if (!w || chk_chr("+,;[=]", w)) {		/* Replace illegal chars for SFN */
				w = '_'; cf |= NS_LOSS | NS_LFN;	/* Lossy conversion */
			} else {
				if (IsUpper(w)) {		/* ASCII large capital */
					b |= 2;
				} else {
					if (IsLower(w)) {	/* ASCII small capital */
						b |= 1; w -= 0x20;
					}
				}
			}
		}
		dj->fn[i++] = (BYTE)w;
	}

	if (dj->fn[0] == 0xE5) dj->fn[0] = 0x05;	/* If the first char collides with deleted mark, replace it with 0x05 */

	if (ni == 8) b <<= 2;
	if ((b & 0x0C) == 0x0C || (b & 0x03) == 0x03)	/* Create LFN entry when there are composite capitals */
		cf |= NS_LFN;
	if (!(cf & NS_LFN)) {						/* When LFN is in 8.3 format without extended char, NT flags are created */
		if ((b & 0x03) == 0x01) cf |= NS_EXT;	/* NT flag (Extension has only small capital) */
		if ((b & 0x0C) == 0x04) cf |= NS_BODY;	/* NT flag (Filename has only small capital) */
	}

	dj->fn[NS] = cf;	/* SFN is created */

	return FR_OK;


#else	/* Non-LFN configuration */
	BYTE c, ni, si, i, *sfn;
	const char *p;

	/* Create file name in directory form */
	sfn = dj->fn;
	mem_set(sfn, ' ', 11);
	si = i = 0; ni = 8;
	p = *path;
	for (;;) {
		c = p[si++];
		if (c < ' ' || c == '/') break;	/* Break on end of segment */
		if (c == '.' || i >= ni) {
			if (ni != 8 || c != '.') return FR_INVALID_NAME;
			i = 8; ni = 11;
			continue;
		}
		if (c >= 0x7F || chk_chr(" +,;[=\\]\"*:<>\?|", c))	/* Reject unallowable chrs for SFN */
			return FR_INVALID_NAME;
		if (c >='a' && c <= 'z') c -= 0x20;
		sfn[i++] = c;
	}
	if (!i) return FR_INVALID_NAME;		/* Reject null string */
	*path = &p[si];						/* Rerurn pointer to the next segment */

	sfn[11] = (c < ' ') ? 1 : 0;		/* Set last segment flag if end of path */

	return FR_OK;
#endif
}




/*-----------------------------------------------------------------------*/
/* Get file information from directory entry                             */
/*-----------------------------------------------------------------------*/
#if _USE_DIR


static
void get_fileinfo (		/* No return code */
	DIR *dj,			/* Pointer to the directory object */
	FILINFO *fno	 	/* Pointer to store the file information */
)
{
	BYTE i, c, nt, *dir;
	char *p;


	p = fno->fname;
	if (dj->sect) {
		dir = FatFs->buf;
		for (i = 0; i < 8; i++) {	/* Copy file name body */
			c = dir[i];
			if (c == ' ') break;
			if (c == 0x05) c = 0xE5;
			*p++ = c;
		}
		if (dir[8] != ' ') {		/* Copy file name extension */
			*p++ = '.';
			for (i = 8; i < 11; i++) {
				c = dir[i];
				if (c == ' ') break;
				*p++ = c;
			}
		}
		fno->fattrib = dir[DIR_Attr];				/* Attribute */
		fno->fsize = LD_DWORD(dir+DIR_FileSize);	/* Size */
		fno->fdate = LD_WORD(dir+DIR_WrtDate);		/* Date */
		fno->ftime = LD_WORD(dir+DIR_WrtTime);		/* Time */
	}
	*p = 0;

#if _USE_LFN
	if (fno->lfname) {
		XCHAR *tp = fno->lfname;
		WCHAR w, *lfn;

		i = 0;
		if (dj->sect && dj->lfn_idx != 0xFFFF) {/* Get LFN if available */
			lfn = dj->lfn;
			while ((w = *lfn++) != 0) {			/* Get an LFN char */
//#if !_LFN_UNICODE
				w = ff_convert(w, 0);			/* Unicode -> OEM conversion */
				if (!w) { i = 0; break; }		/* Could not convert, no LFN */
				if (_DF1S && w >= 0x100)		/* Put 1st byte if it is a DBC */
					tp[i++] = (XCHAR)(w >> 8);
//#endif
				if (i >= fno->lfsize - 1) { i = 0; break; }	/* Buffer overrun, no LFN */
				tp[i++] = (XCHAR)w;
			}
		}
		tp[i] = 0;	/* Terminator */
	}
#endif

}
#endif /* _USE_DIR */



/*-----------------------------------------------------------------------*/
/* Follow a file path                                                    */
/*-----------------------------------------------------------------------*/

static
FRESULT follow_path (	/* FR_OK(0): successful, !=0: error code */
	DIR *dj,			/* Directory object to return last directory and found object */
	const char *path	/* Full-path string to find a file or directory */
)
{
	FRESULT res;
	BYTE *dir;


	if (*path == '/') path++;			/* Strip heading separator */
	dj->sclust = 0;						/* Set start directory (always root dir) */

	if ((BYTE)*path < ' ') {			/* Null path means the root directory */
		res = dir_rewind(dj);
		FatFs->buf[0] = 0;

	} else {							/* Follow path */
		for (;;) {
			res = create_name(dj, &path);	/* Get a segment */
			if (res != FR_OK) break;
		pffclst = 2;
			res = dir_find(dj);				/* Find it */
			if (res != FR_OK) {				/* Could not find the object */
				if (res == FR_NO_FILE && !*(dj->fn+11))
					{ res = FR_NO_PATH; pffclst = 8; }
				break;
			}
		pffclst = 3;
			if (*(dj->fn+11)) break;		/* Last segment match. Function completed. */
			dir = FatFs->buf;				/* There is next segment. Follow the sub directory */
			if (!(dir[DIR_Attr] & AM_DIR)) { /* Cannot follow because it is a file */
				res = FR_NO_PATH; pffclst = 9; break;
			}
			dj->sclust =
#if _FS_FAT32
				((DWORD)LD_WORD(dir+DIR_FstClusHI) << 16) |
#endif
				LD_WORD(dir+DIR_FstClusLO);
		}
	}

	return res;
}




/*-----------------------------------------------------------------------*/
/* Check a sector if it is an FAT boot record                            */
/*-----------------------------------------------------------------------*/

static
BYTE check_fs (	/* 0:The FAT boot record, 1:Valid boot record but not an FAT, 2:Not a boot record, 3:Error */
	BYTE *buf,	/* Working buffer */
	DWORD sect	/* Sector# (lba) to check if it is an FAT boot record or not */
)
{
	if (disk_readp(buf, sect, 510, 2))		/* Read the boot sector */
		return 3;
	if (LD_WORD(buf) != 0xAA55)				/* Check record signature */
		return 2;

	if (!disk_readp(buf, sect, BS_FilSysType, 2) && LD_WORD(buf) == 0x4146)	/* Check FAT12/16 */
		return 0;
#if _FS_FAT32
	if (!disk_readp(buf, sect, BS_FilSysType32, 2) && LD_WORD(buf) == 0x4146)	/* Check FAT32 */
		return 0;
#endif
	return 1;
}




/*--------------------------------------------------------------------------

   Public Functions

--------------------------------------------------------------------------*/



/*-----------------------------------------------------------------------*/
/* Mount/Unmount a Locical Drive                                         */
/*-----------------------------------------------------------------------*/

unsigned char pfmountbuf[36];
extern unsigned char pfMountFmt;

FRESULT pf_mount (
	FATFS *fs		/* Pointer to new file system object (NULL: Unmount) */
)
{
	BYTE fmt;
	static BYTE buf[36];
	static DWORD bsect, fsize, tsect, mclst;

// DEBUG
pfMountFmt = 0xAB;

	FatFs = 0;
	if (!fs) return FR_OK;				/* Unregister fs object */

	if (disk_initialize() != 0) //& STA_NOINIT)	/* Check if the drive is ready or not */
		return FR_NOT_READY;

	/* Search FAT partition on the drive */
	bsect = 0;
	fmt = check_fs(buf, bsect);			/* Check sector 0 as an SFD format */

//DEBUG
memcpy(pfmountbuf, buf, 36);

	if (fmt == 1) {						/* Not an FAT boot record, it may be FDISK format */
		/* Check a partition listed in top of the partition table */
		if (disk_readp(buf, bsect, MBR_Table, 16)) {	/* 1st partition entry */
			fmt = 3;
		} else {
			if (buf[4]) {					/* Is the partition existing? */
				bsect = LD_DWORD(&buf[8]);	/* Partition offset in LBA */
				fmt = check_fs(buf, bsect);	/* Check the partition */
			}
		}
	}

	pfMountFmt = fmt;

	if (fmt == 3) return FR_DISK_ERR;
	if (fmt) return FR_NO_FILESYSTEM;	/* No valid FAT patition is found */

	/* Initialize the file system object */
	if (disk_readp(buf, bsect, 13, sizeof(buf))) return FR_DISK_ERR;

	fsize = LD_WORD(buf+BPB_FATSz16-13);				/* Number of sectors per FAT */
	if (!fsize) fsize = LD_DWORD(buf+BPB_FATSz32-13);

	fsize *= buf[BPB_NumFATs-13];						/* Number of sectors in FAT area */
	fs->fatbase = bsect + LD_WORD(buf+BPB_RsvdSecCnt-13); /* FAT start sector (lba) */
	fs->csize = buf[BPB_SecPerClus-13];					/* Number of sectors per cluster */
	fs->n_rootdir = LD_WORD(buf+BPB_RootEntCnt-13);		/* Nmuber of root directory entries */
	tsect = LD_WORD(buf+BPB_TotSec16-13);				/* Number of sectors on the file system */
	if (!tsect) tsect = LD_DWORD(buf+BPB_TotSec32-13);
	mclst = (tsect						/* Last cluster# + 1 */
		- LD_WORD(buf+BPB_RsvdSecCnt-13) - fsize - (fs->n_rootdir >> 4)
		) / fs->csize + 2;
	fs->max_clust = (CLUST)mclst;

	fmt = FS_FAT12;							/* Determine the FAT sub type */
	if (mclst >= 0xFF7) fmt = FS_FAT16;		/* Number of clusters >= 0xFF5 */

// DEBUG
pfMountFmt = fmt;

	if (mclst >= 0xFFF7)					/* Number of clusters >= 0xFFF5 */
	{
#if _FS_FAT32
		fmt = FS_FAT32;
#else
pfMountFmt = 0xAC;
		return FR_NO_FILESYSTEM;
#endif
    }

	fs->fs_type = fmt;		/* FAT sub-type */
#if _FS_FAT32
	if (fmt == FS_FAT32)
		fs->dirbase = LD_DWORD(buf+(BPB_RootClus-13));	/* Root directory start cluster */
	else
#endif
		fs->dirbase = fs->fatbase + fsize;				/* Root directory start sector (lba) */
	fs->database = fs->fatbase + fsize + (fs->n_rootdir >> 4); /// 16;	/* Data start sector (lba) */

	fs->flag = 0;
	FatFs = fs;

	return FR_OK;
}




/*-----------------------------------------------------------------------*/
/* Open or Create a File                                                 */
/*-----------------------------------------------------------------------*/

FRESULT pf_open (
	const char *path	/* Pointer to the file name */
)
{
	FRESULT res;
	DIR dj;
	static BYTE dir[32];
	NAMEBUF(sfn, lfn);
	FATFS *fs = FatFs;


	if (!fs)						/* Check file system */
		return FR_NOT_ENABLED;

	INITBUF(dj, sfn, lfn);
	fs->flag = 0;
	fs->buf = dir;
	dj.fn = sfn; //sp;
	res = follow_path(&dj, path);	/* Follow the file path */
	if (res != FR_OK) return res;	/* Follow failed */
	if (!dir[0] || (dir[DIR_Attr] & AM_DIR))	/* It is a directory */
		return FR_NO_FILE;

	fs->org_clust =						/* File start cluster */
#if _FS_FAT32
		((DWORD)LD_WORD(dir+DIR_FstClusHI) << 16) |
#endif
		LD_WORD(dir+DIR_FstClusLO);
	fs->fsize = LD_DWORD(dir+DIR_FileSize);	/* File size */
	fs->fptr = 0;						/* File pointer */
	fs->flag = FA_READ;

	return FR_OK;
}




/*-----------------------------------------------------------------------*/
/* Read File                                                             */
/*-----------------------------------------------------------------------*/

FRESULT pf_read (
	void* dest,		/* Pointer to the destination object */
	WORD btr,		/* Number of bytes to read (bit15:destination) */
	WORD* br		/* Pointer to number of bytes read */
)
{
	static DRESULT dr;
	static CLUST clst;
	static DWORD sect, remain;
	WORD rcnt;
	BYTE *rbuff = dest;
	FATFS *fs = FatFs;


	*br = 0;
	if (!fs) return FR_NOT_ENABLED;		/* Check file system */
	if (!(fs->flag & FA_READ))
			return FR_INVALID_OBJECT;

	remain = fs->fsize - fs->fptr;
	if (btr > remain) btr = (UINT)remain;			/* Truncate btr by remaining bytes */

	for ( ;  btr;									/* Repeat until all data transferred */
		rbuff += rcnt, fs->fptr += rcnt, *br += rcnt, btr -= rcnt) {
		if ((fs->fptr & 511) == 0) {				/* On the sector boundary? */
			if (((fs->fptr >> 9) & (fs->csize - 1)) == 0) {	/* On the cluster boundary? */
				clst = (fs->fptr == 0) ?			/* On the top of the file? */
					fs->org_clust : get_fat(fs->curr_clust);
				if (clst <= 1) {
					fs->flag = 0; return FR_DISK_ERR;
				}
				fs->curr_clust = clst;				/* Update current cluster */
				fs->csect = 0;						/* Reset sector offset in the cluster */
			}
			sect = clust2sect(fs->curr_clust);		/* Get current sector */
			if (!sect) {
				fs->flag = 0; return FR_DISK_ERR;
			}
			sect += fs->csect;
			fs->dsect = sect;
			fs->csect++;							/* Next sector address in the cluster */
		}
		rcnt = 512 - ((WORD)fs->fptr & 511);		/* Get partial sector data from sector buffer */
		if (rcnt > btr) rcnt = btr;
		if (fs->flag & FA_STREAM) {
			dr = disk_readp(dest, fs->dsect, (WORD)(fs->fptr & 511), (WORD)(rcnt | 0x8000));
		} else {
			dr = disk_readp(rbuff, fs->dsect, (WORD)(fs->fptr & 511), rcnt);
		}
		if (dr) {
			fs->flag = 0;
			return (dr == RES_WRPRT/*STRERR*/) ? FR_STREAM_ERR : FR_DISK_ERR;
		}
	}

	return FR_OK;
}



FRESULT pf_read_sect_to_psram (
	WORD prbank,
	WORD proffs,
	WORD recalcsector
)
{
	static DRESULT dr;
	static CLUST clst;
	static DWORD sect, remain;
	FATFS *fs = FatFs;

	//*br = 0;
	if (!fs) return FR_NOT_ENABLED;		/* Check file system */
	if (!(fs->flag & FA_READ))
			return FR_INVALID_OBJECT;

	remain = fs->fsize - fs->fptr;
	//if (512 > remain) return FR_INVALID_OBJECT;			/* Truncate btr by remaining bytes */

	if (recalcsector)
	{
		if ((fs->fptr & 511) == 0) {				/* On the sector boundary? */
			if (((fs->fptr >> 9) & (fs->csize - 1)) == 0) {	/* On the cluster boundary? */
				clst = (fs->fptr == 0) ?			/* On the top of the file? */
					fs->org_clust : get_fat(fs->curr_clust);
				if (clst <= 1) {
					fs->flag = 0; return FR_DISK_ERR;
				}
				fs->curr_clust = clst;				/* Update current cluster */
				fs->csect = 0;						/* Reset sector offset in the cluster */
			}
			sect = clust2sect(fs->curr_clust);		/* Get current sector */
			if (!sect) {
				fs->flag = 0; return FR_DISK_ERR;
			}
			sect += fs->csect;
			fs->dsect = sect;
			fs->csect++;							/* Next sector address in the cluster */
		}
	}

	dr = disk_readsect_psram(prbank, proffs, fs->dsect);

	if (dr) {
		fs->flag = 0;
		return (dr == RES_WRPRT/*STRERR*/) ? FR_STREAM_ERR : FR_DISK_ERR;
	}

	fs->fptr += 512;
	//*br = 512;

	return FR_OK;
}



FRESULT pf_read_1mbit_to_psram (
	WORD prbank,
	WORD proffs,
	WORD recalcsector
)
{
	static DRESULT dr;
	static CLUST clst;
	static DWORD basesect, sect, remain;
	static WORD numSects, remSectInClust, bytesRead;
	FATFS *fs = FatFs;

	if (!fs) return FR_NOT_ENABLED;		/* Check file system */
	if (!(fs->flag & FA_READ))
			return FR_INVALID_OBJECT;

	remain = FatFs->fsize - FatFs->fptr;
	if (0x20000 > remain) return FR_INVALID_OBJECT;			/* Truncate btr by remaining bytes */

	basesect = clust2sect(fs->curr_clust);
	numSects = 256;
	while (numSects)
	{
		if (recalcsector)
		{
			if (((FatFs->fptr >> 9) & (FatFs->csize - 1)) == 0) {	/* On the cluster boundary? */
				clst = (FatFs->fptr == 0) ? FatFs->org_clust : get_fat(FatFs->curr_clust);
				if (clst <= 1)
				{
					FatFs->flag = 0;
					return FR_DISK_ERR;
				}
				FatFs->curr_clust = clst;				/* Update current cluster */
				FatFs->csect = 0;						/* Reset sector offset in the cluster */
				basesect = clust2sect(fs->curr_clust);
			}
			//sect = clust2sect(fs->curr_clust);		/* Get current sector */
			if (!basesect)
			{
				FatFs->flag = 0;
				return FR_DISK_ERR;
			}
			//sect += fs->csect;
			FatFs->dsect = basesect + FatFs->csect; //sect;
			FatFs->csect++;							/* Next sector address in the cluster */
		}
		recalcsector = 1;

		remSectInClust = FatFs->csize - FatFs->csect;
		if ((remSectInClust > 2) && (prbank != 0x5F))
		{
			if (remSectInClust > numSects)
			{
				remSectInClust = numSects;
			}
			// DEBUG
			/*pfmountbuf[0] = remSectInClust;
			pfmountbuf[1] = numSects;
			pfmountbuf[2] = FatFs->csize;*/

			dr = disk_read_psram_multi(prbank, proffs, FatFs->dsect, remSectInClust);
			if (dr)
			{
				fs->flag = 0;
				return (dr == RES_WRPRT/*STRERR*/) ? FR_STREAM_ERR : FR_DISK_ERR;
			}

			numSects -= remSectInClust;
			FatFs->csect += remSectInClust-1;
			while (remSectInClust)
			{
				proffs += 512;
				if (proffs == 0)
				{
					prbank++;
				}
				FatFs->fptr += 512;
				remSectInClust--;
			}
		}
		else
		{
			dr = disk_readsect_psram(prbank, proffs, FatFs->dsect);

			if (dr)
			{
				fs->flag = 0;
				return (dr == RES_WRPRT/*STRERR*/) ? FR_STREAM_ERR : FR_DISK_ERR;
			}

			proffs += 512;
			if (proffs == 0)
			{
				prbank++;
			}
			FatFs->fptr += 512;
			numSects--;
		}
	}


	return FR_OK;
}


/******************************************/


FRESULT pf_write (
	const void* buff,	/* Pointer to the data to be written */
	WORD btw,			/* Number of bytes to write (0:Finalize the current write operation) */
	WORD* bw			/* Pointer to number of bytes written */
)
{
	static CLUST clst;
	static DWORD sect, remain;
	BYTE *p = buff;
	BYTE cs;
	WORD wcnt;
	FATFS *fs = FatFs;

	*bw = 0;
	if (!fs) { return FR_NOT_ENABLED; }
	if (!(fs->flag & FA_OPENED)) { return FR_NOT_OPENED; }

	if (!(fs->flag & FA__WIP)){ fs->fptr &= 0xFFFFFE00; }
	remain = fs->fsize - fs->fptr;
	if (btw > remain) {btw = (WORD)remain;}			/* Truncate btw by remaining bytes */

	while (btw)	{									/* Repeat until all data transferred */
		if ((fs->fptr & 511) == 0) {			/* On the sector boundary? */
			cs = (BYTE)((fs->fptr >> 9) & (fs->csize - 1));	/* Sector offset in the cluster */
			if (!cs) {								/* On the cluster boundary? */
				clst = (fs->fptr == 0) ?			/* On the top of the file? */
					fs->org_clust : get_fat(fs->curr_clust);
				if (clst <= 1) { goto fw_abort; }
				fs->curr_clust = clst;				/* Update current cluster */
			}
			sect = clust2sect(fs->curr_clust);		/* Get current sector */
			if (!sect) { goto fw_abort; }
			fs->dsect = sect + cs;

			//crc16_bc(p);
			if(disk_writesect(p, fs->dsect)) { goto fw_abort; }	/* Send data to the sector */
			if(fs->flag & FA__WIP){ fs->flag &= ~FA__WIP; }
		}
		wcnt = 512 -  (WORD)(fs->fptr & 511);		/* Number of bytes to write to the sector */
		if (wcnt > btw) wcnt = btw;

		fs->fptr += (DWORD)wcnt; p += wcnt;				/* Update pointers and counters */
		btw -= wcnt; *bw += wcnt;
	}

	return FR_OK;

fw_abort:
	fs->flag = 0;
	return FR_DISK_ERR;
}


#if _USE_LSEEK
/*-----------------------------------------------------------------------*/
/* Seek File R/W Pointer                                                 */
/*-----------------------------------------------------------------------*/

FRESULT pf_lseek (
	DWORD ofs		/* File pointer from top of file */
)
{
	static CLUST clst;
	static DWORD bcs, nsect, ifptr;
	static DWORD bo1,bo2;
	FATFS *fs = FatFs;


	if (!fs) return FR_NOT_ENABLED;		/* Check file system */
	if (!(fs->flag & FA_READ))
			return FR_INVALID_OBJECT;

// DEBUG
//pffclst = 0;

	if (ofs > fs->fsize) ofs = fs->fsize;	/* Clip offset with the file size */
	ifptr = fs->fptr;
	fs->fptr = 0;

	if (ofs) {
		bcs = (DWORD)fs->csize << 9; 	/* Cluster size (byte) */
		bo1 = (ofs - 1) / bcs;
		bo2 = (ifptr - 1) / bcs;
		//if ((ifptr != 0) &&	(bo1 >= bo2))
		if (ifptr)
		{
			if (bo1 >= bo2)
			{
				/* When seek to same or following cluster, */
				fs->fptr = (ifptr - 1) & ~(bcs - 1);	/* start from the current cluster */
				ofs -= fs->fptr;
				clst = fs->curr_clust;
					//pffclst = 1;
			} else {							/* When seek to back cluster, */
				clst = fs->org_clust;			/* start from the first cluster */
				fs->curr_clust = clst;
					//pffclst = 2;
			}
		}
		else
		{
				clst = fs->org_clust;			/* start from the first cluster */
				fs->curr_clust = clst;
					//pffclst = 3;
		}

pffbcs = ifptr;

		while (ofs > bcs) {				/* Cluster following loop */

			clst = get_fat(clst);	/* Follow cluster chain if not in write mode */
			if ((clst <= 1) || (clst >= fs->max_clust)) {
				fs->flag = 0; return FR_DISK_ERR + 1;
			}
			fs->curr_clust = clst;
			fs->fptr += bcs;
			ofs -= bcs;
		}
		fs->fptr += ofs;
		fs->csect = (BYTE)(ofs >> 9) + 1;	/* Sector offset in the cluster */
		nsect = clust2sect(clst);	/* Current sector */
		if (!nsect) {
			fs->flag = 0; return FR_DISK_ERR;
		}
		fs->dsect = nsect + fs->csect - 1;
	}

	return FR_OK;
}
#endif


#if _USE_DIR
/*-----------------------------------------------------------------------*/
/* Create a Directroy Object                                             */
/*-----------------------------------------------------------------------*/

FRESULT pf_opendir (
	DIR *dj,			/* Pointer to directory object to create */
	const char *path	/* Pointer to the directory path */
)
{
	FRESULT res;
	static BYTE dir[32];
	NAMEBUF(sfn, lfn);
	FATFS *fs = FatFs;


	pffclst = 0;

	if (!fs) {				/* Check file system */
		res = FR_NOT_ENABLED;
	} else {
		INITBUF((*dj), sfn, lfn);
		fs->buf = dir;
		dj->fn = sfn; //sp;
		res = follow_path(dj, path);			/* Follow the path to the directory */
		if (res == FR_OK) {						/* Follow completed */
	pffclst = 1;
			if (dir[0]) {						/* It is not the root dir */
				if (dir[DIR_Attr] & AM_DIR) {	/* The object is a directory */
					dj->sclust =
#if _FS_FAT32
					((DWORD)LD_WORD(dir+DIR_FstClusHI) << 16) |
#endif
					LD_WORD(dir+DIR_FstClusLO);
				} else {						/* The object is not a directory */
					res = FR_NO_PATH;
					pffclst = 6;
				}
			}
			if (res == FR_OK) {
				res = dir_rewind(dj);			/* Rewind dir */
			}
		}
		if (res == FR_NO_FILE) { res = FR_NO_PATH; pffclst = 7; }
	}

	return res;
}




/*-----------------------------------------------------------------------*/
/* Read Directory Entry in Sequense                                      */
/*-----------------------------------------------------------------------*/

FRESULT pf_readdir (
	DIR *dj,			/* Pointer to the open directory object */
	FILINFO *fno		/* Pointer to file information to return */
)
{
	FRESULT res;
	static BYTE dir[32];
	NAMEBUF(sfn,lfn);
	FATFS *fs = FatFs;


	if (!fs) {				/* Check file system */
		res = FR_NOT_ENABLED;
	} else {
		INITBUF((*dj), sfn, lfn);
		fs->buf = dir;
		dj->fn = sfn; //sp;
		if (!fno) {
			res = dir_rewind(dj);
		} else {
			res = dir_read(dj);
			if (res == FR_NO_FILE) {
				dj->sect = 0;
				res = FR_OK;
			}
			if (res == FR_OK) {				/* A valid entry is found */
				get_fileinfo(dj, fno);		/* Get the object information */
				res = dir_next(dj);			/* Increment index for next */
				if (res == FR_NO_FILE) {
					dj->sect = 0;
					res = FR_OK;
				}
			}
		}
	}

	return res;
}

#endif /* _FS_DIR */

