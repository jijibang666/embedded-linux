# W01 — 环境搭建与第一个程序

嵌入式 Linux 求职路线的第 1 周。目标不是"学到什么新知识"，而是**把一台能持续用 24 周的机器搭出来**，并且证明这条流水线从头到尾是通的。

> **一句话验收：** `bash w01-preflight.sh` —— 38 项实测，全绿才算这一周过。
>
> 不确定下一步做什么就跑 `~/work/progress.sh`；想知道 W02/W03 的环境在哪，看 `~/work/embedded-linux/README.md`。

## 一周成果

- Windows 11 + WSL2（Ubuntu 22.04.5 LTS，内核 6.18.40.1-microsoft-standard-WSL2），导入的发行版名为 `Ubuntu-22.04`
- Linux 用户 `yingying`（uid 1000，sudo 免密），代码一律放 Linux 侧的 `~/work`，不放 `/mnt/c`
- apt 源换成上海交大镜像（`mirror.sjtu.edu.cn`）
- 工具链：gcc/g++ 11.4.0、make 4.3、cmake 3.22.1、ninja 1.10.1、git 2.34.1、gdb 12.1、
  dtc 1.6.1、qemu-system-arm 6.2.0、arm-linux-gnueabihf-gcc 11.4.0、minicom 2.8、sigrok-cli 0.7.2、strace、valgrind
- VS Code 通过 WSL 远程连接（`code` 已在 WSL 里可用），IntelliSense / 构建任务 / gdb 调试配置全部就绪

## 目录内容

| 文件 | 干什么的 |
| --- | --- |
| `hello.c` | 第一个程序，原生和 ARM 两个目标都编它 |
| `Makefile` | `make` / `make run` / `make arm` / `make qemu` / `make arm-all` / `make clean` |
| `CMakeLists.txt` | CMake 工程定义，`CMAKE_EXPORT_COMPILE_COMMANDS=ON` 供 IntelliSense 用 |
| `intellisense-check.c` | 故意留了 3 个错，用来肉眼确认扩展是不是真在工作 |
| `w01-preflight.sh` | 一键自检 38 项（环境 / 工具链 / 编译 / 调试 / VS Code / 推送通道），全绿才算这周过 |
| `W01-acceptance.md` | 逐项验收记录，含 GitHub 凭据排查的完整证据 |
| `.vscode/` | 编辑器配置：构建任务、gdb 调试、C/C++ 设置、推荐扩展 |

## 常用命令

```bash
# 原生编译运行（x86-64，日常练 C 用这个）
make && ./hello

# 交叉编译到 ARM 并用 QEMU 跑（不需要开发板）
make arm && qemu-arm ./hello_arm

# CMake + Ninja 构建（并生成 compile_commands.json 喂给 IntelliSense）
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build && ./build/hello

# 看文件类型，确认交叉编译真的产出了 ARM 二进制
file hello_arm
arm-linux-gnueabihf-readelf -h hello_arm
```

## 踩坑记录（这些坑以后还会遇到，先记下来）

### 坑 1：VS Code 的扩展是按平台分包的

微软市场里 `ms-vscode.cpptools` 有 9 个按平台拆开的包（`win32-x64`、`linux-x64`、`darwin-x64`、`linux-arm64`……）。如果按普通方式下载，拿到的可能是给 macOS 用的 `darwin-x64` 包，装到 Linux 上执行 `bin/cpptools` 会直接 `Permission denied`。

判别方法：`file ~/.vscode-server/extensions/ms-vscode.cpptools-*/bin/cpptools` —— 必须是 `ELF 64-bit LSB executable`，如果是 `Mach-O 64-bit x86_64` 那就是拿错包了。

### 坑 2：CMake 项目的 IntelliSense 要喂 compile_commands.json

CMake 项目光靠扩展自己猜头文件路径会漏，要在 `CMakeLists.txt` 里打开 `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)`，再在 `settings.json` 里加 `"C_Cpp.default.compileCommands": "${workspaceFolder}/build/compile_commands.json"`，写完记得先跑一次 CMake 配置。

### 坑 3：cpptools 的二进制用相对路径指定解释器

`bin/cpptools` 的 ELF 解释器是 `./libc.so`（相对路径），所以必须在 `bin/` 目录里、或者用相对路径调用它；从别的目录用绝对路径直接跑会报 `No such file or directory`。这是正常现象，不是装坏了。

## 怎么确认 IntelliSense 真的在工作

`intellisense-check.c` 里故意留了 3 个错：

| 行号 | 代码 | 应该出现的提示 |
| --- | --- | --- |
| 17 | `undefined_function(x);` | 隐式声明 / 找不到符号 |
| 18 | `int z = x + "字符串";` | 指针与整数相加，类型不匹配 |
| 20 | `not_declared` | 未声明的标识符 |

在 VS Code 里打开这个文件，编辑器里应该看到 3 处红色波浪线；同时「问题」面板（Ctrl+Shift+M）会列出这 3 条。
一条命令同时确认三件事（编译器报错 + `compile_commands.json` 在 + cpptools 是 ELF）：

```bash
# VS Code 里：Ctrl+Shift+P → Tasks: Run Task → 8-自检 IntelliSense（故意报 3 个错）
```

如果波浪线没出现，按顺序检查：① 扩展是不是装在 WSL 侧（`ls ~/.vscode-server/extensions/ | grep cpptools`）；
② `build/compile_commands.json` 在不在；③ `settings.json` 里有没有 `C_Cpp.default.compileCommands`。

## 推送到 GitHub（HTTPS + gh 凭据）

用 `gh auth login` 走浏览器授权拿到 token 之后，git 的凭据由 gh 托管（存在 `~/.config/gh/hosts.yml`），**推送不用输密码**。

> 为什么不用 SSH：本机 SSH 通道的 token 缺少 `admin:public_key` 权限，无法通过 API 注册公钥；
> 而 HTTPS token 自带 `repo` 权限，直接就能推。SSH 通道仍然保留（`~/.ssh/config` 里配了 22→443 自动回退），需要时 `gh auth refresh -h github.com -s admin:public_key` 补权限即可。

```bash
# 0. 确认公钥本身（如果没有就先 ssh-keygen -t ed25519 -C "你的邮箱"）
cat ~/.ssh/id_ed25519.pub
# 把这一整行粘到 https://github.com/settings/ssh/new

# 1. 验证身份，看到 "Hi <用户名>! You've successfully authenticated" 就对了
ssh -T git@github.com

# 2. 推（首次推送会自动创建仓库）
git push github HEAD:refs/heads/main

# 3. 以后日常推送
git push
```

VS Code 里也配了对应的任务：`Ctrl+Shift+B` → 或者 `Ctrl+Shift+P` → `Tasks: Run Task` →
- `7-推送到 GitHub（HTTPS，用 gh 凭据）`
- `7b-测试 GitHub SSH 连接`
- `7c-提交当前改动`

### 更省事的另一条路：用 GitHub CLI 网页授权

如果懒得手抄那 80 个字符的公钥，也可以让 `gh` 走浏览器授权（授权后它能直接替你注册公钥）：

```bash
sudo apt-get install -y gh                 # 交大镜像，约 8 秒
gh auth login --hostname github.com --web  # 复制一次性代码 → 浏览器里输入 → 点 Authorize
bash ~/work/post-login-setup.sh            # 注册公钥 + 配凭据助手 + 推送 + 核对远端 HEAD
```

`gh` 登录成功后，后续 HTTPS 推送也不用再输密码（凭据存在 `~/.config/gh/hosts.yml`）。

### 远程仓库是双轨的

| 名称 | 地址 | 用途 |
| --- | --- | --- |
| `origin` | `~/work/remote/embedded-linux.git` | 本地裸仓库，断网也能推，当日常备份；`git push` 默认推这里 |
| `github` | `git@github.com:jijibang666/embedded-linux.git` | 线上仓库，求职时给人看的那个 |

## 验收标准

- [x] `wsl -l -v` 显示发行版处于 Running、版本 2
- [x] 原生编译运行成功，输出 `hello, embedded linux`
- [x] 交叉编译产出 ARM 二进制，`file` 显示 `ELF 32-bit LSB executable, ARM, EABI5 ... statically linked`
- [x] QEMU 里跑通 ARM 程序，输出同样内容（不依赖开发板）
- [x] CMake + Ninja 能构建，并生成 `compile_commands.json`
- [x] VS Code 连上 WSL，C/C++ 扩展在 Linux 侧可运行（`cpptools --version` → 1.35.3.0）
- [ ] 代码推到 GitHub，能看到仓库页面

详细验收记录见 `W01-acceptance.md`。
