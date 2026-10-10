# W01 Makefile —— 演示「同一份源码，两个目标平台」
#
#   make            编译出 x86 原生版 hello
#   make run        编译并运行原生版
#   make arm        交叉编译出 ARM 版 hello_arm
#   make qemu       在 QEMU 里跑 ARM 版
#   make arm-all    交叉编译 + QEMU 跑 + 打印文件信息
#   make clean      清理产物
#
# 这两条规则就是嵌入式开发最核心的循环：
#   写源码 → 用交叉工具链编译 → 在目标环境（开发板/QEMU）执行

CC      := gcc
CROSS   := arm-linux-gnueabihf-gcc
CFLAGS  := -Wall -Wextra -g -O0
SRC     := hello.c
BIN     := hello
BIN_ARM := hello_arm

.PHONY: all run arm qemu arm-all clean

all: $(BIN)

$(BIN): $(SRC)
	$(CC) $(CFLAGS) $< -o $@
	@echo "→ 已生成原生可执行文件: $@"

run: $(BIN)
	./$(BIN)

# -static：宿主机没有 ARM 版动态库，静态链接才能直接扔进 QEMU
arm: $(SRC)
	$(CROSS) $(CFLAGS) -static $< -o $(BIN_ARM)
	@echo "→ 已生成 ARM 可执行文件: $(BIN_ARM)"
	@file $(BIN_ARM)

qemu: $(BIN_ARM)
	qemu-arm ./$(BIN_ARM)

arm-all: arm qemu
	@echo "--- 文件信息 ---"
	@file $(BIN_ARM)
	@echo "--- 段表 ---"
	@arm-linux-gnueabihf-readelf -h $(BIN_ARM) | head -20

clean:
	rm -f $(BIN) $(BIN_ARM)
	@echo "→ 已清理"
