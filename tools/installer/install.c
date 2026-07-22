#include <stdio.h>
#include <string.h>
#include "installer.h"
#ifdef __linux__
char OperatingSystem[] = "linux";
#elif defined(__APPLE__)
char OperatingSystem[] = "macos";
#else
char OperatingSystem[] = "unknown";
#endif

int main() {
    installerInitialGreeting();
    char continueRequest;
    printf("[?] Do you want to continue?(y/n)\n");
    scanf("%c", &continueRequest);
    if (continueRequest == 'y') {
        printf("[*] ok, will continue installer\n");
        if (strcmp(OperatingSystem, "macos") == 0) {
            printf("[*] Detected OS is MacOS/Darwin\n");
            printf("[*] Switching to the MacOS installer!\n");
            bootstrapinstallerDarwin();
        }
        if (strcmp(OperatingSystem, "linux") == 0) {
            printf("[*] Detected OS is Linux\n");
            printf("[*] Switching to the Linux installer!\n");
            bootstrapinstallerLinux();
        }
    }
    else if (continueRequest == 'n') {
        printf("[*] ok, will not install");
      //  return 0;
    } else {
        printf("[x] Response not understood. Abort!");
        return 1;
    }
}
