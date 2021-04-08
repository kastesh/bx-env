#!/bin/bash
set -e

PHPs="${1}"
PHPs_default="php71 php72 php73 php74 php80 nginx"
if [[ -z $PHPs ]]; then
    PHPs="${PHPs_default}"
fi

REPO=repodocker.office.bitrix.ru

for php in $PHPs;do
    pushd $php
    docker build . -t bx-$php
    docker tag bx-$php $REPO/bx-$php
    docker push $REPO/bx-$php
    popd
done
