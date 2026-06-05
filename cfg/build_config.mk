CPCT_PATH ?= ../cpctelera

ifeq ($(strip $(CPCT_PATH)),)
$(error CPCT_PATH is not set. Install CPCtelera, run setup.sh, and build from a Cygwin shell)
endif

PROJNAME   := TETRIS
Z80CODELOC := 0x1000

SRCDIR      := src
DSKFILESDIR := dsk_files
OBJDIR      := obj

C_EXT      := c
ASM_EXT    := s
BIN_EXT    := bin
OBJ_EXT    := rel
DSKINC_EXT := dskinc

IHXFILE := $(OBJDIR)/$(PROJNAME).ihx
BINFILE := $(OBJDIR)/$(PROJNAME).bin
CDT     := $(PROJNAME).cdt
DSK     := $(PROJNAME).dsk
DSKINC  := $(OBJDIR)/$(DSK).$(DSKINC_EXT)

TARGET := $(DSK) $(CDT)
OBJS2CLEAN :=

include $(CPCT_PATH)/cfg/global_paths.mk

Z80CCFLAGS    :=
ifeq ($(OVERLAY_SPLASH),1)
Z80CCFLAGS    += -DOVERLAY_SPLASH=1
endif
ifeq ($(MENU_CODE_OVERLAY),1)
Z80CCFLAGS    += -DMENU_CODE_OVERLAY=1
endif
Z80ASMFLAGS   := -l -o -s
Z80CCINCLUDE  := -I$(CPCT_SRC) -I$(SRCDIR)
Z80CCLINKARGS := -mz80 --no-std-crt0 -Wl-u \
                 --code-loc $(Z80CODELOC) \
                 --data-loc 0 -l$(CPCT_LIB)

include $(CPCT_PATH)/cfg/global_functions.mk
include cfg/image_conversion.mk
include cfg/tilemap_conversion.mk
include cfg/music_conversion.mk

SUBDIRS        := $(filter-out ., $(shell find $(SRCDIR) -type d -print))
OBJDSKINCSDIR  := $(OBJDIR)/$(DSKFILESDIR)
OBJSUBDIRS     := $(OBJDSKINCSDIR) $(foreach DIR, $(SUBDIRS), $(patsubst $(SRCDIR)%, $(OBJDIR)%, $(DIR)))

CFILES         := $(foreach DIR, $(SUBDIRS), $(wildcard $(DIR)/*.$(C_EXT)))
CFILES         := $(filter-out $(IMGCFILES), $(CFILES))
ASMFILES       := $(foreach DIR, $(SUBDIRS), $(wildcard $(DIR)/*.$(ASM_EXT)))
ASMFILES       := $(filter-out $(IMGASMFILES), $(ASMFILES))
ifeq ($(OVERLAY_SPLASH),1)
ASMFILES       := $(filter-out $(SRCDIR)/splash.s $(SRCDIR)/music.s, $(ASMFILES))
else
ASMFILES       := $(filter-out $(SRCDIR)/overlay/music_overlay.generated.s $(SRCDIR)/overlay/runtime_overlay_loader.generated.s, $(ASMFILES))
endif
BIN2CFILES     := $(foreach DIR, $(SUBDIRS), $(wildcard $(DIR)/*.$(BIN_EXT)))
DSKINCSRCFILES := $(wildcard $(DSKFILESDIR)/*)

BIN_OBJFILES    := $(patsubst %.$(BIN_EXT), %.$(C_EXT), $(BIN2CFILES))
CFILES          := $(filter-out $(BIN_OBJFILES), $(CFILES))
GENC_OBJFILES   := $(patsubst $(SRCDIR)%, $(OBJDIR)%, $(patsubst %.$(C_EXT), %.$(OBJ_EXT), $(IMGCFILES)))
GENASM_OBJFILES := $(patsubst $(SRCDIR)%, $(OBJDIR)%, $(patsubst %.$(ASM_EXT), %.$(OBJ_EXT), $(IMGASMFILES)))
C_OBJFILES      := $(patsubst $(SRCDIR)%, $(OBJDIR)%, $(patsubst %.$(C_EXT), %.$(OBJ_EXT), $(BIN_OBJFILES) $(CFILES)))
ASM_OBJFILES    := $(patsubst $(SRCDIR)%, $(OBJDIR)%, $(patsubst %.$(ASM_EXT), %.$(OBJ_EXT), $(ASMFILES)))
DSKINCOBJFILES  := $(foreach FILE, $(DSKINCSRCFILES), $(patsubst $(DSKFILESDIR)/%, $(OBJDSKINCSDIR)/%, $(FILE)).$(DSKINC_EXT))
OBJFILES        := $(C_OBJFILES) $(ASM_OBJFILES)
GENOBJFILES     := $(GENC_OBJFILES) $(GENASM_OBJFILES)
