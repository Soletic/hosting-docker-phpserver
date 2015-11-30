#!/bin/bash

# Config based domain
echo "${HOST_DOMAIN_NAME}" > /etc/nullmailer/defaultdomain
echo "${HOST_DOMAIN_NAME}" > /etc/nullmailer/defaulthost
echo "${HOST_DOMAIN_NAME}" > /etc/mailname
echo 900 >  /etc/nullmailer/pausetime

echo "[nullmailer] config set !"

exit 0