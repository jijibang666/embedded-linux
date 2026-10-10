# W01 验收记录

记录时间：2026-10-10（W01 收尾）
环境：Windows 11 + WSL2 / Ubuntu 22.04.5 LTS / 内核 6.18.40.1-microsoft-standard-WSL2

---

## 1. WSL 与发行版

| 检查项 | 命令 | 实测结果 | 结论 |
| --- | --- | --- | --- |
| 发行版状态 | `wsl -l -v` | `Ubuntu-22.04  Running  2` | ✅ |
| 版本 | `lsb_release -a` | Ubuntu 22.04.5 LTS (Jammy Jellyfish) | ✅ |
| 内核 | `uname -r` | 6.18.40.1-microsoft-standard-WSL2 | ✅ |
| 默认用户 | `id` | `uid=1000(yingying) gid=1000(yingying) groups=1000(yingying),27(sudo)` | ✅ |
| sudo | `sudo -n true; echo $?` | `0`（免密） | ✅ |
| 磁盘 | `df -h /` | 已用 4.0G，可用 952G | ✅ |

## 2. 工具链（全部 `--version` 验证过）

| 工具 | 版本 | 工具 | 版本 |
| --- | --- | --- | --- |
| gcc / g++ | 11.4.0 | git | 2.34.1 |
| make | 4.3 | gdb | 12.1 |
| cmake | 3.22.1 | dtc | 1.6.1 |
| ninja | 1.10.1 | qemu-system-arm | 6.2.0 |
| arm-linux-gnueabihf-gcc | 11.4.0 | minicom | 2.8 |
| sigrok-cli | 0.7.2 | strace / valgrind | 已装 |

## 3. 编译与运行

| 检查项 | 命令 | 实测输出 | 结论 |
| --- | --- | --- | --- |
| 原生编译运行 | `make && ./hello` | `hello, embedded linux` | ✅ |
| 交叉编译 | `make arm` | 生成 `hello_arm` | ✅ |
| 二进制格式 | `file hello_arm` | `ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked` | ✅ |
| QEMU 运行 | `qemu-arm ./hello_arm` | `hello, embedded linux` | ✅ |
| CMake 配置 | `cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug` | 配置成功 | ✅ |
| CMake 构建运行 | `cmake --build build && ./build/hello` | `hello, embedded linux` | ✅ |
| IntelliSense 数据 | `ls build/compile_commands.json` | 存在，含 `hello.c` 的完整编译命令 | ✅ |

## 4. VS Code

| 检查项 | 实测结果 | 结论 |
| --- | --- | --- |
| 远程连接 | 窗口标题 `work [WSL: Ubuntu-22.04] - Visual Studio Code` | ✅ |
| `code` 命令在 WSL 里可用 | `type code` → function（`~/.bashrc` 里的 shim） | ✅ |
| C/C++ 扩展在 Linux 侧 | `bin/cpptools --version` → `1.35.3.0`，`file` 显示 ELF x86-64 | ✅ |
| 调试配置 | `.vscode/launch.json` 两条：原生 gdb、ARM（QEMU + gdb） | ✅ |
| IntelliSense 自检 | `intellisense-check.c` 里故意留的 3 个错（第 17/18/20 行）被编译器和扩展同时识别 | ✅ |
| 原生 gdb 调试 | `gdb -batch -ex "break main" -ex run -ex "print sizeof(int)" ./build/hello` → 断在 hello.c:4，`$1 = 4` | ✅ |
| 构建任务 | `.vscode/tasks.json` 共 14 个任务，JSON 校验通过 | ✅ |

## 5. Git

| 检查项 | 实测结果 | 结论 |
| --- | --- | --- |
| 仓库初始化 | `~/work/w01`，分支 `main` | ✅ |
| 提交 | 4 次提交，工作区干净 | ✅ |
| 本地裸仓库推送 | push 成功，远端 HEAD == 本地 HEAD（`ead53dd`） | ✅ |
| 端到端 | 从裸仓库 clone 回来 → `make` → 输出正确 | ✅ |
| 推送 GitHub | **待完成**：SSH 公钥还没有加到 GitHub 账号 | ⬜ |

### 待办：把公钥加到 GitHub

公钥内容（`~/.ssh/id_ed25519.pub`）：

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSOGgu3Z5BlgW/yI62ttN+mUsZRXol5yWdS4wG6zX8e yingying@laptop
```

指纹：`SHA256:aOBmicSEGNOM0croYyTFFLMmd9B8MBZDXPEKsUp342o`

步骤：
1. 打开 <https://github.com/settings/ssh/new>
2. Title 填 `WSL-Ubuntu-22.04`，Key type 保持 `Authentication Key`
3. Key 里粘贴上面那一整行 → `Add SSH key`
4. 回到 Ubuntu 终端验证：`ssh -T git@github.com`（应显示 `Hi jijibang666! You've successfully authenticated...`）
5. 推送：`cd ~/work/w01 && git push github HEAD:refs/heads/main`


## 6. GitHub 凭据排查（重要结论）

这台机器的 Windows 凭据管理器里存着一个 GitHub 凭据（目标 `git:https://github.com`），
账号是 **jijibang666**（id 295646756，7 个公开仓库）。但它**不能用来推送或建仓库**，实测证据：

| 探测 | 命令 | 结果 | 说明 |
| --- | --- | --- | --- |
| 能读账号信息 | `GET /user`（经 gh-proxy） | 200，返回 `jijibang666` | token 本身有效 |
| 看仓库列表 | `GET /user/repos` | 返回 0 个仓库 | 这个 token 看不到任何仓库 |
| 建仓库 | `POST /user/repos` | **403** `Resource not accessible by personal access token` | 无建仓权限 |
| 管公钥 | `GET /user/keys` | `Resource not accessible` | 无 SSH 公钥管理权限 |
| git 推送 | `git push --dry-run` 到已有仓库 | `remote: No anonymous write access` + `Authentication failed` | 推不上去 |
| 对照组 | 换成随便编的假 token | **一模一样的报错** | 说明 gh-proxy 不转发推送认证 |

结论：**这台机器上现存的凭据只能读公开数据，写操作一条都不行**，必须另找身份。

### 备用通道：gh-proxy.com（只读可用）

实测 `gh-proxy.com` 能给 git 做 HTTPS 传输，`git ls-remote` 能列出真实仓库的 commit：

```
git ls-remote https://gh-proxy.com/https://github.com/aeroheaven1/AutoClicker.git
→ d7867b7c14be7384ff5b3e728c9856c254515a4a  HEAD
→ d7867b7c14be7384ff5b3e728c9856c254515a4a  refs/heads/main
```

但它**只承担读取**（推送时连真 token 和假 token 报错一样），所以不能作为推送方案，只能当"HTTPS 读不了时的手动兜底"。

### 所以推送只有 SSH 一条路

公钥已生成、SSH 配置已就绪（22 端口优先，自动回退 ssh.github.com:443），只差把公钥粘到 GitHub。

---

## 遗留问题

- [ ] 公钥未加到 GitHub（上表最后一项）
- [ ] 任务栏图标固定需要在 VS Code GUI 里手动点一次（Windows 11 不允许脚本固定到任务栏）
