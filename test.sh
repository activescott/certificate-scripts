#!/usr/bin/env sh
MYNAME=`basename "$0"`
MYFULLNAME="$PWD/$MYNAME"
MYDIR=`dirname "$MYFULLNAME"`

unset TEST_NAME

begin_test () {
  if [ -z "$1" ]; then
    echo "Must specify a test name when calling begin_test!"
    exit 1
  fi
  TEST_NAME=$1
  echo "\n\n------------------------------------"
  echo "Beginning test \"$TEST_NAME\""
  echo "------------------------------------"
}

assert_fail() {
	echo >&2 "\nTest $TEST_NAME failed: $@"
	exit 1
}

assert_success() {
  echo "Test $TEST_NAME PASSED"
}

last_cmd_should_exit_success() {
  LAST_EXIT=$?
  if [ "$LAST_EXIT" -ne "0" ]; then
    assert_fail "Last command expected to succeed, but was $LAST_EXIT"
  fi
}

last_cmd_should_exit_fail() {
  LAST_EXIT=$?
  if [ "$LAST_EXIT" -eq "0" ]; then
    assert_fail "Last command expected to exit with failure, but was $LAST_EXIT"
  fi
}

begin_test "No domains (not enough)"
"$MYDIR/gen-cert-multiple-domain-names.sh" "myhost"
last_cmd_should_exit_fail

begin_test "One domain (ok)"
"$MYDIR/gen-cert-multiple-domain-names.sh" "myhost" "my-primary-domain.com"
last_cmd_should_exit_success

begin_test "Two domains (ok)"
"$MYDIR/gen-cert-multiple-domain-names.sh" "myhost" "my-primary-domain.com" "my-secondary-domain.com"
last_cmd_should_exit_success

begin_test "All attributes"
"$MYDIR/gen-cert-multiple-domain-names.sh" "myhost" "mydomain.com" ALT_DOMAIN="myseconddomain.com" COUNTRY="US" CORPORATION='@activescott' CITY='Seattle' STATE='WA' COUNTRY="US"
last_cmd_should_exit_success
