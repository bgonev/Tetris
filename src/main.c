#include <cpctelera.h>
#include "splash.h"

#define BOARD_W 10
#define BOARD_H 20
#define CELL_WB 2
#define CELL_H 8
#define CELL_BYTES (CELL_WB * CELL_H)
#define BOARD_X 10
#define BOARD_Y 16
#define PANEL_X 44
#define DEDICATION_X 18
#define DEDICATION_Y 188
#define FRAME_WB 2
#define FONT_WB 2
#define FONT_H 8
#define FONT_ADV 2
#define FONT_GLYPH_ROWS 7

#define ACT_LEFT   1
#define ACT_RIGHT  2
#define ACT_DOWN   4
#define ACT_ROTATE 8
#define ACT_DROP   16

#define CELL_INNER_BORDER 0
#define CELL_OUTER_BORDER CELL_INNER_BORDER

extern void music_init(void);
extern void music_init_troika(void);
extern void music_play_frame(void);
extern void music_stop(void);
extern void sfx_line_clear(void);
extern void firmware_set_mode0(void);

typedef struct {
   cpct_keyID id;
   const char* name;
} KeyChoice;

static u8 board[BOARD_H][BOARD_W];
static u8 cellPattern[16];
static u8 cellSprite[16][CELL_BYTES];
static u8 cellDrawSprite[CELL_BYTES];
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

static const u8 palette[16] = {
   HW_BLUE, HW_BRIGHT_CYAN, HW_BRIGHT_YELLOW, HW_SKY_BLUE,
   HW_PASTEL_YELLOW, HW_PASTEL_GREEN, HW_PINK, HW_PASTEL_MAGENTA,
   HW_PASTEL_CYAN, HW_BRIGHT_WHITE, HW_PASTEL_BLUE, HW_BRIGHT_GREEN,
   HW_YELLOW, HW_ORANGE, HW_WHITE, HW_BLACK
};

static const u8 shapes[7][4][8] = {
   {{0,1,1,1,2,1,3,1},{2,0,2,1,2,2,2,3},{0,1,1,1,2,1,3,1},{2,0,2,1,2,2,2,3}},
   {{1,0,2,0,1,1,2,1},{1,0,2,0,1,1,2,1},{1,0,2,0,1,1,2,1},{1,0,2,0,1,1,2,1}},
   {{1,0,0,1,1,1,2,1},{1,0,1,1,2,1,1,2},{0,1,1,1,2,1,1,2},{1,0,0,1,1,1,1,2}},
   {{1,0,2,0,0,1,1,1},{1,0,1,1,2,1,2,2},{1,1,2,1,0,2,1,2},{0,0,0,1,1,1,1,2}},
   {{0,0,1,0,1,1,2,1},{2,0,1,1,2,1,1,2},{0,0,1,0,1,1,2,1},{2,0,1,1,2,1,1,2}},
   {{0,0,0,1,1,1,2,1},{1,0,2,0,1,1,1,2},{0,1,1,1,2,1,2,2},{1,0,1,1,0,2,1,2}},
   {{2,0,0,1,1,1,2,1},{1,0,1,1,1,2,2,2},{0,1,1,1,2,1,0,2},{0,0,1,0,1,1,1,2}}
};

static const KeyChoice keyChoices[] = {
   { Key_O, "O" }, { Key_P, "P" }, { Key_Q, "Q" }, { Key_A, "A" },
   { Key_Z, "Z" }, { Key_X, "X" }, { Key_M, "M" }, { Key_N, "N" },
   { Key_Space, "SPACE" }, { Key_CursorLeft, "CUR L" },
   { Key_CursorRight, "CUR R" }, { Key_CursorUp, "CUR U" },
   { Key_CursorDown, "CUR D" }
};

static const u8 fontGlyphs[38][7] = {
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
   {0x1,0x2,0x2,0x4,0x4,0x8,0x8}
};

static u8 glyphIndex(char c) {
   if (c >= 'a' && c <= 'z')
      c = (char)(c - 'a' + 'A');
   if (c >= 'A' && c <= 'Z')
      return (u8)(c - 'A' + 1);
   if (c >= '0' && c <= '9')
      return (u8)(c - '0' + 27);
   if (c == '/')
      return 37;
   return 0;
}

static void drawText(u8 x, u8 y, const char* text, u8 pen) {
   u8 row;
   u8 bits;
   const u8* glyph;
   while (*text && x <= 80 - FONT_WB) {
      glyph = fontGlyphs[glyphIndex(*text)];
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

static void drawNumber(u8 x, u8 y, u16 value) {
   char buf[6];
   i8 i;
   buf[5] = 0;
   for (i = 4; i >= 0; --i) {
      buf[i] = '0' + (value % 10);
      value /= 10;
   }
   drawText(x, y, "     ", 9);
   drawText(x, y, buf, 9);
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

static void initVideo(void) {
   u8 i;
   firmware_set_mode0();
   cpct_disableFirmware();
   cpct_setVideoMemoryPage(cpct_pageC0);
   cpct_setVideoMemoryOffset(0);
   cpct_setVideoMode(0);
   cpct_setPalette((u8*)palette, 16);
   for (i = 0; i < 16; ++i)
      cellPattern[i] = cpct_px2byteM0(i, i);
   cpct_setBorder(HW_BLUE);
   cpct_clearScreen(cellPattern[0]);
}

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
   for (colour = 0; colour < 16; ++colour) {
      if (!colour) {
         for (row = 0; row < CELL_WB * CELL_H; ++row)
            cellSprite[colour][row] = 0;
      } else {
         for (row = 0; row < CELL_H; ++row)
            setCellSpriteRow(colour, row, colour, colour, colour, colour);
      }
   }
}

static void buildSquareSprite(u8* sprite, u8 colour) {
   u8 row;
   u8 p0;
   u8 p1;
   u8 p2;
   u8 p3;
   for (row = 0; row < CELL_H; ++row) {
      if (!colour || row == 0 || row == CELL_H - 1) {
         p0 = p1 = p2 = p3 = 0;
      } else {
         p0 = p1 = p2 = colour;
         p3 = CELL_INNER_BORDER;
      }
      setSpriteRow(sprite, row, p0, p1, p2, p3);
   }
}

static void drawCellAt(u8 screenX, u8 screenY, u8 colour) {
   buildSquareSprite(cellDrawSprite, colour);
   cpct_drawSprite(cellDrawSprite, cpct_getScreenPtr(CPCT_VMEM_START, screenX, screenY), CELL_WB, CELL_H);
}

static void drawCell(u8 x, u8 y, u8 colour) {
   u8* pvm;
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, BOARD_X + x * CELL_WB, BOARD_Y + y * CELL_H);
   cpct_drawSprite(cellSprite[colour], pvm, CELL_WB, CELL_H);
}

static void buildPieceCellSprites(u8* sprites, u8 colour) {
   u8 i;
   for (i = 0; i < 4; ++i)
      buildSquareSprite(sprites + i * CELL_BYTES, colour);
}

static void cacheCurrentPieceSprites(void) {
   buildPieceCellSprites((u8*)pieceCellSprite, piece);
}

static void cacheNextPieceSprites(void) {
   buildPieceCellSprites((u8*)nextCellSprite, nextPiece);
}

static void drawBoardCell(u8 x, u8 y) {
   drawCellAt(
      BOARD_X + x * CELL_WB,
      BOARD_Y + y * CELL_H,
      board[y][x]
   );
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
   drawText(PANEL_X, 16, "TETRIS", 9);
   drawText(PANEL_X, 40, "LINES", 9);
   drawText(PANEL_X, 72, "LEVEL", 9);
   drawText(PANEL_X, 112, "NEXT", 9);
   drawText(DEDICATION_X, DEDICATION_Y, "for my daughter Marija", 9);
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
   for (y = 0; y < BOARD_H; ++y)
      for (x = 0; x < BOARD_W; ++x)
         drawBoardCell(x, y);
}

static void drawPieceAt(i8 x0, i8 y0, u8 r, u8 colour) {
   u8 i;
   u8 shape;
   i8 relX;
   i8 relY;
   i8 x;
   i8 y;
   shape = piece - 1;
   for (i = 0; i < 4; ++i) {
      relX = shapes[shape][r][i * 2];
      relY = shapes[shape][r][i * 2 + 1];
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
   i8 x;
   i8 y;
   if (!colour) {
      drawPieceAt(pieceX, pieceY, rotation, 0);
      return;
   }
   for (i = 0; i < 4; ++i) {
      x = pieceX + shapes[piece - 1][rotation][i * 2];
      y = pieceY + shapes[piece - 1][rotation][i * 2 + 1];
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
   i8 x;
   i8 y;
   for (i = 0; i < 4; ++i) {
      x = x0 + shapes[piece - 1][r][i * 2];
      y = y0 + shapes[piece - 1][r][i * 2 + 1];
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
   i8 x;
   i8 y;
   for (i = 0; i < 4; ++i) {
      x = pieceX + shapes[piece - 1][rotation][i * 2];
      y = pieceY + shapes[piece - 1][rotation][i * 2 + 1];
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

static void clearLines(void) {
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
      sfx_line_clear();
      linesCleared += cleared;
      level = 1 + (u8)(linesCleared / 10);
      if (level < 10)
         gravityDelay = 24 - level * 2;
      else
         gravityDelay = 5;
      drawBoard();
      drawNumber(PANEL_X, 56, linesCleared);
      drawNumber(PANEL_X, 88, level);
   }
}

static void drawNext(void) {
   u8 x;
   u8 y;
   u8 i;
   u8 shape;
   u8* pvm;
   pvm = cpct_getScreenPtr(CPCT_VMEM_START, PANEL_X, 128);
   cpct_drawSolidBox(pvm, cellPattern[0], 20, 32);
   shape = nextPiece - 1;
   for (i = 0; i < 4; ++i) {
      x = shapes[shape][0][i * 2];
      y = shapes[shape][0][i * 2 + 1];
      cpct_drawSprite(
         nextCellSprite[i],
         cpct_getScreenPtr(CPCT_VMEM_START, PANEL_X + x * CELL_WB, 128 + y * CELL_H),
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

static cpct_keyID chooseKey(const char* prompt) {
   u8 i;
   drawText(4, 120, "                ", 9);
   drawText(4, 120, prompt, 9);
   waitReleased();
   while (1) {
      cpct_waitVSYNC();
      cpct_scanKeyboard_f();
      for (i = 0; i < sizeof(keyChoices) / sizeof(keyChoices[0]); ++i) {
         if (cpct_isKeyPressed(keyChoices[i].id)) {
            drawText(4, 136, "SET             ", 9);
            drawText(8, 136, keyChoices[i].name, 9);
            waitReleased();
            return keyChoices[i].id;
         }
      }
   }
}

static void redefineKeys(void) {
   cpct_clearScreen(cellPattern[0]);
   drawText(4, 24, "REDEFINE KEYS", 9);
   drawText(4, 48, "USE O P Q A Z X M N", 9);
   drawText(4, 64, "SPACE OR CURSORS", 9);
   keyLeft = chooseKey("LEFT");
   keyRight = chooseKey("RIGHT");
   keyRotate = chooseKey("ROTATE");
   keyDown = chooseKey("DOWN");
   keyDrop = chooseKey("DROP");
}

static u8 menu(void) {
   music_stop();
   cpct_clearScreen(cellPattern[0]);
   drawText(20, 24, "TETRIS", 9);
   drawText(8, 64, "1 KEYBOARD", 9);
   drawText(8, 84, "2 JOYSTICK", 9);
   drawText(8, 104, "3 REDEFINE", 9);
   drawText(8, 136, "O/P OR CURSORS", 9);
   drawText(8, 152, "Q OR UP ROTATE", 9);
   drawText(8, 168, "A OR DOWN", 9);
   drawText(8, 184, "SPACE DROP", 9);
   waitReleased();
   while (1) {
      cpct_waitVSYNC();
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

static void startGame(void) {
   u8 lock;
   u8 actions;
   i8 oldX;
   i8 oldY;
   u8 oldRot;
   u8 changed;
   controlMode = menu();
   waitReleased();
   resetInputState();
   cpct_clearScreen(cellPattern[0]);
   clearBoard();
   drawFrame();
   linesCleared = 0;
   level = 1;
   gravityDelay = 22;
   nextPiece = randomPiece();
   drawNumber(PANEL_X, 56, linesCleared);
   drawNumber(PANEL_X, 88, level);
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
         clearLines();
         if (spawnPiece())
            break;
         drawNext();
         drawPiece(piece);
      }
      if (!lock && changed)
         drawPiece(piece);
      music_play_frame();
   }
   music_stop();
   cpct_clearScreen(cellPattern[0]);
   drawText(16, 80, "GAME OVER", 9);
   drawText(8, 112, "PRESS ANY KEY", 9);
   waitReleased();
   while (!cpct_isAnyKeyPressed_f()) {
      cpct_waitVSYNC();
      cpct_scanKeyboard_f();
   }
   waitReleased();
}

void main(void) {
   initRuntimeState();
   initVideo();
   buildCellSprites();
   showSplash();
   while (1)
      startGame();
}
