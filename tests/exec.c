/**
 * exec.c - External executable test fixture.
 * Summary: Minimal external executable for kcapk integration tests.
 *
 * Author:  KaisarCode
 * Website: https://kaisarcode.com
 * License: https://www.gnu.org/licenses/gpl-3.0.html
 */

static const char message[] = "kcapk external executable OK\n";

#if defined(__aarch64__)
/**
 * sys_write - Write to a file descriptor using direct syscall.
 * @fd: File descriptor.
 * @buf: Buffer to write.
 * @len: Number of bytes to write.
 * @return Number of bytes written, or negative error code.
 */
static long sys_write(long fd, const void *buf, long len) {
    register long x0 __asm__("x0") = fd;
    register const void *x1 __asm__("x1") = buf;
    register long x2 __asm__("x2") = len;
    register long x8 __asm__("x8") = 64;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x8) : "memory");
    return x0;
}

/**
 * sys_exit - Exit the process using direct syscall.
 * @code: Exit code.
 * @return Does not return.
 */
static void sys_exit(long code) {
    register long x0 __asm__("x0") = code;
    register long x8 __asm__("x8") = 93;
    __asm__ volatile("svc 0" : : "r"(x0), "r"(x8) : "memory");
    __builtin_unreachable();
}
#elif defined(__x86_64__)
/**
 * sys_write - Write to a file descriptor using direct syscall.
 * @fd: File descriptor.
 * @buf: Buffer to write.
 * @len: Number of bytes to write.
 * @return Number of bytes written, or negative error code.
 */
static long sys_write(long fd, const void *buf, long len) {
    long ret;
    register long rax __asm__("rax") = 1;
    register long rdi __asm__("rdi") = fd;
    register const void *rsi __asm__("rsi") = buf;
    register long rdx __asm__("rdx") = len;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(rax), "D"(rdi), "S"(rsi), "d"(rdx) : "rcx", "r11", "memory");
    return ret;
}

/**
 * sys_exit - Exit the process using direct syscall.
 * @code: Exit code.
 * @return Does not return.
 */
static void sys_exit(long code) {
    register long rax __asm__("rax") = 60;
    register long rdi __asm__("rdi") = code;
    __asm__ volatile("syscall" : : "a"(rax), "D"(rdi) : "rcx", "r11", "memory");
    __builtin_unreachable();
}
#else
#error Unsupported architecture
#endif

/**
 * _start - Program entry point.
 * Writes a test message to stdout and exits successfully.
 * @return Does not return.
 */
void _start(void) {
    sys_write(1, message, sizeof(message) - 1);
    sys_exit(0);
}
