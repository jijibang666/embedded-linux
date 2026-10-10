// -*- mode: c -*-
// W01 自测用：故意留了几个错误，用来验证 Linux 侧的 cpptools IntelliSense 是否工作。
// 打开这个文件后，下面标了「这里应该报错」的几行应当出现红色波浪线。
#include <stdio.h>
#include <stdlib.h>

int add(int a, int b) {
    return a + b;
}

int main(void) {
    int x = 3;
    int y = 4;

    printf("%d\n", add(x, y));

    undefined_function(x);   // 这里应该报错：隐式声明 / 未定义符号
    int z = x + "字符串";      // 这里应该报错：指针与整数相加，类型不匹配
    printf("%d\n", z);
    printf("%d\n", not_declared);  // 这里应该报错：未声明的标识符

    return 0;
}
