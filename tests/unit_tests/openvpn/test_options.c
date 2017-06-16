#ifdef HAVE_CONFIG_H
#include "config.h"
#elif defined(_MSC_VER)
#include "config-msvc.h"
#endif

#include "syshead.h"

#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include <cmocka.h>

#include "buffer.h"
#include "error.h"
#include "misc.h"
#include "platform.h"
#include "argv.h"
#include "fdmisc.h"
#include "tun.h"
#include "manage.h"
#include "route.h"
#include "mtu.h"
#include "socket.h"
#include "crypto_backend.h"
#include "options.h"

static void
usage_test(void **state)
{
    usage();
}

int
main(void)
{
    const struct CMUnitTest tests[] = {
        cmocka_unit_test(usage_test),
    };

    return cmocka_run_group_tests(tests, NULL, NULL);
}
