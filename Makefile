#--------------------------------------------------------------------
# Build tools
#--------------------------------------------------------------------

RISCV_PREFIX=riscv64-unknown-elf-
CC = $(RISCV_PREFIX)gcc
LD = $(RISCV_PREFIX)ld
RISCV_COPY = $(RISCV_PREFIX)objcopy
RISCV_DUMP = $(RISCV_PREFIX)objdump
RISCV_COPY_FLAGS = --set-section-flags .bss=alloc,contents --set-section-flags .sbss=alloc,contents -O binary

#--------------------------------------------------------------------
# BBL variables
#--------------------------------------------------------------------

BBL_REPO_PATH = $(abspath .)
BBL_BUILD_PATH = ./build
BBL_BUILD_MAKEFILE = $(BBL_BUILD_PATH)/Makefile
BBL_ELF_BUILD = $(BBL_BUILD_PATH)/bbl
BBL_BIN = $(BBL_BUILD_PATH)/bbl.bin

BBL_PAYLOAD = $(LINUX_ELF)
#BBL_PAYLOAD = dummy_payload
BBL_CONFIG = --host=riscv64-unknown-elf --with-payload=$(BBL_PAYLOAD) \
						 --with-arch=rv64imac --enable-logo #--enable-print-device-tree

DTB = $(BBL_BUILD_PATH)/system.dtb
DTS = dts/system.dts

ifeq ($(MAKECMDGOALS),qemu)
BBL_ENV = CFLAGS=-D__QEMU__
endif

#--------------------------------------------------------------------
# Linux variables
#--------------------------------------------------------------------

LINUX_REPO_PATH = $(abspath ../riscv-linux)
LINUX_ELF = $(LINUX_REPO_PATH)/vmlinux

ROOTFS_PATH = $(abspath ../riscv-rootfs)
RFS_ENV = RISCV_ROOTFS_HOME=$(ROOTFS_PATH)

#--------------------------------------------------------------------
# BBL rules
#--------------------------------------------------------------------

bbl: $(BBL_BIN)

$(BBL_BIN): $(BBL_ELF_BUILD)
	$(RISCV_COPY) $(RISCV_COPY_FLAGS) $< $@
	$(RISCV_DUMP) -d $< > $<.txt

$(BBL_BUILD_MAKEFILE):
	mkdir -p $(@D)
	cd $(@D) && $(BBL_REPO_PATH)/configure $(BBL_CONFIG)

$(DTB): $(DTS)
	mkdir -p $(@D)
	dtc -O dtb -I dts -o $@ $<

dummy_payload:

$(BBL_ELF_BUILD): $(BBL_PAYLOAD) $(DTB) $(BBL_BUILD_MAKEFILE)
	$(BBL_ENV) $(MAKE) -C $(BBL_BUILD_PATH)

bbl-clean:
	-rm -rf build

.PHONY: bbl bbl-clean dummy_payload $(BBL_ELF_BUILD)

#--------------------------------------------------------------------
# Linux rules
#--------------------------------------------------------------------

$(LINUX_REPO_PATH):
	mkdir -p $@
	@/bin/echo -e "\033[1;31mBy default, a shallow clone with only 1 commit history is performed, since the commit history is very large.\nThis is enough for building the project.\nTo fetch full history, run 'git fetch --unshallow' under $(LINUX_REPO_PATH).\033[0m"
	git clone --depth 1 -b nanshan https://github.com/OpenXiangShan/riscv-linux.git $@
	$(RFS_ENV) $(MAKE) -C $@ ARCH=riscv emu_defconfig

$(ROOTFS_PATH):
	mkdir -p $@
	git clone https://github.com/LvNA-system/riscv-rootfs.git $@

linux: $(LINUX_ELF)

$(LINUX_ELF): | $(LINUX_REPO_PATH) $(ROOTFS_PATH)
	$(RFS_ENV) $(MAKE) -C $(ROOTFS_PATH)
	$(RFS_ENV) $(MAKE) -C $(@D) CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv vmlinux
	$(RISCV_DUMP) -d $(LINUX_ELF) > $(BBL_BUILD_PATH)/vmlinux.txt

linux-clean:
	-rm $(LINUX_ELF)
	-$(RFS_ENV) $(MAKE) clean -C $(LINUX_REPO_PATH)

.PHONY: linux linux-clean $(LINUX_ELF)


#--------------------------------------------------------------------
# Top-level rules
#--------------------------------------------------------------------

default: bbl

nemu: bbl
	$(MAKE) -C $(NEMU_HOME) ISA=riscv64 run ARGS="-b $(abspath $(BBL_BIN))"

nutshell: bbl
	$(MAKE) -C $(NUTSHELL_HOME) emu IMAGE="$(abspath $(BBL_BIN))"

qemu: bbl
	qemu-system-riscv64 -nographic -kernel $(BBL_ELF_BUILD) -machine virt

clean: bbl-clean #linux-clean
#	-$(RFS_ENV) $(MAKE) -C $(ROOTFS_PATH) clean

.PHONY: default run clean
