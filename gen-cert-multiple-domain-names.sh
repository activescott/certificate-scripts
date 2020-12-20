#!/usr/bin/env sh
#####
# 
#####

##### Boilerplate stuff
MYNAME=`basename "$0"`
MYFULLNAME="$PWD/$MYNAME"
MYDIR=`dirname "$MYFULLNAME"`

show_help() {
	echo "\nUsage: ./$(basename $0) HOST_SHORT_NAME DOMAIN_NAME_PRIMARY [ALT_DOMAIN=<alternative domain>] [CORPORATION=<subject_corporation_name>] [GROUP=<subject_group_name>] [CITY=<subject_city_name>] [STATE=<subject_state_name>] [COUNTRY=<subject_country_name>]"
  echo "\nRequired Positional Arguments:"
  echo "  HOST_SHORT_NAME:      The host name without any domain information." 
	echo "  DOMAIN_NAME_PRIMARY:  The primary domain for the host." 
  echo "\nOptional, named arguments: The below arguments are optional and can be provided by specifying them with the name=value format:"
	echo "  ALT_DOMAIN=<value>    A host name without any domain information."  
  echo "  CORPORATION=<value>   The O= value in the subject."
  echo "  GROUP=<value>         The OU= value in the subject."
  echo "  CITY=<value>          The L= value in the subject."
  echo "  STATE=<value>         The ST= value in the subject."
  echo "  COUNTRY=<value>       The C= value in the subject."
  echo "\n"
}

die () {
	echo >&2 "\n$@" #TODO: should probably use printf instead of echo to support newlines. Need to test.
  show_help
	exit 1
}
#####

##### PARSE ARGUMENTS #####

## Required Positional Arguments:

HOST_SHORT_NAME=$1 # e.g. bitbox
DOMAIN_NAME_PRIMARY=$2 # e.g. mycooldomain.com

# Validate:
[ -z "$HOST_SHORT_NAME" ] && die "ERROR: HOST_SHORT_NAME must be specified!"
[ -z "$DOMAIN_NAME_PRIMARY" ] && die "ERROR: DOMAIN_NAME_PRIMARY must be specified!"

# Optional Named Arguments:
unset CORPORATION
unset GROUP
unset CITY
unset STATE
unset COUNTRY
unset ALT_DOMAIN

for ARGUMENT in "$@"
do

    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)

    case "$KEY" in
            CORPORATION) CORPORATION=${VALUE} ;;
            GROUP)       GROUP=${VALUE} ;;
            CITY)        CITY=${VALUE} ;;
            STATE)       STATE=${VALUE} ;;
            COUNTRY)     COUNTRY=${VALUE} ;;
            ALT_DOMAIN)  ALT_DOMAIN=${VALUE} ;;
            *)   
    esac    

done

echo "Using the following subject detail to generate certificate:"
echo " Primary name: $HOST_SHORT_NAME.$DOMAIN_NAME_PRIMARY"
if [ -n "$ALT_DOMAIN" ]; then
  echo " Alternative name: $HOST_SHORT_NAME.$ALT_DOMAIN"
else
  echo " Alternative name: (not specified)"
fi
echo " CORPORATION: $CORPORATION"
echo " GROUP: $GROUP"
echo " CITY: $CITY"
echo " STATE: $STATE"
echo " COUNTRY: $COUNTRY"

##### / PARSE ARGUMENTS ####

##### openssl path
# MAC SPECIFIC :/
# NOTE: We need the non-mac bundled openssl for -addext (https://security.stackexchange.com/a/183973/40848)
#  We're using homebrew installed v1.1 here and I tested with OpenSSL 1.1.1g  21 Apr 2020
OPEN_SSL_BIN=/usr/local/opt/openssl\@1.1/bin/openssl
#####

# Prepare file names:
PRIVATE_KEY_FILE="$HOST_SHORT_NAME-key.pem"
CSR_FILE="$HOST_SHORT_NAME-csr.csr"
CERT_FILE="$HOST_SHORT_NAME-cert.crt"

# clean up any pre-existing files:
[ -f "$PRIVATE_KEY_FILE" ] && rm "$PRIVATE_KEY_FILE"
[ -f "$CSR_FILE" ]         && rm "$CSR_FILE"
[ -f "$CERT_FILE" ]        && rm "$CERT_FILE"

# For details on subjectAltName see:
# - https://security.stackexchange.com/a/183973/40848
# - http://apetec.com/support/GenerateSAN-CSR.htm
# - https://medium.com/@pubudu538/how-to-create-a-self-signed-ssl-certificate-for-multiple-domains-25284c91142b


#SUBJ_STR="/CN=$HOST_SHORT_NAME.$DOMAIN_NAME/OU=$GROUP/O=$CORPORATION/L=$CITY/ST=$STATE/C=$COUNTRY"
SUBJ_STR="/CN=$HOST_SHORT_NAME.$DOMAIN_NAME_PRIMARY"
[ -n "$GROUP" ] && SUBJ_STR="$SUBJ_STR/OU=$GROUP"
[ -n "$CORPORATION" ] && SUBJ_STR="$SUBJ_STR/O=$CORPORATION"
[ -n "$CITY" ] && SUBJ_STR="$SUBJ_STR/L=$CITY"
[ -n "$STATE" ] && SUBJ_STR="$SUBJ_STR/ST=$STATE"
[ -n "$COUNTRY" ] && SUBJ_STR="$SUBJ_STR/C=$COUNTRY"
#echo "Using SUBJ_STR: $SUBJ_STR"

if [ -n "$ALT_DOMAIN" ]; then
  $OPEN_SSL_BIN req\
    -new\
    -newkey rsa:2048\
    -subj "$SUBJ_STR" \
    -nodes\
    -keyout "$PRIVATE_KEY_FILE" \
    -out "$CSR_FILE" \
    -addext "subjectAltName = DNS:$HOST_SHORT_NAME.$ALT_DOMAIN" -addext "certificatePolicies = 1.2.3.4"
else
  $OPEN_SSL_BIN req\
    -new\
    -newkey rsa:2048\
    -subj "$SUBJ_STR" \
    -nodes\
    -keyout "$PRIVATE_KEY_FILE" \
    -out "$CSR_FILE"
    #-addext "subjectAltName = DNS:$HOST_SHORT_NAME.$ALT_DOMAIN" -addext "certificatePolicies = 1.2.3.4"
fi

if [ "$?" = "0" ]
then
  echo "\ngenerating private key (.pem) and certificate request file (.crf) succeeded.\n"
else
  die "generating private key (.pem) and certificate request file (.crf) FAILED."
fi

# openssl x509 doesn't read the extentions from a CSR. So we have to generate a config file:
if [ -n "$ALT_DOMAIN" ]; then
  echo "\nGenerating config file...\n"

  CNF_FILE=tempopenssl.cnf
  cat <<- EOF > $CNF_FILE
  [req]
  req_extensions = v3_req

  [v3_req]
  subjectAltName = @alt_names

  [alt_names]
  DNS.1 = $HOST_SHORT_NAME.$ALT_DOMAIN
EOF

  echo "\nCalling openssl to create $CERT_FILE\n"
  $OPEN_SSL_BIN x509\
    -req \
    -days 365 \
    -in "$CSR_FILE" \
    $OPT_EXTENSION_ARGS \
    -signkey "$PRIVATE_KEY_FILE" \
    -out "$CERT_FILE" \
    -extfile $CNF_FILE -extensions v3_req
else
  echo "\nCalling openssl to create $CERT_FILE\n"
  $OPEN_SSL_BIN x509\
    -req \
    -days 365 \
    -in "$CSR_FILE" \
    $OPT_EXTENSION_ARGS \
    -signkey "$PRIVATE_KEY_FILE" \
    -out "$CERT_FILE"
    #-extfile $CNF_FILE -extensions v3_req
fi

if [ $? ]
then
  echo "\ngenerating x509 .crt file succeeded.\n"
  [ -f "$CNF_FILE" ] && rm "$CNF_FILE"
else
  die "generating  x509 .crt file FAILED."
fi

echo "\nDisplaying info from the generated certificate:\n"
CERT_DISP_OPT="-certopt no_header,no_sigdump,no_pubkey,ext_error"
$OPEN_SSL_BIN x509 -text -noout $CERT_DISP_OPT -in $CERT_FILE

exit $?