# CoreFreq
# Copyright (C) 2015-2025 CYRIL COURTIAT
# Licenses: GPL2

COREFREQ_MAJOR = 2
COREFREQ_MINOR = 0
COREFREQ_REV = 8
HW = $(shell uname -m)
CC ?= cc
WARNING ?= -Wall -Wfatal-errors
SYMLINK ?= ln -s
INSTALL ?= install
DEPMOD ?= depmod
MKDIR ?= mkdir
RMDIR ?= rmdir
RM ?= rm -f
PWD ?= $(shell pwd)
BUILD ?= build
KERNELREL ?= /lib/modules/$(shell uname -r)
KERNELDIR ?= $(KERNELREL)/build
PREFIX ?= /usr
UBENCH = 0
CORE_COUNT ?= 256
TASK_ORDER = 5
MAX_FREQ_HZ ?= 7125000000
MSR_CORE_PERF_UCC ?= MSR_IA32_APERF
MSR_CORE_PERF_URC ?= MSR_IA32_MPERF
ifeq ($(HW), x86_64)
DELAY_TSC ?= 1
else
DELAY_TSC = 0
endif
ARCH_PMC ?=

SILENT = 0
ifneq ($(findstring s,$(firstword -$(MAKEFLAGS))),)
	SILENT = 1
else
	ifneq ($(V),)
		SYMLINK += -v
		MKDIR += -v
		RMDIR += -v
		RM += -v
	endif
endif

obj-m := corefreqk.o
corefreqk-y := module/corefreqk.o

ccflags-y := -I$(PWD)/$(HW)
ccflags-y +=	-D COREFREQ_MAJOR=$(COREFREQ_MAJOR) \
		-D COREFREQ_MINOR=$(COREFREQ_MINOR) \
		-D COREFREQ_REV=$(COREFREQ_REV) \
		-D CORE_COUNT=$(CORE_COUNT) \
		-D TASK_ORDER=$(TASK_ORDER) \
		-D MAX_FREQ_HZ=$(MAX_FREQ_HZ)
ccflags-y += $(WARNING)

ifeq ($(OPTIM_LVL),0)
OPTIM_FLG = -O$(OPTIM_LVL)
ccflags-y += -fno-inline
else ifneq ($(OPTIM_LVL),)
OPTIM_FLG = -O$(OPTIM_LVL)
ccflags-y += -D OPTIM_LVL=$(OPTIM_LVL)
ccflags-y += $(OPTIM_FLG)
endif

DEFINITIONS =	-D COREFREQ_MAJOR=$(COREFREQ_MAJOR) \
		-D COREFREQ_MINOR=$(COREFREQ_MINOR) \
		-D COREFREQ_REV=$(COREFREQ_REV) \
		-D CORE_COUNT=$(CORE_COUNT) -D TASK_ORDER=$(TASK_ORDER) \
		-D MAX_FREQ_HZ=$(MAX_FREQ_HZ) -D UBENCH=$(UBENCH)

ifneq ($(FEAT_DBG),)
DEFINITIONS += -D FEAT_DBG=$(FEAT_DBG)
ccflags-y += -D FEAT_DBG=$(FEAT_DBG)
endif

ifneq ($(LEGACY),)
DEFINITIONS += -D LEGACY=$(LEGACY)
ccflags-y += -D LEGACY=$(LEGACY)
endif

ifneq ($(DELAY_TSC),)
DEFINITIONS += -D DELAY_TSC=$(DELAY_TSC)
ccflags-y += -D DELAY_TSC=$(DELAY_TSC)
endif

ifneq ($(ARCH_PMC),)
DEFINITIONS += -D ARCH_PMC=$(ARCH_PMC)
ccflags-y += -D ARCH_PMC=$(ARCH_PMC)
endif

ccflags-y += -D MSR_CORE_PERF_UCC=$(MSR_CORE_PERF_UCC)
ccflags-y += -D MSR_CORE_PERF_URC=$(MSR_CORE_PERF_URC)

ifneq ($(HWM_CHIPSET),)
ccflags-y += -D HWM_CHIPSET=$(HWM_CHIPSET)
endif

ccflags-y += -D DT_VIRTUAL_BOARD='{	\
	"linux,dummy-virt",		\
	"riscv-virtio", 		\
	"qemu,pseries",			\
	NULL				\
}'

ifneq ($(NO_HEADER),)
LAYOUT += -D NO_HEADER=$(NO_HEADER)
endif

ifneq ($(NO_FOOTER),)
LAYOUT += -D NO_FOOTER=$(NO_FOOTER)
endif

ifneq ($(NO_UPPER),)
LAYOUT += -D NO_UPPER=$(NO_UPPER)
endif

ifneq ($(NO_LOWER),)
LAYOUT += -D NO_LOWER=$(NO_LOWER)
endif

ifneq ($(UI_TRANSPARENCY),)
LAYOUT += -D UI_TRANSPARENCY=$(UI_TRANSPARENCY)
endif

ifneq ($(UI_RULER_MINIMUM),)
LAYOUT += -D UI_RULER_MINIMUM=$(UI_RULER_MINIMUM)
endif

ifneq ($(UI_RULER_MAXIMUM),)
LAYOUT += -D UI_RULER_MAXIMUM=$(UI_RULER_MAXIMUM)
endif

ifneq ($(filter clean,$(MAKECMDGOALS)),)
ifneq ($(words $(MAKECMDGOALS)),1)
$(error Target 'clean' must be run alone: See 'make help')
endif
endif

ifneq ($(filter $(BUILD)/.prepare-stamp,$(MAKECMDGOALS)),)
$(error Target '$(BUILD)/.prepare-stamp' is internal. See 'make help')
endif

.PHONY: all
all: $(BUILD)/.prepare-stamp corefreqd corefreq-cli corefreqk.ko | $(BUILD)/.prepare-stamp

$(BUILD)/.prepare-stamp:
	@if [ ! -d $(BUILD) ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  MD [$(BUILD)]"; \
		fi; \
		$(MKDIR) -m +t $(BUILD); \
	fi; \
	if [ ! -d $(BUILD)/module ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  MD [$(BUILD)/module]"; \
		fi; \
		$(MKDIR) $(BUILD)/module; \
	fi; \
	if [ ! -e $(BUILD)/Makefile ]; then \
		cd $(BUILD); \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  LN [$(BUILD)/Makefile]"; \
		fi; \
		$(SYMLINK) ../Makefile Makefile; \
		cd ..; \
	fi; \
	if [ ! -e $(BUILD)/module/corefreqk.c ]; then \
		cd $(BUILD)/module; \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  LN [$(BUILD)/module/corefreqk.c]"; \
		fi; \
		$(SYMLINK) ../../$(HW)/corefreqk.c corefreqk.c; \
		cd ../..; \
	fi; \
	touch $@

$(BUILD)/corefreqk.ko: $(BUILD)/.prepare-stamp
	@if [ -e $(BUILD)/Makefile ]; then \
	    if [ -z ${V} ]; then \
		$(MAKE) --no-print-directory -C $(KERNELDIR) \
			M=$(PWD)/$(BUILD) modules; \
	    else \
		$(MAKE) -C $(KERNELDIR) M=$(PWD)/$(BUILD) modules; \
	    fi \
	fi

.PHONY: corefreqk.ko
corefreqk.ko: $(BUILD)/corefreqk.ko

.PHONY: uninstall
uninstall:
	@if [ -e $(PREFIX)/bin/corefreq-cli ]; then \
		$(RM) $(PREFIX)/bin/corefreq-cli; \
	fi
	@if [ -e $(PREFIX)/bin/corefreqd ]; then \
		$(RM) $(PREFIX)/bin/corefreqd; \
	fi
	@if [ -e $(PREFIX)/lib/systemd/system/corefreqd.service ]; then \
		$(RM) $(PREFIX)/lib/systemd/system/corefreqd.service; \
	fi
	@MCNT=0; \
	for MDIR in updates extra ; do \
	    if [ -d $(KERNELREL)/$${MDIR} ]; then \
		for MEXT in ko ko.gz ko.xz ko.zst ; do \
			MFILE=$(KERNELREL)/$${MDIR}/corefreqk.$${MEXT}; \
			if [ -e $${MFILE} ]; then \
				$(RM) $${MFILE}; \
				if [ $$? -eq 0 ]; then \
					MCNT=$$((MCNT + 1)); \
				fi \
			fi \
		done \
	    fi \
	done; \
	if [ $${MCNT} -ge 1 ]; then \
		$(DEPMOD) -a; \
	fi

.PHONY: install
install: module-install
	@if [ -e $(BUILD)/corefreq-cli ]; then \
		$(INSTALL) -m 0755 $(BUILD)/corefreq-cli $(PREFIX)/bin; \
	fi
	@if [ -e $(BUILD)/corefreqd ]; then \
		$(INSTALL) -m 0755 $(BUILD)/corefreqd $(PREFIX)/bin; \
	fi
	@if [ -d $(PREFIX)/lib/systemd/system ]; then \
		$(INSTALL) -m 0644 corefreqd.service \
			$(PREFIX)/lib/systemd/system; \
	fi

.PHONY: module-install
module-install:
	@if [ -e $(BUILD)/corefreqk.ko ]; then \
		$(MAKE) -C $(KERNELDIR) M=$(PWD)/$(BUILD) modules_install; \
	fi

.PHONY: clean
clean:
	@if [ -e $(BUILD)/Makefile ]; then \
	    if [ -z ${V} ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  RM [M] $(PWD)/$(BUILD)"; \
		fi; \
		$(MAKE) -s -C $(KERNELDIR) M=$(PWD)/$(BUILD) clean; \
	    else \
		$(MAKE) -C $(KERNELDIR) M=$(PWD)/$(BUILD) clean; \
	    fi \
	fi; \
	if [ -e $(BUILD)/corefreqd ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  RM [$(BUILD)/corefreqd]"; \
		fi; \
		$(RM) $(BUILD)/corefreqd; \
	fi; \
	if [ -e $(BUILD)/corefreq-cli ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  RM [$(BUILD)/corefreq-cli]"; \
		fi; \
		$(RM) $(BUILD)/corefreq-cli; \
	fi; \
	if [ -e $(BUILD)/module/corefreqk.c ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  RM [$(BUILD)/module/corefreqk.c]"; \
		fi; \
		$(RM) $(BUILD)/module/corefreqk.c; \
	fi; \
	if [ -e $(BUILD)/Makefile ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  RM [$(BUILD)/Makefile]"; \
		fi; \
		$(RM) $(BUILD)/Makefile; \
	fi; \
	if [ -d $(BUILD)/module ]; then \
		if [ ${SILENT} -eq 0 ]; then \
			echo "  RD [$(BUILD)/module]"; \
		fi; \
		$(RMDIR) $(BUILD)/module; \
	fi; \
	if [ -d $(BUILD) ] && [ -z "$(ls -A $(BUILD))" ]; then \
		$(RM) $(BUILD)/.prepare-stamp; \
		if [ ${SILENT} -eq 0 ]; then echo "  RD [$(BUILD)]"; fi; \
		$(RMDIR) $(BUILD); \
	fi

$(BUILD)/corefreqm.o: $(HW)/corefreqm.c
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  CC [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) $(WARNING) -pthread $(DEFINITIONS) \
	  -c $(HW)/corefreqm.c -o $(BUILD)/corefreqm.o

$(BUILD)/corefreqd.o: $(HW)/corefreqd.c
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  CC [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) $(WARNING) -pthread $(DEFINITIONS) \
	  -c $(HW)/corefreqd.c -o $(BUILD)/corefreqd.o

$(BUILD)/corefreqd: $(BUILD)/.prepare-stamp $(BUILD)/corefreqd.o $(BUILD)/corefreqm.o
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  LD [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) -o $(BUILD)/corefreqd \
	  $(BUILD)/corefreqd.o $(BUILD)/corefreqm.o -lpthread -lm -lrt -lc

.PHONY: corefreqd
corefreqd: $(BUILD)/corefreqd

$(BUILD)/corefreq-ui.o: $(HW)/corefreq-ui.c
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  CC [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) $(WARNING) $(DEFINITIONS) \
	  -c $(HW)/corefreq-ui.c -o $(BUILD)/corefreq-ui.o

$(BUILD)/corefreq-cli.o: $(HW)/corefreq-cli.c
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  CC [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) $(WARNING) $(DEFINITIONS) $(LAYOUT) \
	  -c $(HW)/corefreq-cli.c -o $(BUILD)/corefreq-cli.o

$(BUILD)/corefreq-cli-rsc.o: $(HW)/corefreq-cli-rsc.c
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  CC [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) $(WARNING) $(DEFINITIONS) $(LAYOUT) \
	  -c $(HW)/corefreq-cli-rsc.c -o $(BUILD)/corefreq-cli-rsc.o

$(BUILD)/corefreq-cli-json.o: $(HW)/corefreq-cli-json.c
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  CC [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) $(WARNING) $(DEFINITIONS) \
	  -c $(HW)/corefreq-cli-json.c -o $(BUILD)/corefreq-cli-json.o

$(BUILD)/corefreq-cli-extra.o: $(HW)/corefreq-cli-extra.c
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  CC [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) $(WARNING) $(DEFINITIONS) \
	  -c $(HW)/corefreq-cli-extra.c -o $(BUILD)/corefreq-cli-extra.o

$(BUILD)/corefreq-cli:	$(BUILD)/.prepare-stamp \
			$(BUILD)/corefreq-cli.o \
			$(BUILD)/corefreq-ui.o \
			$(BUILD)/corefreq-cli-rsc.o \
			$(BUILD)/corefreq-cli-json.o \
			$(BUILD)/corefreq-cli-extra.o
	$(if $(V), $(CC), @if [ ${SILENT} -eq 0 ]; then echo "  LD [$@]"; fi; \
	$(CC)) $(OPTIM_FLG) -o $(BUILD)/corefreq-cli \
	  $(BUILD)/corefreq-cli.o $(BUILD)/corefreq-ui.o \
	  $(BUILD)/corefreq-cli-rsc.o $(BUILD)/corefreq-cli-json.o \
	  $(BUILD)/corefreq-cli-extra.o -lm -lrt -lc

.PHONY: corefreq-cli
corefreq-cli: $(BUILD)/corefreq-cli

.PHONY: info
info:
	$(info HW [$(HW)])
	$(info CC [$(shell whereis -b $(CC))])
	$(info WARNING [$(WARNING)])
	$(info PWD [$(PWD)])
	$(info BUILD [$(BUILD)])
	$(info KERNELDIR [$(KERNELDIR)])
	$(info PREFIX [$(PREFIX)])
	$(info LEGACY [$(LEGACY)])
	$(info UBENCH [$(UBENCH)])
	$(info FEAT_DBG [$(FEAT_DBG)])
	$(info DELAY_TSC [$(DELAY_TSC)])
	$(info OPTIM_LVL [$(OPTIM_LVL)])
	$(info CORE_COUNT [$(CORE_COUNT)])
	$(info TASK_ORDER [$(TASK_ORDER)])
	$(info MAX_FREQ_HZ [$(MAX_FREQ_HZ)])
	$(info HWM_CHIPSET [$(HWM_CHIPSET)])
	$(info MSR_CORE_PERF_UCC [$(MSR_CORE_PERF_UCC)])
	$(info MSR_CORE_PERF_URC [$(MSR_CORE_PERF_URC)])
	$(info ARCH_PMC [$(ARCH_PMC)])
	$(info NO_HEADER [$(NO_HEADER)])
	$(info NO_FOOTER [$(NO_FOOTER)])
	$(info NO_UPPER [$(NO_UPPER)])
	$(info NO_LOWER [$(NO_LOWER)])
	$(info SILENT [$(SILENT)])
	@:

.PHONY: version
version:
	$(info $(COREFREQ_MAJOR).$(COREFREQ_MINOR).$(COREFREQ_REV))
	@:

.PHONY: help
help:
	@echo -e \
	"o---------------------------------------------------------------o\n"\
	"|  make [corefreqd] [corefreq-cli] [corefreqk.ko] [all]         |\n"\
	"|  make [install] [module-install] [uninstall]                  |\n"\
	"|  make [info] [help] [version]                                 |\n"\
	"|  make [clean]                                                 |\n"\
	"|                                                               |\n"\
	"|  Options:                                                     |\n"\
	"|     -j [N], --jobs[=N]                                        |\n"\
	"|     -s, --silent, --quiet                                     |\n"\
	"|                                                               |\n"\
	"|  V=<n>                                                        |\n"\
	"|    where <n> is the verbose build level                       |\n"\
	"|                                                               |\n"\
	"|  CC=<COMPILER>                                                |\n"\
	"|    where <COMPILER> is cc, gcc, clang                         |\n"\
	"|                                                               |\n"\
	"|  WARNING=<ARG>                                                |\n"\
	"|    where default argument is -Wall -Wfatal-errors             |\n"\
	"|                                                               |\n"\
	"|  KERNELDIR=<PATH>                                             |\n"\
	"|    where <PATH> is the Kernel source directory                |\n"\
	"|                                                               |\n"\
	"|  CORE_COUNT=<N>                                               |\n"\
	"|    where <N> is 64, 128, 256, 512 or 1024 builtin CPU         |\n"\
	"|                                                               |\n"\
	"|  LEGACY=<L>                                                   |\n"\
	"|    where level <L>                                            |\n"\
	"|    1: assembly level restriction such as CMPXCHG16            |\n"\
	"|                                                               |\n"\
	"|  UBENCH=<N>                                                   |\n"\
	"|    where <N> is 0 to disable or 1 to enable micro-benchmark   |\n"\
	"|                                                               |\n"\
	"|  TASK_ORDER=<N>                                               |\n"\
	"|    where <N> is the memory page unit of kernel allocation     |\n"\
	"|                                                               |\n"\
	"|  FEAT_DBG=<N>                                                 |\n"\
	"|    where <N> is 0 or N for FEATURE DEBUG level                |\n"\
	"|    3: XMM assembly in RING operations                         |\n"\
	"|                                                               |\n"\
	"|  DELAY_TSC=<N>                                                |\n"\
	"|    where <N> is 1 to build a TSC implementation of udelay()   |\n"\
	"|                                                               |\n"\
	"|  OPTIM_LVL=<N>                                                |\n"\
	"|    where <N> is 0, 1, 2 or 3 of the OPTIMIZATION level        |\n"\
	"|                                                               |\n"\
	"|  MAX_FREQ_HZ=<freq>                                           |\n"\
	"|    where <freq> is at least 4850000000 Hz                     |\n"\
	"|                                                               |\n"\
	"|  HWM_CHIPSET=<chipset>                                        |\n"\
	"|    where <chipset> is W83627; IT8720; AMD_VCO or COMPATIBLE   |\n"\
	"|                                                               |\n"\
	"|  Performance Counters:                                        |\n"\
	"|    -------------------------------------------------------    |\n"\
	"|   |     MSR_CORE_PERF_UCC     |     MSR_CORE_PERF_URC     |   |\n"\
	"|   |----------- REG -----------|----------- REG -----------|   |\n"\
	"|   | MSR_IA32_APERF            |  MSR_IA32_MPERF           |   |\n"\
	"|   | MSR_CORE_PERF_FIXED_CTR1  |  MSR_CORE_PERF_FIXED_CTR2 |   |\n"\
	"|   | MSR_PPERF                 |  MSR_PPERF                |   |\n"\
	"|   |                           |  MSR_ANY_CORE_C0          |   |\n"\
	"|   | MSR_AMD_F17H_APERF        |  MSR_AMD_F17H_MPERF       |   |\n"\
	"|    -------------------------------------------------------    |\n"\
	"|                                                               |\n"\
	"|  Architectural Counters:                                      |\n"\
	"|    -------------------------------------------------------    |\n"\
	"|   |           Intel           |            AMD            |   |\n"\
	"|   |----------- REG -----------|----------- REG -----------|   |\n"\
	"|   |       ARCH_PMC=PCU        |      ARCH_PMC=L3          |   |\n"\
	"|   |                           |      ARCH_PMC=PERF        |   |\n"\
	"|   |                           |      ARCH_PMC=UMC         |   |\n"\
	"|    -------------------------------------------------------    |\n"\
	"|                                                               |\n"\
	"|  User Interface Layout:                                       |\n"\
	"|    NO_HEADER=<F>  NO_FOOTER=<F>  NO_UPPER=<F>  NO_LOWER=<F>   |\n"\
	"|      when <F> is 1: don't build and display this area part    |\n"\
	"|    UI_TRANSPARENCY=<F>                                        |\n"\
	"|      when <F> is 1: build with background transparency        |\n"\
	"|    UI_RULER_MINIMUM=<N>, UI_RULER_MAXIMUM=<N>                 |\n"\
	"|      set ruler left or right bound to <N> frequency ratio     |\n"\
	"|                                                               |\n"\
	"|  Example:                                                     |\n"\
	"|    make CC=gcc OPTIM_LVL=3 FEAT_DBG=1 ARCH_PMC=PCU \\          |\n"\
	"|         MSR_CORE_PERF_UCC=MSR_CORE_PERF_FIXED_CTR1 \\          |\n"\
	"|         MSR_CORE_PERF_URC=MSR_CORE_PERF_FIXED_CTR2 \\          |\n"\
	"|         HWM_CHIPSET=W83627 MAX_FREQ_HZ=5350000000  \\          |\n"\
	"|         CORE_COUNT=1024 NO_FOOTER=1 NO_UPPER=1                |\n"\
	"o---------------------------------------------------------------o"
