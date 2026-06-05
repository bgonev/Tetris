#include <cpctelera.h>
#include "splash.h"
#ifdef OVERLAY_SPLASH
#include "overlay/overlay_text.generated.h"
#else
#define TXT_MENU_TITLE "Z32X TETRIS V.0.5"
#define TXT_GAME_OVER "GAME OVER"
#define TXT_BLANK8 "        "
#define TXT_BLANK16 "                "
#define TXT_SCORE "SCORE"
#define TXT_LEVEL "LEVEL"
#define TXT_LINES "LINES"
#define TXT_TETRIS "TETRIS"
#define TXT_NEXT "NEXT"
#define TXT_DEDICATION "for my daughter Marija"
#define TXT_SET_PAD "SET             "
#define TXT_REDEFINE_KEYS "REDEFINE KEYS"
#define TXT_REDEFINE_KEYS_HINT "USE O P Q A Z X M N"
#define TXT_SPACE_OR_CURSORS "SPACE OR CURSORS"
#define TXT_SELECT "SELECT"
#define TXT_MENU_KEYBOARD "1 KEYBOARD"
#define TXT_MENU_JOYSTICK "2 JOYSTICK"
#define TXT_MENU_REDEFINE "3 REDEFINE"
#define TXT_KEYS "KEYS"
#define TXT_LEFT "LEFT"
#define TXT_RIGHT "RIGHT"
#define TXT_ROTATE "ROTATE"
#define TXT_DOWN "DOWN"
#define TXT_DROP "DROP"
#define TXT_PRESS_ANY_KEY "PRESS ANY KEY"
#define TXT_KEY_UNKNOWN "KEY"
#define TXT_KEY_O "O"
#define TXT_KEY_P "P"
#define TXT_KEY_Q "Q"
#define TXT_KEY_A "A"
#define TXT_KEY_Z "Z"
#define TXT_KEY_X "X"
#define TXT_KEY_M "M"
#define TXT_KEY_N "N"
#define TXT_KEY_SPACE "SPACE"
#define TXT_KEY_CUR_L "CUR L"
#define TXT_KEY_CUR_R "CUR R"
#define TXT_KEY_CUR_U "CUR U"
#define TXT_KEY_CUR_D "CUR D"
#endif

#define BOARD_W 10
#define BOARD_H 20
#define CELL_WB 2
#define CELL_H 8
#define CELL_BYTES (CELL_WB * CELL_H)
#define BOARD_X 30
#define BOARD_Y 20
#define LEFT_PANEL_X 2
#define RIGHT_PANEL_X 56
#define NEXT_PREVIEW_Y 76
#define DEDICATION_X 18
#define DEDICATION_Y 188
#define FRAME_WB 2
#define FONT_WB 2
#define FONT_H 8
#define FONT_ADV 2
#define FONT_GLYPH_ROWS 7
#define FONT_GLYPH_COUNT 39
#define FONT_OVERLAY_GLYPHS ((const u8*)0x5004)
#define MENU_TITLE_TEXT TXT_MENU_TITLE
#define MENU_TITLE_LEN 17
#define MENU_TITLE_X 23
#define MENU_TITLE_Y 20
#define MENU_TITLE_ANIM_FRAMES 25
#define GAME_OVER_TEXT TXT_GAME_OVER
#define GAME_OVER_LEN 9
#define GAME_OVER_X 22
#define GAME_OVER_Y 80
#define GAME_OVER_WB 4
#define GAME_OVER_COLOUR_FRAMES 3
#define SCORE_DIGITS 7
#define SH(x, y) (u8)(((y) << 4) | (x))
#define SHAPE_X(cell) ((cell) & 0x0F)
#define SHAPE_Y(cell) ((cell) >> 4)

#define ACT_LEFT   1
#define ACT_RIGHT  2
#define ACT_DOWN   4
#define ACT_ROTATE 8
#define ACT_DROP   16

#define MAX_LEVEL 100
#define LINES_PER_LEVEL 10
#define BOARD_BG 15
#define CELL_INNER_BORDER BOARD_BG
#define CELL_OUTER_BORDER CELL_INNER_BORDER

extern void music_init(void);
extern void music_init_troika(void);
extern void music_play_frame(void);
extern void music_stop(void);
extern void sfx_line_clear(void);
extern void firmware_set_mode0(void);
#ifdef OVERLAY_SPLASH
extern void overlay_load_initial_segments(void);
extern void overlay_load_runtime_font(void);
#ifdef MENU_CODE_OVERLAY
extern void overlay_load_menu_code(void);
extern u8 overlay_run_menu_code(void);
#endif
#endif

typedef struct {
   cpct_keyID id;
   const char* name;
} KeyChoice;

static u8 board[BOARD_H][BOARD_W];
static u8 cellPattern[16];
static u8 cellSprite[16][CELL_BYTES];
static u8 pieceCellSprite[4][CELL_BYTES];
static u8 nextCellSprite[4][CELL_BYTES];
static u8 glyphSprite[FONT_WB * FONT_H];
static u8 piece;
static u8 rotation;
static i8 pieceX;
static i8 pieceY;
static u8 nextPiece;
static u8 gravityTick;
static u8 gravityDelay;
static u8 rngSeed;
static u16 linesCleared;
static char scoreText[SCORE_DIGITS + 1];
static u8 level;
static u8 controlMode;
static u8 holdL;
static u8 holdR;
static u8 holdD;
static u8 prevRotate;
static u8 prevDrop;
static cpct_keyID keyLeft;
static cpct_keyID keyRight;
static cpct_keyID keyRotate;
static cpct_keyID keyDown;
static cpct_keyID keyDrop;
static u16 firmwareRomPointer;

static const u8 palette[16] = {
   HW_BLUE, HW_BRIGHT_CYAN, HW_BRIGHT_YELLOW, HW_SKY_BLUE,
   HW_PASTEL_YELLOW, HW_PASTEL_GREEN, HW_PINK, HW_PASTEL_MAGENTA,
   HW_PASTEL_CYAN, HW_BRIGHT_WHITE, HW_PASTEL_BLUE, HW_BRIGHT_GREEN,
   HW_YELLOW, HW_ORANGE, HW_WHITE, HW_BLACK
};

#ifndef OVERLAY_SPLASH
static const u8 gravityDelays[MAX_LEVEL] = {
   39, 35, 32, 29, 27, 24, 22, 20, 18, 17,
   15, 14, 12, 11, 10, 9, 8, 8, 7, 6,
   6, 5, 5, 4, 4, 4, 3, 3, 3, 2,
   2, 2, 2, 2, 2, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1, 1, 1
};

static const u16 lineScoreTable[5] = { 0, 40, 100, 300, 1200 };

static const u8 shapes[7][4][4] = {
   {{SH(0,1),SH(1,1),SH(2,1),SH(3,1)},{SH(2,0),SH(2,1),SH(2,2),SH(2,3)},{SH(0,1),SH(1,1),SH(2,1),SH(3,1)},{SH(2,0),SH(2,1),SH(2,2),SH(2,3)}},
   {{SH(1,0),SH(2,0),SH(1,1),SH(2,1)},{SH(1,0),SH(2,0),SH(1,1),SH(2,1)},{SH(1,0),SH(2,0),SH(1,1),SH(2,1)},{SH(1,0),SH(2,0),SH(1,1),SH(2,1)}},
   {{SH(1,0),SH(0,1),SH(1,1),SH(2,1)},{SH(1,0),SH(1,1),SH(2,1),SH(1,2)},{SH(0,1),SH(1,1),SH(2,1),SH(1,2)},{SH(1,0),SH(0,1),SH(1,1),SH(1,2)}},
   {{SH(1,0),SH(2,0),SH(0,1),SH(1,1)},{SH(1,0),SH(1,1),SH(2,1),SH(2,2)},{SH(1,1),SH(2,1),SH(0,2),SH(1,2)},{SH(0,0),SH(0,1),SH(1,1),SH(1,2)}},
   {{SH(0,0),SH(1,0),SH(1,1),SH(2,1)},{SH(2,0),SH(1,1),SH(2,1),SH(1,2)},{SH(0,0),SH(1,0),SH(1,1),SH(2,1)},{SH(2,0),SH(1,1),SH(2,1),SH(1,2)}},
   {{SH(0,0),SH(0,1),SH(1,1),SH(2,1)},{SH(1,0),SH(2,0),SH(1,1),SH(1,2)},{SH(0,1),SH(1,1),SH(2,1),SH(2,2)},{SH(1,0),SH(1,1),SH(0,2),SH(1,2)}},
   {{SH(2,0),SH(0,1),SH(1,1),SH(2,1)},{SH(1,0),SH(1,1),SH(1,2),SH(2,2)},{SH(0,1),SH(1,1),SH(2,1),SH(0,2)},{SH(0,0),SH(1,0),SH(1,1),SH(1,2)}}
};
#define GRAVITY_DELAY_AT(index) (gravityDelays[(index)])
#define LINE_SCORE_AT(index) (lineScoreTable[(index)])
#define SHAPE_CELL(shape, rot, index) (shapes[(shape)][(rot)][(index)])
#else
#define GRAVITY_DELAY_AT(index) (((const u8*)OVERLAY_GRAVITY_DELAYS)[(index)])
#define LINE_SCORE_AT(index) (((const u16*)OVERLAY_LINE_SCORE_TABLE)[(index)])
#define SHAPE_CELL(shape, rot, index) (((const u8*)OVERLAY_SHAPES)[(((u16)(shape)) << 4) + (((u8)(rot)) << 2) + (index)])
#endif

#ifndef OVERLAY_SPLASH
static const KeyChoice keyChoices[] = {
   { Key_O, TXT_KEY_O }, { Key_P, TXT_KEY_P }, { Key_Q, TXT_KEY_Q }, { Key_A, TXT_KEY_A },
   { Key_Z, TXT_KEY_Z }, { Key_X, TXT_KEY_X }, { Key_M, TXT_KEY_M }, { Key_N, TXT_KEY_N },
   { Key_Space, TXT_KEY_SPACE }, { Key_CursorLeft, TXT_KEY_CUR_L },
   { Key_CursorRight, TXT_KEY_CUR_R }, { Key_CursorUp, TXT_KEY_CUR_U },
   { Key_CursorDown, TXT_KEY_CUR_D }
};
#define KEY_CHOICES keyChoices
#define KEY_CHOICE_COUNT (sizeof(keyChoices) / sizeof(keyChoices[0]))
#else
#define KEY_CHOICES OVERLAY_KEY_CHOICES
#define KEY_CHOICE_COUNT OVERLAY_KEY_CHOICE_COUNT
#endif

#ifndef MENU_CODE_OVERLAY
static const char* keyName(cpct_keyID key) {
   u8 i;
   const KeyChoice* choices = KEY_CHOICES;
   for (i = 0; i < KEY_CHOICE_COUNT; ++i)
      if (choices[i].id == key)
         return choices[i].name;
   return TXT_KEY_UNKNOWN;
}
#endif

#ifndef OVERLAY_SPLASH
static const u8 fontGlyphs[FONT_GLYPH_COUNT][FONT_GLYPH_ROWS] = {
   {0x0,0x0,0x0,0x0,0x0,0x0,0x0},
   {0x6,0x9,0x9,0xF,0x9,0x9,0x9},
   {0xE,0x9,0x9,0xE,0x9,0x9,0xE},
   {0x7,0x8,0x8,0x8,0x8,0x8,0x7},
   {0xE,0x9,0x9,0x9,0x9,0x9,0xE},
   {0xF,0x8,0x8,0xE,0x8,0x8,0xF},
   {0xF,0x8,0x8,0xE,0x8,0x8,0x8},
   {0x7,0x8,0x8,0xB,0x9,0x9,0x7},
   {0x9,0x9,0x9,0xF,0x9,0x9,0x9},
   {0xE,0x4,0x4,0x4,0x4,0x4,0xE},
   {0x1,0x1,0x1,0x1,0x9,0x9,0x6},
   {0x9,0xA,0xC,0x8,0xC,0xA,0x9},
   {0x8,0x8,0x8,0x8,0x8,0x8,0xF},
   {0x9,0xF,0xF,0x9,0x9,0x9,0x9},
   {0x9,0xD,0xD,0xB,0xB,0x9,0x9},
   {0x6,0x9,0x9,0x9,0x9,0x9,0x6},
   {0xE,0x9,0x9,0xE,0x8,0x8,0x8},
   {0x6,0x9,0x9,0x9,0xB,0xA,0x5},
   {0xE,0x9,0x9,0xE,0xC,0xA,0x9},
   {0x7,0x8,0x8,0x6,0x1,0x1,0xE},
   {0xF,0x4,0x4,0x4,0x4,0x4,0x4},
   {0x9,0x9,0x9,0x9,0x9,0x9,0x6},
   {0x9,0x9,0x9,0x9,0x9,0x6,0x6},
   {0x9,0x9,0x9,0x9,0xF,0xF,0x9},
   {0x9,0x9,0x6,0x6,0x6,0x9,0x9},
   {0x9,0x9,0x9,0x6,0x4,0x4,0x4},
   {0xF,0x1,0x2,0x4,0x8,0x8,0xF},
   {0x6,0x9,0xB,0xD,0x9,0x9,0x6},
   {0x2,0x6,0x2,0x2,0x2,0x2,0x7},
   {0xE,0x1,0x1,0x6,0x8,0x8,0xF},
   {0xE,0x1,0x1,0x6,0x1,0x1,0xE},
   {0x9,0x9,0x9,0xF,0x1,0x1,0x1},
   {0xF,0x8,0x8,0xE,0x1,0x1,0xE},
   {0x7,0x8,0x8,0xE,0x9,0x9,0x6},
   {0xF,0x1,0x2,0x2,0x4,0x4,0x4},
   {0x6,0x9,0x9,0x6,0x9,0x9,0x6},
   {0x6,0x9,0x9,0x7,0x1,0x1,0xE},
   {0x1,0x2,0x2,0x4,0x4,0x8,0x8},
   {0x0,0x0,0x0,0x0,0x0,0x6,0x6}
};
#define FONT_GLYPHS ((const u8*)fontGlyphs)
#else
#define FONT_GLYPHS FONT_OVERLAY_GLYPHS
#endif

static u8 glyphIndex(char c) {
   if (c >= 'a' && c <= 'z')
      c = (char)(c - 'a' + 'A');
   if (c >= 'A' && c <= 'Z')
      return (u8)(c - 'A' + 1);
   if (c >= '0' && c <= '9')
      return (u8)(c - '0' + 27);
   if (c == '/')
      return 37;
   if (c == '.')
      return 38;
   return 0;
}

static void drawText(u8 x, u8 y, const char* text, u8 pen) {
   u8 row;
   u8 bits;
   const u8* glyph;
   while (*text && x <= 80 - FONT_WB) {
      glyph = FONT_GLYPHS + (u16)glyphIndex(*text) * FONT_GLYPH_ROWS;
      for (row = 0; row < FONT_GLYPH_ROWS; ++row) {
         bits = glyph[row];
         glyphSprite[row * FONT_WB] = cpct_px2byteM0((bits & 8) ? pen : 0, (bits & 4) ? pen : 0);
         glyphSprite[row * FONT_WB + 1] = cpct_px2byteM0((bits & 2) ? pen : 0, (bits & 1) ? pen : 0);
      }
      glyphSprite[FONT_GLYPH_ROWS * FONT_WB] = 0;
      glyphSprite[FONT_GLYPH_ROWS * FONT_WB + 1] = 0;
      cpct_drawSprite(glyphSprite, cpct_getScreenPtr(CPCT_VMEM_START, x, y), FONT_WB, FONT_H);
      x += FONT_ADV;
      ++text;
   }
}

static void drawNumberWidth(u8 x, u8 y, u16 value, u8 width) {
   char buf[5];
   i8 i;
   buf[width] = 0;
   for (i = (i8)width - 1; i >= 0; --i) {
      buf[i] = '0' + (value % 10);
      value /= 10;
   }
   drawText(x, y, TXT_BLANK8, 9);
   drawText(x, y, buf, 9);
}

static void resetScore(void) {
   u8 i;
   for (i = 0; i < SCORE_DIGITS; ++i)
      scoreText[i] = '0';
   scoreText[SCORE_DIGITS] = 0;
}

static void addScoreValue(u16 value) {
   u8 digit;
   i8 i;
   for (i = SCORE_DIGITS - 1; i >= 0 && value; --i) {
      digit = (scoreText[i] - '0') + (value % 10);
      value /= 10;
      if (digit > 9) {
         digit -= 10;
         ++value;
      }
      scoreText[i] = '0' + digit;
   }
}

static void addLineScore(u8 cleared) {
   u8 i;
   for (i = 0; i < level; ++i)
      addScoreValue(LINE_SCORE_AT(cleared));
}

static void updateLevelAndGravity(void) {
   u16 newLevel;
   newLevel = 1 + linesCleared / LINES_PER_LEVEL;
   if (newLevel > MAX_LEVEL)
      newLevel = MAX_LEVEL;
   level = (u8)newLevel;
   gravityDelay = GRAVITY_DELAY_AT(level - 1);
}

static void resetInputState(void) {
   holdL = 0;
   holdR = 0;
   holdD = 0;
   prevRotate = 0;
   prevDrop = 0;
}

static void setDefaultKeys(void) {
   keyLeft = Key_O;
   keyRight = Key_P;
   keyRotate = Key_Q;
   keyDown = Key_A;
   keyDrop = Key_Space;
}

static void initRuntimeState(void) {
   rngSeed = 91;
   setDefaultKeys();
   resetInputState();
}

static u8 isDefaultKeyboardLayout(void) {
   return keyLeft == Key_O && keyRight == Key_P && keyRotate == Key_Q && keyDown == Key_A && keyDrop == Key_Space;
}

static void setVideoHardware(void) {
   cpct_setVideoMemoryPage(cpct_pageC0);
   cpct_setVideoMemoryOffset(0);
   cpct_setVideoMode(0);
   cpct_setPalette((u8*)palette, 16);
   cpct_setBorder(HW_BLUE);
}

static void initVideo(void) {
   u8 i;
   firmware_set_mode0();
   firmwareRomPointer = cpct_disableFirmware();
   setVideoHardware();
   for (i = 0; i < 16; ++i)
      cellPattern[i] = cpct_px2byteM0(i, i);
   cpct_clearScreen(cellPattern[0]);
}

#ifdef OVERLAY_SPLASH
static void loadRuntimeFontOverlay(void) {
   overlay_load_runtime_font();
   setVideoHardware();
}
#endif

static void setCellSpriteRow(u8 colour, u8 row, u8 p0, u8 p1, u8 p2, u8 p3) {
   cellSprite[colour][row * CELL_WB] = cpct_px2byteM0(p0, p1);
   cellSprite[colour][row * CELL_WB + 1] = cpct_px2byteM0(p2, p3);
}

static void setSpriteRow(u8* sprite, u8 row, u8 p0, u8 p1, u8 p2, u8 p3) {
   sprite[row * CELL_WB] = cpct_px2byteM0(p0, p1);
   sprite[row * CELL_WB + 1] = cpct_px2byteM0(p2, p3);
}

static void buildCellSprites(void) {
   u8 colour;
   u8 row;
   u8 p0;
   u8 p1;
   u8 p2;
   u8 p3;
   for (colour = 0; colour < 16; ++colour) {
      for (row = 0; row < CELL_H; ++row) {
         if (!colour || row == 0 || row == CELL_H - 1) {
            p0 = p1 = p2 = p3 = BOARD_BG;
         } else {
            p0 = p1 = p2 = colour;
            p3 = BOARD_BG;
         }
         setCellSpriteRow(colour, row, p0, p1, p2, p3);
      }
   }
}

static void buildSquareSprite(u8* sprite, u8 colour, u8 background) {
   u8 row;
   u8 p0;
   u8 p1;
   u8 p2;
   u8 p3;
   for (row = 0; row < CELL_H; ++row) {
      if (!colour || row == 0 || row == CELL_H - 1) {
         p0 = p1 = p2 = p3 = background;
      } else {
         p0 = p1 = p2 = colour;
         p3 = background;
      }
      setSpriteRow(sprite, row, p0, p1, p2, p3);
   }
}

static void drawCellAt(u8 screenX, u8 screenY, u8 colour) {
   u8* pvm;
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, screenX, screenY);
   if (!colour)
      cpct_drawSolidBox(pvm, cellPattern[BOARD_BG], CELL_WB, CELL_H);
   else
      cpct_drawSprite(cellSprite[colour], pvm, CELL_WB, CELL_H);
}

static void drawCell(u8 x, u8 y, u8 colour) {
   u8* pvm;
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X + x * CELL_WB, BOARD_Y + y * CELL_H);
   if (!colour)
      cpct_drawSolidBox(pvm, cellPattern[BOARD_BG], CELL_WB, CELL_H);
   else
      cpct_drawSprite(cellSprite[colour], pvm, CELL_WB, CELL_H);
}

static void buildPieceCellSprites(u8* sprites, u8 colour, u8 background) {
   u8 i;
   for (i = 0; i < 4; ++i)
      buildSquareSprite(sprites + i * CELL_BYTES, colour, background);
}

static void cacheCurrentPieceSprites(void) {
   buildPieceCellSprites((u8*)pieceCellSprite, piece, BOARD_BG);
}

static void cacheNextPieceSprites(void) {
   buildPieceCellSprites((u8*)nextCellSprite, nextPiece, 0);
}

static void drawBoardCell(u8 x, u8 y) {
   drawCellAt(
      BOARD_X + x * CELL_WB,
      BOARD_Y + y * CELL_H,
      board[y][x]
   );
}

static void drawBoardBackground(void) {
   u8* pvm;
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X, BOARD_Y);
   cpct_drawSolidBox(pvm, cellPattern[BOARD_BG], BOARD_W * CELL_WB, BOARD_H * CELL_H);
}

static void drawFrame(void) {
   u8* pvm;
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X - FRAME_WB, BOARD_Y - 4);
   cpct_drawSolidBox(pvm, cellPattern[8], BOARD_W * CELL_WB + FRAME_WB * 2, 4);
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X - FRAME_WB, BOARD_Y);
   cpct_drawSolidBox(pvm, cellPattern[8], FRAME_WB, BOARD_H * CELL_H);
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X + BOARD_W * CELL_WB, BOARD_Y);
   cpct_drawSolidBox(pvm, cellPattern[8], FRAME_WB, BOARD_H * CELL_H);
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X - FRAME_WB, BOARD_Y + BOARD_H * CELL_H);
   cpct_drawSolidBox(pvm, cellPattern[8], BOARD_W * CELL_WB + FRAME_WB * 2, 4);
   drawText(LEFT_PANEL_X, 20, TXT_SCORE, 9);
   drawText(LEFT_PANEL_X, 64, TXT_LEVEL, 9);
   drawText(LEFT_PANEL_X, 104, TXT_LINES, 9);
   drawText(RIGHT_PANEL_X, 20, TXT_TETRIS, 9);
   drawText(RIGHT_PANEL_X, 56, TXT_NEXT, 9);
   drawText(DEDICATION_X, DEDICATION_Y, TXT_DEDICATION, 9);
}

static void clearBoard(void) {
   u8 x;
   u8 y;
   for (y = 0; y < BOARD_H; ++y)
      for (x = 0; x < BOARD_W; ++x)
         board[y][x] = 0;
}

static void drawBoard(void) {
   u8 x;
   u8 y;
   u8 rowsUntilMusic;
   rowsUntilMusic = 0;
   for (y = 0; y < BOARD_H; ++y) {
      if (!rowsUntilMusic) {
         cpct_waitVSYNC();
         music_play_frame();
         rowsUntilMusic = 2;
      }
      for (x = 0; x < BOARD_W; ++x)
         drawBoardCell(x, y);
      --rowsUntilMusic;
   }
}

static void drawPieceAt(i8 x0, i8 y0, u8 r, u8 colour) {
   u8 i;
   u8 shape;
   u8 cell;
   i8 relX;
   i8 relY;
   i8 x;
   i8 y;
   shape = piece - 1;
   for (i = 0; i < 4; ++i) {
      cell = SHAPE_CELL(shape, r, i);
      relX = SHAPE_X(cell);
      relY = SHAPE_Y(cell);
      x = x0 + relX;
      y = y0 + relY;
      if (y >= 0) {
         if (colour)
            drawCellAt(
               BOARD_X + (u8)x * CELL_WB,
               BOARD_Y + (u8)y * CELL_H,
               colour
            );
         else
            drawCell((u8)x, (u8)y, 0);
      }
   }
}

static void drawPiece(u8 colour) {
   u8 i;
   u8 cell;
   i8 x;
   i8 y;
   if (!colour) {
      drawPieceAt(pieceX, pieceY, rotation, 0);
      return;
   }
   for (i = 0; i < 4; ++i) {
      cell = SHAPE_CELL(piece - 1, rotation, i);
      x = pieceX + SHAPE_X(cell);
      y = pieceY + SHAPE_Y(cell);
      if (y >= 0)
         cpct_drawSprite(
            pieceCellSprite[i],
            cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X + (u8)x * CELL_WB, BOARD_Y + (u8)y * CELL_H),
            CELL_WB,
            CELL_H
         );
   }
}

static u8 collision(i8 x0, i8 y0, u8 r) {
   u8 i;
   u8 cell;
   i8 x;
   i8 y;
   for (i = 0; i < 4; ++i) {
      cell = SHAPE_CELL(piece - 1, r, i);
      x = x0 + SHAPE_X(cell);
      y = y0 + SHAPE_Y(cell);
      if (x < 0 || x >= BOARD_W || y >= BOARD_H)
         return 1;
      if (y >= 0 && board[(u8)y][(u8)x])
         return 1;
   }
   return 0;
}

static u8 randomPiece(void) {
   rngSeed = rngSeed * 5 + 1;
   return (rngSeed % 7) + 1;
}

static void drawBigChar2x(u8 x, u8 y, char c, u8 pen) {
   u8 row;
   u8 bits;
   u8 p0;
   u8 p1;
   u8 p2;
   u8 p3;
   const u8* glyph;

   glyph = FONT_GLYPHS + (u16)glyphIndex(c) * FONT_GLYPH_ROWS;
   for (row = 0; row < FONT_H; ++row) {
      bits = row < FONT_GLYPH_ROWS ? glyph[row] : 0;
      p0 = (bits & 8) ? pen : 0;
      p1 = (bits & 4) ? pen : 0;
      p2 = (bits & 2) ? pen : 0;
      p3 = (bits & 1) ? pen : 0;
      glyphSprite[0] = glyphSprite[4] = cpct_px2byteM0(p0, p0);
      glyphSprite[1] = glyphSprite[5] = cpct_px2byteM0(p1, p1);
      glyphSprite[2] = glyphSprite[6] = cpct_px2byteM0(p2, p2);
      glyphSprite[3] = glyphSprite[7] = cpct_px2byteM0(p3, p3);
      cpct_drawSprite(glyphSprite, cpct_getScreenPtr(CPCT_VMEM_START, x, y + row * 2), GAME_OVER_WB, 2);
   }
}

static void drawGameOverTitle(u8 phase) {
   u8 i;
   for (i = 0; i < GAME_OVER_LEN; ++i)
      drawBigChar2x(GAME_OVER_X + i * GAME_OVER_WB, GAME_OVER_Y, GAME_OVER_TEXT[i], ((i + phase) % 15) + 1);
}

#ifndef MENU_CODE_OVERLAY
static void initMenuTitleColours(u8* colours) {
   u8 i;
   for (i = 0; i < MENU_TITLE_LEN; ++i)
      colours[i] = randomPiece();
}

static void shiftMenuTitleColours(u8* colours) {
   u8 i;
   u8 carry;
   u8 previous;
   carry = colours[MENU_TITLE_LEN - 1];
   for (i = 0; i < MENU_TITLE_LEN; ++i) {
      previous = colours[i];
      colours[i] = carry;
      carry = previous;
   }
}

static void drawMenuTitle(const u8* colours) {
   u8 i;
   char glyph[2];
   glyph[1] = 0;
   for (i = 0; i < MENU_TITLE_LEN; ++i) {
      glyph[0] = MENU_TITLE_TEXT[i];
      drawText(MENU_TITLE_X + i * FONT_ADV, MENU_TITLE_Y, glyph, colours[i]);
   }
}
#endif

static u8 spawnPiece(void) {
   piece = nextPiece;
   nextPiece = randomPiece();
   pieceX = 3;
   pieceY = 0;
   rotation = 0;
   gravityTick = 0;
   cacheCurrentPieceSprites();
   cacheNextPieceSprites();
   return collision(pieceX, pieceY, rotation);
}

static void lockPiece(void) {
   u8 i;
   u8 cell;
   i8 x;
   i8 y;
   for (i = 0; i < 4; ++i) {
      cell = SHAPE_CELL(piece - 1, rotation, i);
      x = pieceX + SHAPE_X(cell);
      y = pieceY + SHAPE_Y(cell);
      if (y >= 0)
         board[(u8)y][(u8)x] = piece;
   }
}

static u8 rowFull(u8 y) {
   u8 x;
   for (x = 0; x < BOARD_W; ++x)
      if (!board[y][x])
         return 0;
   return 1;
}

static void collapseRow(u8 y) {
   u8 x;
   while (y) {
      for (x = 0; x < BOARD_W; ++x)
         board[y][x] = board[y - 1][x];
      --y;
   }
   for (x = 0; x < BOARD_W; ++x)
      board[0][x] = 0;
}

static u8 clearLines(void) {
   i8 y;
   u8 cleared;
   cleared = 0;
   y = BOARD_H - 1;
   while (y >= 0) {
      if (rowFull((u8)y)) {
         collapseRow((u8)y);
         ++cleared;
      } else {
         --y;
      }
   }
   if (cleared) {
      addLineScore(cleared);
      linesCleared += cleared;
      updateLevelAndGravity();
      sfx_line_clear();
      drawBoard();
      cpct_waitVSYNC();
      music_play_frame();
      drawText(LEFT_PANEL_X, 36, scoreText, 9);
      cpct_waitVSYNC();
      music_play_frame();
      drawNumberWidth(LEFT_PANEL_X, 80, level, 3);
      cpct_waitVSYNC();
      music_play_frame();
      drawNumberWidth(LEFT_PANEL_X, 120, linesCleared, 4);
      cpct_waitVSYNC();
      music_play_frame();
   }
   return cleared;
}

static void drawNext(void) {
   u8 cell;
   u8 x;
   u8 y;
   u8 i;
   u8 shape;
   u8* pvm;
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, RIGHT_PANEL_X, NEXT_PREVIEW_Y);
   cpct_drawSolidBox(pvm, cellPattern[0], 20, 32);
   shape = nextPiece - 1;
   for (i = 0; i < 4; ++i) {
      cell = SHAPE_CELL(shape, 0, i);
      x = SHAPE_X(cell);
      y = SHAPE_Y(cell);
      cpct_drawSprite(
         nextCellSprite[i],
         cpct_getScreenPtr(CPCT_VMEM_START, RIGHT_PANEL_X + x * CELL_WB, NEXT_PREVIEW_Y + y * CELL_H),
         CELL_WB,
         CELL_H
      );
   }
}

static u8 heldPressed(u8 pressed, u8* hold, u8 firstDelay, u8 repeatDelay) {
   if (pressed) {
      ++(*hold);
      if (*hold == 1)
         return 1;
      if (*hold > firstDelay && ((*hold - firstDelay) % repeatDelay) == 0)
         return 1;
   } else {
      *hold = 0;
   }
   return 0;
}

static u8 heldAction(cpct_keyID key, u8* hold, u8 firstDelay, u8 repeatDelay) {
   return heldPressed(cpct_isKeyPressed(key), hold, firstDelay, repeatDelay);
}

static u8 heldEitherAction(cpct_keyID keyA, cpct_keyID keyB, u8* hold, u8 firstDelay, u8 repeatDelay) {
   return heldPressed(cpct_isKeyPressed(keyA) || cpct_isKeyPressed(keyB), hold, firstDelay, repeatDelay);
}

static u8 readActions(void) {
   u8 actions;
   u8 rotatePressed;
   u8 dropPressed;
   u8 defaultLayout;
   cpct_scanKeyboard_f();
   actions = 0;

   if (controlMode) {
      if (heldAction(Joy0_Left, &holdL, 8, 3))
         actions |= ACT_LEFT;
      if (heldAction(Joy0_Right, &holdR, 8, 3))
         actions |= ACT_RIGHT;
      if (heldAction(Joy0_Down, &holdD, 1, 1))
         actions |= ACT_DOWN;
      rotatePressed = cpct_isKeyPressed(Joy0_Fire1);
      dropPressed = cpct_isKeyPressed(Joy0_Up) || cpct_isKeyPressed(Joy0_Fire2);
   } else {
      defaultLayout = isDefaultKeyboardLayout();
      if (defaultLayout) {
         if (heldEitherAction(keyLeft, Key_CursorLeft, &holdL, 8, 3))
            actions |= ACT_LEFT;
         if (heldEitherAction(keyRight, Key_CursorRight, &holdR, 8, 3))
            actions |= ACT_RIGHT;
         if (heldEitherAction(keyDown, Key_CursorDown, &holdD, 1, 1))
            actions |= ACT_DOWN;
         rotatePressed = cpct_isKeyPressed(keyRotate) || cpct_isKeyPressed(Key_CursorUp);
         dropPressed = cpct_isKeyPressed(keyDrop) || cpct_isKeyPressed(Key_Return) || cpct_isKeyPressed(Key_Enter);
      } else {
         if (heldAction(keyLeft, &holdL, 8, 3))
            actions |= ACT_LEFT;
         if (heldAction(keyRight, &holdR, 8, 3))
            actions |= ACT_RIGHT;
         if (heldAction(keyDown, &holdD, 1, 1))
            actions |= ACT_DOWN;
         rotatePressed = cpct_isKeyPressed(keyRotate);
         dropPressed = cpct_isKeyPressed(keyDrop);
      }
   }

   if (rotatePressed && !prevRotate)
      actions |= ACT_ROTATE;
   if (dropPressed && !prevDrop)
      actions |= ACT_DROP;
   prevRotate = rotatePressed;
   prevDrop = dropPressed;
   return actions;
}

static u8 applyActions(u8 actions) {
   u8 newRot;
   if ((actions & ACT_LEFT) && !collision(pieceX - 1, pieceY, rotation))
      --pieceX;
   if ((actions & ACT_RIGHT) && !collision(pieceX + 1, pieceY, rotation))
      ++pieceX;
   if (actions & ACT_ROTATE) {
      newRot = (rotation + 1) & 3;
      if (!collision(pieceX, pieceY, newRot)) {
         rotation = newRot;
         cacheCurrentPieceSprites();
      }
   }
   if (actions & ACT_DROP) {
      while (!collision(pieceX, pieceY + 1, rotation))
         ++pieceY;
      return 1;
   }
   if (actions & ACT_DOWN) {
      if (!collision(pieceX, pieceY + 1, rotation))
         ++pieceY;
      else
         return 1;
      return 0;
   }
   ++gravityTick;
   if (gravityTick >= gravityDelay) {
      gravityTick = 0;
      if (!collision(pieceX, pieceY + 1, rotation))
         ++pieceY;
      else
         return 1;
   }
   return 0;
}

static u8 anyInputPressed(void) {
   return cpct_isAnyKeyPressed_f() || cpct_isKeyPressed(Joy0_Fire1) || cpct_isKeyPressed(Joy0_Fire2);
}

static void waitReleased(void) {
   do {
      cpct_waitVSYNC();
      cpct_scanKeyboard_f();
   } while (anyInputPressed());
}

static void drawSplashImage(void) {
   const u8* src;
   u8 y;
   src = splash_img;
   for (y = 0; y < SPLASH_HEIGHT; ++y) {
      cpct_memcpy(cpct_getScreenPtr(CPCT_VMEM_START, 0, y), src, SPLASH_W_BYTES);
      src += SPLASH_W_BYTES;
   }
}

static void showSplash(void) {
   cpct_clearScreen(cellPattern[0]);
   drawSplashImage();
   music_init_troika();
   waitReleased();
   do {
      cpct_waitVSYNC();
      music_play_frame();
      cpct_scanKeyboard_f();
   } while (!anyInputPressed());
   music_stop();
   waitReleased();
}

#ifndef MENU_CODE_OVERLAY
static cpct_keyID chooseKey(const char* prompt) {
   u8 i;
   const KeyChoice* choices = KEY_CHOICES;
   drawText(4, 120, TXT_BLANK16, 9);
   drawText(4, 120, prompt, 9);
   waitReleased();
   while (1) {
      cpct_waitVSYNC();
      cpct_scanKeyboard_f();
      for (i = 0; i < KEY_CHOICE_COUNT; ++i) {
         if (cpct_isKeyPressed(choices[i].id)) {
            drawText(4, 136, TXT_SET_PAD, 9);
            drawText(8, 136, choices[i].name, 9);
            waitReleased();
            return choices[i].id;
         }
      }
   }
}

static void redefineKeys(void) {
   cpct_clearScreen(cellPattern[0]);
   drawText(4, 24, TXT_REDEFINE_KEYS, 9);
   drawText(4, 48, TXT_REDEFINE_KEYS_HINT, 9);
   drawText(4, 64, TXT_SPACE_OR_CURSORS, 9);
   keyLeft = chooseKey(TXT_LEFT);
   keyRight = chooseKey(TXT_RIGHT);
   keyRotate = chooseKey(TXT_ROTATE);
   keyDown = chooseKey(TXT_DOWN);
   keyDrop = chooseKey(TXT_DROP);
}

static u8 menu(void) {
   u8 titleFrame;
   u8 titleColours[MENU_TITLE_LEN];

   music_stop();
   cpct_clearScreen(cellPattern[0]);
   initMenuTitleColours(titleColours);
   drawMenuTitle(titleColours);
   drawText(4, 48, TXT_SELECT, 11);
   drawText(4, 72, TXT_MENU_KEYBOARD, 9);
   drawText(4, 96, TXT_MENU_JOYSTICK, 9);
   drawText(4, 120, TXT_MENU_REDEFINE, 9);
   drawText(42, 48, TXT_KEYS, 2);
   drawText(42, 72, TXT_LEFT, 9);
   drawText(58, 72, keyName(keyLeft), 9);
   drawText(42, 88, TXT_RIGHT, 9);
   drawText(58, 88, keyName(keyRight), 9);
   drawText(42, 104, TXT_ROTATE, 9);
   drawText(58, 104, keyName(keyRotate), 9);
   drawText(42, 120, TXT_DOWN, 9);
   drawText(58, 120, keyName(keyDown), 9);
   drawText(42, 136, TXT_DROP, 9);
   drawText(58, 136, keyName(keyDrop), 9);
   waitReleased();
   titleFrame = 0;
   while (1) {
      cpct_waitVSYNC();
      if (++titleFrame >= MENU_TITLE_ANIM_FRAMES) {
         titleFrame = 0;
         shiftMenuTitleColours(titleColours);
         drawMenuTitle(titleColours);
      }
      cpct_scanKeyboard_f();
      if (cpct_isKeyPressed(Key_1))
         return 0;
      if (cpct_isKeyPressed(Key_2))
         return 1;
      if (cpct_isKeyPressed(Key_3)) {
         redefineKeys();
         return menu();
      }
   }
}
#else
static u8 menu(void) {
   overlay_load_menu_code();
   return overlay_run_menu_code();
}
#endif

static void startGame(void) {
   u8 lock;
   u8 actions;
   i8 oldX;
   i8 oldY;
   u8 oldRot;
   u8 changed;
   u8 cleared;
   controlMode = menu();
   waitReleased();
   resetInputState();
   cpct_clearScreen(cellPattern[0]);
   clearBoard();
   drawFrame();
   drawBoardBackground();
   linesCleared = 0;
   resetScore();
   updateLevelAndGravity();
   nextPiece = randomPiece();
   drawText(LEFT_PANEL_X, 36, scoreText, 9);
   drawNumberWidth(LEFT_PANEL_X, 80, level, 3);
   drawNumberWidth(LEFT_PANEL_X, 120, linesCleared, 4);
   music_init();
   if (spawnPiece())
      return;
   drawNext();
   drawPiece(piece);
   while (1) {
      actions = readActions();
      oldX = pieceX;
      oldY = pieceY;
      oldRot = rotation;
      lock = applyActions(actions);
      changed = oldX != pieceX || oldY != pieceY || oldRot != rotation;
      cpct_waitVSYNC();
      if (changed)
         drawPieceAt(oldX, oldY, oldRot, 0);
      if (lock) {
         drawPiece(piece);
         lockPiece();
         cleared = clearLines();
         if (spawnPiece())
            break;
         if (cleared) {
            cpct_waitVSYNC();
            music_play_frame();
         }
         drawNext();
         if (cleared) {
            cpct_waitVSYNC();
            music_play_frame();
         }
         drawPiece(piece);
         if (cleared) {
            cpct_waitVSYNC();
            music_play_frame();
         }
      }
      if (!lock && changed)
         drawPiece(piece);
      music_play_frame();
   }
   music_stop();
   cpct_clearScreen(cellPattern[0]);
   actions = 0;
   changed = 0;
   drawGameOverTitle(actions);
   drawText(27, 112, TXT_PRESS_ANY_KEY, 9);
   waitReleased();
   while (!cpct_isAnyKeyPressed_f()) {
      cpct_waitVSYNC();
      if (++changed >= GAME_OVER_COLOUR_FRAMES) {
         changed = 0;
         if (++actions >= 15)
            actions = 0;
         drawGameOverTitle(actions);
      }
      cpct_scanKeyboard_f();
   }
   waitReleased();
}

void main(void) {
   initRuntimeState();
#ifdef OVERLAY_SPLASH
   overlay_load_initial_segments();
#endif
   initVideo();
   buildCellSprites();
   showSplash();
#ifdef OVERLAY_SPLASH
   loadRuntimeFontOverlay();
#endif
   while (1)
      startGame();
}
