# W01 · 环境搭建与第一次接触

**阶段**：①基础　**周期**：2026-10-12 ~ 2026-10-18　**预计工时**：10 小时

这个仓库是我 24 周嵌入式 Linux 路线的起点，用来做 W01 的交付验收：
WSL2 + Ubuntu 22.04 环境、VS Code Remote-WSL、以及第一个能编译、能跑、
能交叉编译到 ARM 的程序。

## 这周做完的事

- [x] 启用 WSL2 与虚拟机平台（管理员 + 重启）
- [x] 用国内镜像导入 Ubuntu 22.04（绕过微软商店，325.3 MB 约 1 分钟）
- [x] apt 换上海交大源，装齐 GCC/CMake/Ninja/GDB/QEMU/dtc 等工具链
- [x] VS Code + Remote-WSL 连上 `~/work`
- [x] 配置 11 个任务与 2 个调试配置（Ctrl+Shift+B / F5 直接用）
- [x] 第一个程序：原生编译 + 交叉编译到 ARM + QEMU 里跑起来

## 验收命令

```bash
# 1. 原生编译并运行
gcc -Wall -Wextra -g -O0 hello.c -o hello && ./hello
# 期望输出：hello, embedded linux

# 2. 交叉编译到 ARM（32 位）
arm-linux-gnueabihf-gcc -Wall -g -O0 -static hello.c -o hello_arm
file hello_arm
# 期望：ELF 32-bit LSB executable, ARM, EABI5 ... statically linked

# 3. 用 QEMU 模拟 ARM CPU 跑它
qemu-arm ./hello_arm
# 期望输出：hello, embedded linux
```

## 本周的关键收获（写给自己，也是面试素材）

**为什么要 `-static`**：宿主机上没有 ARM 版的 libc 动态库，静态链接把 libc
打进可执行文件，QEMU 里才能直接跑。等以后有开发板，这一步换成动态链接 +
把库拷进 rootfs。

**为什么要 `-g -O0`**：`-g` 才有调试信息（否则断点只能设在汇编上、看不到
变量名）；`-O0` 关优化，否则变量会被优化掉、单步会跳行，学习阶段极易困惑。

**交叉编译的意义**：x86 电脑上写代码 → 编译成 ARM 指令 → QEMU 模拟 ARM
CPU 执行。这跟「烧进开发板」是同一套流程，只是执行环境不同。

**踩坑：VS Code 扩展是按平台分包的**
装 C/C++ 扩展时遇到一个很典型的坑——微软市场里的 `ms-vscode.cpptools`
**按平台分成了 9 个包**（win32-x64 / linux-x64 / darwin-x64 / linux-arm64 …）。
如果按「通用」去拉，很可能拿到的是 macOS 的包，里头的 `cpptools` 是 Mach-O
格式，在 Linux 上直接 `Permission denied`。

判别方法：`file` 一下 `~/.vscode-server/extensions/ms-vscode.cpptools-*/bin/cpptools`，
必须是 `ELF 64-bit LSB executable, x86-64` 才对。
拿到正确平台包的办法：查市场的 extensionquery 接口，带 `flags:2151`
把 `targetPlatform` 列出来，取 `linux-x64` 那个下载地址。

**踩坑：CMake 项目的 IntelliSense 要喂 compile_commands.json**
命令行编译得过、编辑器却报红，通常是因为 cpptools 不知道真实的头文件路径和
宏定义。在 `CMakeLists.txt` 里加一句 `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)`，
配置一次就会生成 `build/compile_commands.json`，`.vscode/settings.json` 里的
`C_Cpp.default.compileCommands` 指过去，报错就和真实编译一致了。

## 环境备忘

| 项目 | 值 |
|---|---|
| 发行版 | Ubuntu 22.04.5 LTS（WSL2） |
| 内核 | 6.18.40.1-microsoft-standard-WSL2 |
| 用户 | yingying (uid 1000, sudo 免密) |
| 工作目录 | `~/work`（**不要**放 `/mnt/c`） |
| apt 源 | mirror.sjtu.edu.cn |
| 交叉工具链 | arm-linux-gnueabihf-gcc 11.4.0 |
| 调试器 | gdb 12.1（原生）/ gdb-multiarch 12.1（ARM） |
| 模拟器 | qemu-arm / qemu-system-arm 6.2.0 |

从 Windows 侧访问本目录：`\\wsl.localhost\Ubuntu-22.04\home\yingying\work`

## 推送到 GitHub（SSH，不用 HTTPS）

这台机器到 `github.com` 的 **HTTPS 443 被阻断**（curl 超时），但 **SSH 可用**，
所以走 SSH。`~/.ssh/config` 里配了两条通道，22 不通会自动回退到 443。

```bash
# 1) 把公钥加到 GitHub → Settings → SSH and GPG keys → New SSH key
cat ~/.ssh/id_ed25519.pub

# 2) 验证连通（看到 successfully authenticated 且 Hi <用户名>! 就成了）
ssh -T git@github.com

# 3) 关联远程仓库并推送
git remote add origin git@github.com:<你的用户名>/embedded-linux.git
git push -u origin main
```

以后每天写代码的节奏就是：

```bash
git add .
git commit -m "W02: 完成 xx"
git push
```

