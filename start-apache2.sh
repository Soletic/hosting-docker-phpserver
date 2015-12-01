#!/bin/bash

function string_join { local IFS="$1"; shift; echo "$*"; }

# php conf
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
    -e "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" \
    -e "s/^memory_limit.*/memory_limit = ${PHP_MEMORY_LIMIT}/" \
    -e "s/^;date\.timezone.*/date.timezone = $(echo ${PHP_TIME_ZONE} | sed -e 's/\//\\\//g')/" /etc/php5/apache2/php.ini

# setup apache template 
sed -ri -e "s/ServerName.*/ServerName ${HOST_DOMAIN_NAME}/" \
    -e "s/%HOST_DOMAIN_NAME%/${HOST_DOMAIN_NAME}/" /etc/apache2/templates/default.confsite
sed -ri "s/%HOST_DOMAIN_NAME%/${HOST_DOMAIN_NAME}/" /etc/apache2/templates/default.vhost

if [ ! -z ${SERVER_MAIL} ]; then
	sed -ri -e "s/#ServerAdmin.*/ServerAdmin ${SERVER_MAIL}/" /etc/apache2/templates/default.confsite
fi
if [ ! -z ${HOST_DOMAIN_ALIAS} ]; then
	IFS=',' read -r -a server_alias <<< "${HOST_DOMAIN_ALIAS}"
	sed -ri -e "s/#ServerAlias.*/ServerAlias $server_alias/" /etc/apache2/templates/default.confsite
fi

# Log rotate
sed -ri -e "s~/var/log/apache2~/var/www/logs~" /etc/logrotate.d/apache2
sed -ri -e "s~daily~weekly~" -e "s~rotate.*~rotate 12" /etc/logrotate.d/apache2
sed -ri -e "s~missingok~missingok\n\tsize 10M~" /etc/logrotate.d/apache2

usermod -u ${WORKER_UID} www-data
groupmod -g ${WORKER_UID} www-data

# Setup default vhost if no configuration in /var/www/conf/apache2
vhosts_total=$(find /var/www/conf/apache2 -name "*.vhost" | wc -l)
if [ $vhosts_total -eq 0 ]; then
	cp -f /etc/apache2/templates/default.* /var/www/conf/apache2/
fi
# Setup default certificates if not exists
crt_total=$(find /var/www/conf/certificates -name "${HOST_DOMAIN_NAME}.key" | wc -l)
if [ $crt_total -eq 0 ]; then
	if [ -z ${HOST_DOMAIN_ALIAS} ]; then
		openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
				-subj "/C=FR/L=Toulouse/O=Soletic/OU={WORKER_NAME}/CN=${HOST_DOMAIN_NAME}" \
				-keyout /var/www/conf/certificates/${HOST_DOMAIN_NAME}.key -out /var/www/conf/certificates/${HOST_DOMAIN_NAME}.crt
	else 
		openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
				-subj "/C=FR/L=Toulouse/O=Soletic/OU={WORKER_NAME}/CN=*.${HOST_DOMAIN_NAME}/subjectAltName=DNS.1=${HOST_DOMAIN_NAME}" \
				-keyout /var/www/conf/certificates/${HOST_DOMAIN_NAME}.key -out /var/www/conf/certificates/${HOST_DOMAIN_NAME}.crt
	fi
fi;

source /etc/apache2/envvars
exec apache2 -D FOREGROUND