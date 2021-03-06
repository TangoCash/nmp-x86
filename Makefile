####################################################
# Makefile for building native neutrino / libstb-hal
# (C) 2012,2013 Stefan Seyfried
#
# taken from seife's build system, modified from
# (C) 2014 TangoCash, 2015 Max,TangoCash
# (C) 2016 TangoCash
#
# prerequisite packages need to be installed,
# no checking is done for that
####################################################

ARCHIVE    = $(HOME)/Archive
BASE_DIR   = $(PWD)
BUILD_SRC  = $(BASE_DIR)/build_source
BUILD_TMP        = $(BASE_DIR)/build_tmp
SCRIPTS    = $(BASE_DIR)/scripts

BOXTYPE    = generic
DEST       = $(BASE_DIR)/build_sysroot
D          = $(BASE_DIR)/deps

LH_SRC     = $(BUILD_SRC)/libstb-hal
LH_OBJ     = $(BUILD_TMP)/libstb-hal
N_SRC      = $(BUILD_SRC)/neutrino
N_OBJ      = $(BUILD_TMP)/neutrino

PATCHES    = $(BASE_DIR)/patches

PARALLEL_JOBS := $(shell echo $$((1 + `getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1`)))
override MAKE = make $(if $(findstring j,$(filter-out --%,$(MAKEFLAGS))),,-j$(PARALLEL_JOBS)) $(SILENT_OPT)

#supported flavours: classic,franken,tangos (default)
FLAVOUR	  ?= tangos

N_PATCHES  = $(PATCHES)/neutrino-mp.pc.diff
LH_PATCHES = $(PATCHES)/libstb-hal.pc.diff

CFLAGS     = -funsigned-char -g -W -Wall -Wshadow -O2
CFLAGS    += -rdynamic
CFLAGS    += -DPEDANTIC_VALGRIND_SETUP
CFLAGS    += -DDYNAMIC_LUAPOSIX
CFLAGS    += -ggdb
CFLAGS    += -D__user=
CFLAGS    += -D__STDC_CONSTANT_MACROS
### enable --as-needed for catching more build problems...
CFLAGS    += -Wl,--as-needed
CFLAGS    += $(shell pkg-config --cflags --libs freetype2)
###
CFLAGS    += -pthread
CFLAGS    += $(shell pkg-config --cflags --libs glib-2.0)
CFLAGS    += $(shell pkg-config --cflags --libs libxml-2.0)
### GST
ifeq ($(shell pkg-config --exists gstreamer-0.10 && echo 1),1)
	CFLAGS    += $(shell pkg-config --cflags --libs gstreamer-0.10)
	GST-PLAYBACK = --enable-gstreamer_01=yes
endif

ifeq ($(shell pkg-config --exists gstreamer-1.0 && echo 1),1)
	CFLAGS    += $(shell pkg-config --cflags --libs gstreamer-1.0)
	CFLAGS    += $(shell pkg-config --cflags --libs gstreamer-audio-1.0)
	CFLAGS    += $(shell pkg-config --cflags --libs gstreamer-video-1.0)
	GST-PLAYBACK = --enable-gstreamer_10=yes
endif

### workaround for debian's non-std sigc++ locations
CFLAGS += -I/usr/include/sigc++-2.0
CFLAGS += -I/usr/lib/x86_64-linux-gnu/sigc++-2.0/include

### in case some libs are installed in $(DEST) (e.g. dvbsi++ / lua / ffmpeg)
CFLAGS    += -I$(DEST)/include
CFLAGS    += -L$(DEST)/lib
CFLAGS    += -L$(DEST)/lib64

PKG_CONFIG_PATH = $(DEST)/lib/pkgconfig
export PKG_CONFIG_PATH

CXXFLAGS = $(CFLAGS)
export CFLAGS CXXFLAGS

# Prepend ccache into the PATH
PATH := $(PATH):/usr/lib/ccache/
CC    = ccache gcc
CXX   = ccache g++
export CC CXX PATH

### export our custom lib dir
#export LD_LIBRARY_PATH=$(DEST)/lib
export LUA_PATH=$(DEST)/share/lua/5.2/?.lua;;

### in case no frontend is available uncomment next 3 lines
#export SIMULATE_FE=1
#export HAL_NOAVDEC=1
#export HAL_DEBUG=0xff
export NO_SLOW_ADDEVENT=1

# wget tarballs into archive directory
WGET = wget --no-check-certificate -t6 -T20 -c -P $(ARCHIVE)

# unpack tarballs
UNTAR = tar -C $(BUILD_SRC) -xf $(ARCHIVE)

BOOTSTRAP = $(ARCHIVE) $(BUILD_SRC) $(D)

# first target is default...
default: bootstrap $(D)/libdvbsipp $(D)/ffmpeg $(D)/lua neutrino
	make run

$(ARCHIVE):
	mkdir -p $(ARCHIVE)

$(BUILD_SRC):
	mkdir -p $(BUILD_SRC)

$(D):
	mkdir -p $(D)

bootstrap: $(BOOTSTRAP)

run:
	gdb -ex run $(DEST)/bin/neutrino

run-nogdb:
	$(DEST)/bin/neutrino

run-valgrind:
	valgrind --leak-check=full --log-file="valgrind_`date +'%y.%m.%d %H:%M:%S'`.log" -v $(DEST)/bin/neutrino

$(BUILD_TMP):
	mkdir -p $(BUILD_TMP)
$(BUILD_TMP)/neutrino \
$(BUILD_TMP)/libstb-hal: | $(BUILD_TMP)
	mkdir -p $@

clean:
	-$(MAKE) -C $(N_OBJ) clean
	-$(MAKE) -C $(LH_OBJ) clean
	rm -rf $(N_OBJ) $(LH_OBJ)

distclean:
	rm -rf $(BUILD_SRC)
	rm -rf $(D)
	rm -rf $(DEST)
	rm -rf $(BUILD_TMP)

update:
	rm -rf $(LH_SRC)
	rm -rf $(LH_SRC).org
	rm -rf $(N_SRC)
	rm -rf $(N_SRC).org
	rm -rf $(BUILD_TMP)
	make default

update-s:
	rm -rf $(LH_SRC)
	rm -rf $(LH_SRC).org
	rm -rf $(N_SRC)
	rm -rf $(N_SRC).org
	rm -rf $(BUILD_TMP)
	make neutrino

copy:
	rm -rf $(LH_SRC).org
	cp -r $(LH_SRC) $(LH_SRC).org
	rm -rf $(N_SRC).org
	cp -r $(N_SRC) $(N_SRC).org

diff:
	make diff-n
	make diff-lh

diff-n:
	cd $(BUILD_SRC) && \
	diff -NEur --exclude-from=$(SCRIPTS)/diff-exclude neutrino.org neutrino > $(PWD)/neutrino.pc.diff ; [ $$? -eq 1 ]

diff-lh:
	cd $(BUILD_SRC) && \
	diff -NEur --exclude-from=$(SCRIPTS)/diff-exclude libstb-hal.org libstb-hal > $(PWD)/libstb-hal.pc.diff ; [ $$? -eq 1 ]

include make/buildenv.mk
include make/archives.mk
include make/system-libs.mk
include make/neutrino.mk
include Makefile.local

PHONY = update
.PHONY: $(PHONY)

