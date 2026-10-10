# CMake 模板：让 IntelliSense 拿到精确的编译参数
#
# 用法：
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
#   cmake --build build
#   ./build/hello
#
# 关键点：CMAKE_EXPORT_COMPILE_COMMANDS=ON 会生成 build/compile_commands.json，
# cpptools 读到它之后，头文件路径、宏定义、标准版本都跟真实编译完全一致，
# 就不会再出现「命令行能编过、VS Code 却报红」的假错误。
# （VS Code 侧由 .vscode/settings.json 的 C_Cpp.default.compileCommands 指过来。）
#
# 想交叉编译成 ARM，不必改这个文件，用工具链参数即可：
#   cmake -S . -B build-arm -G Ninja \
#         -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc \
#         -DCMAKE_EXE_LINKER_FLAGS=-static
#   cmake --build build-arm

cmake_minimum_required(VERSION 3.16)
project(w01 C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)      # ← 这一行是 IntelliSense 舒服的关键

add_compile_options(-Wall -Wextra -g -O0)

add_executable(hello hello.c)
