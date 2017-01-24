#!/bin/bash

# $@ line: --eventtype=SSL Certificate Expiry WARN vservers/v_vadc.bedis9.net      vssslcertexpired        expired=1481204580      Public SSL certificate 'c_vadc.bedis9.net_ecc' expired on Thu, 08 Dec 2016 13:43:00 GMT
# My certificate name has the following format: c_[certfile]_[certtype]

# version 1.0

# may be run manually: ./letsencryptforvtm.sh --issue c_vadc.bedis9.net_ecc
# may be run manually: ./letsencryptforvtm.sh --issue c_vadc.bedis9.net_rsa
#set -x

if [ "$1" = "--issue" ]; then
  CERTNAME=${2}
else
  # $1 is eventtype and my be ignored
  CERTNAME=$(echo "${2}" | sed -n "s/.*'\([^']\+\)'.*/\1/p")
fi
CERTFILE=$(echo "${CERTNAME}" | cut -d'_' -f 2)
CERTTYPE=$(echo "${CERTNAME}" | cut -d'_' -f 3)

if [ -z "$CERTNAME" ] || [ -z "$CERTFILE" ] || [ -z "$CERTTYPE" ]; then
  echo "error, can't figure out CERTNAME or CERTFILE or CERTTYPE"
  exit 1
fi

ZCLI=$(locate zcli 2>/dev/null | egrep "bin/zcli$")
[ -z "$ZCLI" ] && ZCLI=$(which zcli)
[ -z "$ZCLI" ] && ZCLI=$(find / -name zcli | egrep "bin/zcli$")

if [ -z "$ZCLI" ]; then
  echo "Can't find zcli command"
  exit 1
fi


ACMEHOME="/root/.acme.sh/"
ACMEOPTIONS="--standalone --httpport 88"
# Worth reading this link first: https://letsencrypt.org/docs/rate-limits/
#TEST="--test --days 0"

case "$CERTTYPE" in
  ecc)
    ACMEKEY="--keylength ec-256"
    CERTDIR=$ACMEHOME/${CERTFILE}_${CERTTYPE}
    ;;
  rsa)
    ACMEKEY="--keylength 2048"
    CERTDIR=$ACMEHOME/${CERTFILE}
    ;;
  *)
    echo "error: wrong CERTTYPE"
    exit 1
esac

if [ -d $CERTDIR ]; then
  # certificate renewal
  ACMEACTION="--renew"
  if [ "$CERTTYPE" = "ecc" ]; then
    ACMEKEY="--ecc"
  fi
else
  # certificate issuance
  ACMEACTION="--issue"
fi

$ACMEHOME/acme.sh $TEST $ACMEOPTIONS $ACMEACTION -d ${CERTFILE} $ACMEKEY

# key
key=$(cat $CERTDIR/${CERTFILE}.key)
key=${key//$'\n'/\\n}

# crt
crt=$(cat $CERTDIR/fullchain.cer)
crt=${crt//$'\n'/\\n}

echo "Catalog.SSL.Certificates.setRawCertificate ${CERTNAME} \"$crt\" " > $CERTDIR/zcli_${CERTFILE}.script
$ZCLI $CERTDIR/zcli_${CERTFILE}.script
if [ $? -ne 0 ]; then
  echo "Catalog.SSL.Certificates.importCertificate ${CERTNAME} { private_key: \"$key\", public_cert: \"$crt\" }" > $CERTDIR/zcli_${CERTFILE}.script
  $ZCLI $CERTDIR/zcli_${CERTFILE}.script
fi

echo "Done!"

