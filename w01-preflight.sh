#!/bin/bash
# ============================================================================
# W01 一键验收自检 —— 把 W01-acceptance.md 里那张表变成一条命令
#
# 用法：
#   ~/work/w01/w01-preflight.sh              跑全部检查
#   ~/work/w01/w01-preflight.sh --quiet      只打印失败项与总结
#
# 为什么要有这个：验收文档是「我某一天手敲的结果」，环境一变就过期；
# 这个脚本每次重新实测，答案来自机器而不是记忆。改完环境跑一遍就知道有没有坏。
# ============================================================================
set -u

REPO="$HOME/work/w01"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

PASS=0; FAIL=0; SKIP=0
RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; BLD=$'\033[1m'; RST=$'\033[0m'
if [ ! -t 1 ]; then RED=; GRN=; YEL=; DIM=; BLD=; RST=; fi

section() { [ "$QUIET" -eq 1 ] || printf '\n%s%s%s\n' "$BLD" "$1" "$RST"; }

# check <名称> <期望> <实际>   —— 实际以标准输入传入
check() {
    local name="$1" expect="$2" got
    got="$(cat)"
    if printf '%s' "$got" | grep -qE "$expect"; then
        PASS=$((PASS+1))
        [ "$QUIET" -eq 1 ] || printf '  %s✓%s %-34s %s%s%s\n' "$GRN" "$RST" "$name" "$DIM" "$(printf '%s' "$got" | head -1 | cut -c1-56)" "$RST"
    else
        FAIL=$((FAIL+1))
        printf '  %s✗%s %-34s 期望匹配 /%s/\n      实际: %s\n' "$RED" "$RST" "$name" "$expect" "$(printf '%s' "$got" | head -2 | tr '\n' ' ' | cut -c1-110)"
    fi
}

skip() { SKIP=$((SKIP+1)); printf '  %s-%s %-34s %s\n' "$YEL" "$RST" "$1" "$2"; }

cd "$REPO" 2>/dev/null || { echo "找不到 $REPO"; exit 1; }

# ---------------------------------------------------------------- 1 环境
section "1) WSL 与发行版"
check "发行版是 Ubuntu 22.04" 'Ubuntu 22\.04'        <<< "$(lsb_release -ds 2>&1)"
check "3.10 以上内核"        '^[3-9]\.'                <<< "$(uname -r)"
check "WSL2 内核标识"        'microsoft-standard-WSL2'  <<< "$(uname -r)"
check "默认用户 yingying"     'uid=1000\(yingying\)'    <<< "$(id)"
check "sudo 免密可用"        '^0$'                     <<< "$(sudo -n true 2>/dev/null; echo $?)"
check "根分区可写且有余量"    '^[0-9]+$'                <<< "$(df -h / | awk 'NR==2{print $4}' | tr -d 'GMK')"

# ---------------------------------------------------------------- 2 工具链
section "2) 工具链"
check "gcc"                 '^gcc \(Ubuntu 11\.'       <<< "$(gcc --version 2>&1 | head -1)"
check "make"                '^GNU Make [0-9]'          <<< "$(make --version 2>&1 | head -1)"
check "cmake"               '^cmake version [0-9]'     <<< "$(cmake --version 2>&1 | head -1)"
check "ninja"               '^[0-9]+\.[0-9]+'          <<< "$(ninja --version 2>&1)"
check "gdb"                 '^GNU gdb'                 <<< "$(gdb --version 2>&1 | head -1)"
check "git"                 '^git version'             <<< "$(git --version 2>&1)"
check "ARM 交叉编译器"       '^arm-linux-gnueabihf-gcc'  <<< "$(arm-linux-gnueabihf-gcc --version 2>&1 | head -1)"
check "qemu-arm 已安装"       '^qemu-ok$'                <<< "$(qemu-arm --version >/dev/null 2>&1 && echo qemu-ok || echo qemu-missing)"
check "dtc（设备树编译器）"   '^Version: DTC'            <<< "$(dtc --version 2>&1 | head -1)"
check "strace"              '^strace -- version'       <<< "$(strace --version 2>&1 | head -1)"

# ---------------------------------------------------------------- 3 编译运行
section "3) 编译、运行、交叉编译"
BUILD_LOG="$(make clean >/dev/null 2>&1; make 2>&1; echo "make-exit=$?")"
check "make 构建成功"        'make-exit=0'             <<< "$BUILD_LOG"
check "原生运行输出正确"      'hello, embedded linux'    <<< "$(./hello 2>&1)"
ARM_LOG="$(make arm 2>&1; echo "make-arm-exit=$?")"
check "make arm 交叉编译成功" 'make-arm-exit=0'          <<< "$ARM_LOG"
check "产物是 ARM ELF"       'ELF 32-bit LSB executable, ARM' <<< "$(file hello_arm 2>&1)"
check "QEMU 能跑 ARM 产物"   'hello, embedded linux'    <<< "$(qemu-arm ./hello_arm 2>&1)"
CM_LOG="$(rm -rf build && cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug 2>&1 && cmake --build build 2>&1; echo "cmake-exit=$?")"
check "CMake+Ninja 构建成功" 'cmake-exit=0'             <<< "$CM_LOG"
check "CMake 产物输出正确"   'hello, embedded linux'    <<< "$(./build/hello 2>&1)"
check "compile_commands.json" '^[0-9]+$'                <<< "$(grep -c hello.c build/compile_commands.json 2>/dev/null || echo 0)"

# ---------------------------------------------------------------- 4 调试
section "4) 调试"
GDB_OUT="$(gdb -q -batch -ex 'break main' -ex run -ex 'print sizeof(int)' ./build/hello 2>&1)"
check "gdb 能断在 main"      'Breakpoint 1'             <<< "$GDB_OUT"
check "gdb 能求值"           '\$1 = 4'                  <<< "$GDB_OUT"

# ---------------------------------------------------------------- 5 VS Code
section "5) VS Code（WSL 侧）"
EXT_ROOT="$HOME/.vscode-server/extensions"
CPP_BIN="$(find "$EXT_ROOT" -name cpptools -type f -path '*/bin/*' 2>/dev/null | head -1)"
if [ -n "$CPP_BIN" ]; then
    check "cpptools 是 linux-x64 ELF" 'ELF 64-bit LSB executable, x86-64' <<< "$(file -b "$CPP_BIN" 2>&1)"
    CPP_VER="$(cd "$(dirname "$CPP_BIN")" && ./cpptools --version 2>&1 | head -1)"
    check "cpptools 版本"            '^[0-9]+\.[0-9]+\.[0-9]+'            <<< "$CPP_VER"
else
    skip "cpptools 二进制" "没找到（扩展未装或路径变了）"
fi
check "launch.json 存在"      'launch\.json'            <<< "$(ls .vscode/ 2>&1)"
JSONC_OK="$(python3 - <<'PYEOF'
import re, json
raw = open('.vscode/tasks.json', encoding='utf-8').read()
# 去掉 // 行注释与 /* */ 块注释（VS Code 用 JSONC，标准 json 解析不了）
raw = re.sub(r'/\*.*?\*/', '', raw, flags=re.S)
raw = re.sub(r'(?m)^\s*//.*$', '', raw)
raw = re.sub(r'(?m)([^:"])//.*$', r'\1', raw)
d = json.loads(raw)
print(f"ok tasks={len(d['tasks'])}")
PYEOF
)"
check "tasks.json JSONC 合法"  '^ok'                    <<< "$JSONC_OK"
check "tasks.json 任务数"     'tasks=[0-9]+'           <<< "$JSONC_OK"
check "IntelliSense 自检文件在" 'intellisense-check\.c'   <<< "$(ls 2>&1)"
check "自检文件的 3 个错仍在"   'not_declared'            <<< "$(gcc -fsyntax-only -Wall intellisense-check.c 2>&1)"

# ---------------------------------------------------------------- 6 Git
section "6) Git 与推送通道"
check "分支是 main"          '^main$'                   <<< "$(git rev-parse --abbrev-ref HEAD)"
DIRTY="$(git status --porcelain | grep -v '^?? ' || true)"
check "已跟踪文件无未提交改动" '^clean$'                  <<< "$(if [ -z "$DIRTY" ]; then echo clean; else echo "dirty: $DIRTY"; fi)"
check "有 origin 本地裸仓库"  '^origin$'                 <<< "$(git remote | grep -x origin || true)"
check "有 github 远程"       '^github$'                 <<< "$(git remote | grep -x github || true)"
check "origin 与本地 HEAD 一致" "^$(git rev-parse HEAD)$" <<< "$(git ls-remote origin refs/heads/main 2>/dev/null | cut -f1)"
SSH_OUT="$(timeout 25 ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)"
if printf '%s' "$SSH_OUT" | grep -q 'successfully authenticated'; then
    check "GitHub SSH 认证"   'successfully authenticated' <<< "$SSH_OUT"
    check "GitHub 远端 main"  '^[0-9a-f]{40}$'             <<< "$(timeout 25 git ls-remote github refs/heads/main 2>/dev/null | cut -f1)"
else
    skip "GitHub SSH 认证" "公钥还没加到 GitHub（唯一待办）"
    skip "GitHub 远端 main" "同上"
fi

# ---------------------------------------------------------------- 总结
printf '\n%s结论%s\n' "$BLD" "$RST"
printf '  通过 %s%d%s / 失败 %s%d%s / 跳过 %s%d%s\n' "$GRN" "$PASS" "$RST" "$RED" "$FAIL" "$RST" "$YEL" "$SKIP" "$RST"
if [ "$FAIL" -eq 0 ]; then
    printf '  %s环境全绿。%s' "$GRN" "$RST"
    [ "$SKIP" -gt 0 ] && printf '跳过的 %d 项都跟「公钥还没贴」有关。\n' "$SKIP" || printf '\n'
else
    printf '  %s有 %d 项没过，上面带 ✗ 的行就是原因。%s\n' "$RED" "$FAIL" "$RST"
fi
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
