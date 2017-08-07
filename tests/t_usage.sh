#!/bin/sh
#
# run "openvpn --help"
# - check that openvpn did not crash
#
# prerequisites:
# - openvpn binary in current directory
#
# inspired by https://www.mail-archive.com/openvpn-devel@lists.sourceforge.net/msg13808.html
#

top_builddir="${top_builddir:-..}"

if [ ! -x "${top_builddir}/src/openvpn/openvpn" ]
then
    echo "no (executable) openvpn binary in current build tree. FAIL." >&2
    exit 1
fi

exit_code=0

"${top_builddir}/src/openvpn/openvpn" --help >/dev/null

if [ $? -ne 1 ]
then
   exit_code=1
fi

exit $exit_code
