#!/usr/bin/env bash

. ./Core/init

echo "Téléchargement de l'image iso…"
MIRROR=distfiles.gentoo.org
IMAGE="install-amd64-minimal-\w*.iso"
TMP=/tmp
FILE=$(wget -4 -q http://${MIRROR}/releases/amd64/autobuilds/latest-iso.txt -O - | grep -o -e "${IMAGE}")
wget -4 -c http://${MIRROR}/releases/amd64/autobuilds/current-install-amd64-minimal/$FILE -O ${TMP}/$FILE
wget -4 -c http://${MIRROR}/releases/amd64/autobuilds/current-install-amd64-minimal/${FILE}.DIGESTS -O ${TMP}/${FILE}.DIGESTS

echo "Vérification de l'image iso…"
cd ${TMP}
try grep "$( sha512sum $FILE )" ${FILE}.DIGESTS

exit 0

