#include <stdio.h>
#include <curl/curl.h>
#include <stdlib.h> // for --> system()

// file made with duct tape

void installerInitialGreeting() {
	printf("===XPK installer===\n");
	printf("This installer will guide you through\n");
	printf("the steps of installer XPK on your UNIX system\n");
}

void bootstrapinstallerDarwin() {
	printf("[*] Running on Darwin... \n");
	printf("[*] Bootstrapping installer...\n");
	CURL *curl;
	FILE *fp;
	CURLcode res;
	char *url = "https://raw.githubusercontent.com/fischblob-lol/xpk/main/scripts/install-darwin.sh";
	char outfilename[FILENAME_MAX] = "/tmp/xpkinstaller";
	curl = curl_easy_init();
	fp = fopen(outfilename,"wb");
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
	curl_easy_setopt(curl, CURLOPT_URL, url);
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, NULL);
	curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
	res = curl_easy_perform(curl);
	curl_easy_cleanup(curl);
	fclose(fp);
	printf("[*] Sucess! Handing off. \n");
	char handoffcmd[4095] = "bash /tmp/xpkinstaller";
	system(handoffcmd);
}

void bootstrapinstallerLinux() {
	printf("[*] Running on Linux... \n");
	printf("[*] Bootstrapping installer...\n");
	CURL *curl;
	FILE *fp;
	CURLcode res;
	char *url = "https://raw.githubusercontent.com/fischblob-lol/xpk/main/scripts/install-linux.sh";
	char outfilename[FILENAME_MAX] = "/tmp/xpkinstaller";
	curl = curl_easy_init();
	fp = fopen(outfilename,"wb");
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
	curl_easy_setopt(curl, CURLOPT_URL, url);
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, NULL);
	curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
	res = curl_easy_perform(curl);
	curl_easy_cleanup(curl);
	fclose(fp);
	printf("[*] Sucess! Handing off. \n");
	char handoffcmd[4095] = "bash /tmp/xpkinstaller";
	system(handoffcmd);
}
