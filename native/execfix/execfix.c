// Interceptor de execve() para Android (mismo principio que termux-exec).
// Redirige cualquier ejecución de ELF a través del linker dinámico real
// del sistema, que sí tiene permiso de mapear código ejecutable, aunque
// el fichero original viva en almacenamiento "no ejecutable" de la app.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <fcntl.h>

#if defined(__LP64__)
#define LINKER_PATH "/system/bin/linker64"
#else
#define LINKER_PATH "/system/bin/linker"
#endif

typedef int (*execve_t)(const char *, char *const[], char *const[]);

static execve_t real_execve(void) {
    static execve_t fn = NULL;
    if (!fn) fn = (execve_t)dlsym(RTLD_NEXT, "execve");
    return fn;
}

static int count_argv(char *const argv[]) {
    int n = 0;
    while (argv[n]) n++;
    return n;
}

int execve(const char *pathname, char *const argv[], char *const envp[]) {
    if (strcmp(pathname, LINKER_PATH) == 0) {
        return real_execve()(pathname, argv, envp);
    }

    char shebang[2] = {0, 0};
    int fd = open(pathname, O_RDONLY);
    if (fd >= 0) read(fd, shebang, 2);

    if (fd >= 0 && shebang[0] == '#' && shebang[1] == '!') {
        char line[512] = {0};
        int pos = 0;
        char c;
        lseek(fd, 2, SEEK_SET);
        while (pos < (int)sizeof(line) - 1 && read(fd, &c, 1) == 1 && c != '\n') {
            line[pos++] = c;
        }
        close(fd);

        char *interp = line;
        while (*interp == ' ' || *interp == '\t') interp++;
        char *end = interp;
        while (*end && *end != ' ' && *end != '\t' && *end != '\n') end++;
        char *interp_arg = NULL;
        if (*end) {
            *end = '\0';
            interp_arg = end + 1;
            while (*interp_arg == ' ' || *interp_arg == '\t') interp_arg++;
            if (*interp_arg == '\0') interp_arg = NULL;
        }

        int orig_n = count_argv(argv);
        int extra = interp_arg ? 2 : 1;
        char **new_argv = malloc(sizeof(char *) * (orig_n + extra + 1));
        int idx = 0;
        new_argv[idx++] = interp;
        if (interp_arg) new_argv[idx++] = interp_arg;
        new_argv[idx++] = (char *)pathname;
        for (int i = 1; i < orig_n; i++) new_argv[idx++] = argv[i];
        new_argv[idx] = NULL;

        int ret = execve(interp, new_argv, envp);
        free(new_argv);
        return ret;
    }
    if (fd >= 0) close(fd);

    int orig_n = count_argv(argv);
    char **new_argv = malloc(sizeof(char *) * (orig_n + 2));
    new_argv[0] = LINKER_PATH;
    new_argv[1] = (char *)pathname;
    for (int i = 1; i < orig_n; i++) new_argv[i + 1] = argv[i];
    new_argv[orig_n + 1] = NULL;

    int ret = real_execve()(LINKER_PATH, new_argv, envp);
    free(new_argv);
    return ret;
}
