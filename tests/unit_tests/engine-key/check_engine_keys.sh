#!/bin/sh

OPENSSL_CONF="${builddir}/openssl.cnf"
export OPENSSL_CONF

password='AT3S4PASSWD'

key="${builddir}/client.key"
pwdfile="${builddir}/passwd"

grep_a_log () {
  grep -q $1 $2 || { echo $3; cat $2 ; exit 1; }
}

# create an engine key for us
sed 's/PRIVATE KEY/TEST ENGINE KEY/' < ${top_srcdir}/sample/sample-keys/client.key > ${key}
echo "$password" > $pwdfile

# note here we've induced a mismatch in the client key and the server
# cert which openvpn should report and die.  Check that it does.  Note
# also that this mismatch depends on openssl not openvpn, so it is
# somewhat fragile
${top_builddir}/src/openvpn/openvpn --cd ${top_srcdir}/sample --config sample-config-files/loopback-server --engine testengine --key ${key} --askpass $pwdfile > log.txt 2>&1

# first off check we died because of a key mismatch.  If this doesn't
# pass, suspect openssl of returning different messages and update the
# test accordingly
grep_a_log 'X509_check_private_key:key values mismatch' log.txt 'Key mismatch not detected'

# now look for the engine prints (these are under our control)
grep_a_log 'ENGINE: engine_init called' log.txt 'Engine initialization not detected'
grep_a_log 'ENGINE: engine_load_key called' log.txt 'Key was not loaded from engine'
grep_a_log "ENGINE: engine_load_key got password ${password}" log.txt 'Key password was not retrieved by the engine'
exit 0
