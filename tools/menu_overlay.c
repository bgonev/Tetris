#include <cpctelera.h>

typedef struct {
   cpct_keyID id;
   const char* name;
} KeyChoice;

#include "overlay/overlay_text.generated.h"

#define FONT_ADV 2
#define MENU_TITLE_TEXT TXT_MENU_TITLE
#define MENU_TITLE_LEN 17
#define MENU_TITLE_X 23
#define MENU_TITLE_Y 20
#define MENU_TITLE_ANIM_FRAMES 25
#define KEY_CHOICES OVERLAY_KEY_CHOICES
#define KEY_CHOICE_COUNT OVERLAY_KEY_CHOICE_COUNT

extern u8 cellPattern[];
extern cpct_keyID keyLeft;
extern cpct_keyID keyRight;
extern cpct_keyID keyRotate;
extern cpct_keyID keyDown;
extern cpct_keyID keyDrop;

extern void drawText(u8 x, u8 y, const char* text, u8 pen);
extern void waitReleased(void);
extern u8 randomPiece(void);
extern void music_stop(void);

static const char* keyName(cpct_keyID key) {
   u8 i;
   const KeyChoice* choices = KEY_CHOICES;
   for (i = 0; i < KEY_CHOICE_COUNT; ++i)
      if (choices[i].id == key)
         return choices[i].name;
   return TXT_KEY_UNKNOWN;
}

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

u8 menu_overlay_run(void) {
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
         return menu_overlay_run();
      }
   }
}
