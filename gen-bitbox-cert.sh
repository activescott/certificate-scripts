#!/usr/bin/env sh
MYNAME=`basename "$0"`
MYFULLNAME="$PWD/$MYNAME"
MYDIR=`dirname "$MYFULLNAME"`

"$MYDIR/gen-cert-multiple-domain-names.sh" bitbox activescott.com activenet CORPORATION='@activescott' CITY='Seattle' STATE='WA' COUNTRY='US'
