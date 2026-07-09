#include <security/pam_appl.h>
#include <security/pam_misc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct appdata {
    const char *password;
};

static int conversation(int num_msg, const struct pam_message **msg,
                        struct pam_response **resp, void *appdata_ptr) {
    struct appdata *data = (struct appdata *)appdata_ptr;
    struct pam_response *responses = calloc((size_t)num_msg, sizeof(struct pam_response));
    if (responses == NULL) {
        return PAM_BUF_ERR;
    }

    for (int i = 0; i < num_msg; i++) {
        if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF ||
            msg[i]->msg_style == PAM_PROMPT_ECHO_ON) {
            responses[i].resp = strdup(data->password);
            if (responses[i].resp == NULL) {
                free(responses);
                return PAM_BUF_ERR;
            }
        }
    }

    *resp = responses;
    return PAM_SUCCESS;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <user>\n", argv[0]);
        return 2;
    }

    char password[4096];
    if (fgets(password, sizeof(password), stdin) == NULL) {
        return 2;
    }
    password[strcspn(password, "\r\n")] = '\0';

    struct appdata data = {.password = password};
    struct pam_conv conv = {.conv = conversation, .appdata_ptr = &data};
    pam_handle_t *pamh = NULL;

    const char *service = getenv("KDE_WEBTOP_PAM_SERVICE");
    if (service == NULL || service[0] == '\0') {
        service = "login";
    }

    int rc = pam_start(service, argv[1], &conv, &pamh);
    if (rc == PAM_SUCCESS) {
        rc = pam_authenticate(pamh, 0);
    }
    if (rc == PAM_SUCCESS) {
        rc = pam_acct_mgmt(pamh, 0);
    }
    if (pamh != NULL) {
        pam_end(pamh, rc);
    }

    explicit_bzero(password, sizeof(password));
    return rc == PAM_SUCCESS ? 0 : 1;
}
