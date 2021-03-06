#!/bin/bash

function string_join { local IFS="$1"; shift; echo "$*"; }

# php conf
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
    -e "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" \
    -e "s/^memory_limit.*/memory_limit = ${PHP_MEMORY_LIMIT}/" \
    -e "s/^;date\.timezone.*/date.timezone = $(echo ${PHP_TIME_ZONE} | sed -e 's/\//\\\//g')/" /etc/php/5.6/apache2/php.ini

# Add  MAILTO to cron if not exist
if [ $(cat /etc/crontab | grep ^MAILTO | wc -l) -eq 0 ]; then
	sed -i "$(grep -n ^PATH /etc/crontab | grep -Eo '^[^:]+') a MAILTO=\"${SERVER_MAIL}\"" /etc/crontab
fi

# setup apache
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
if [ ! -d /var/www/logs ]; then
	mkdir -p /var/www/logs
fi
sed -ri -e "s~/var/log/apache2~/var/www/logs~" /etc/logrotate.d/apache2
sed -ri -e "s~daily~weekly~" -e "s~rotate [0-9]+~rotate 12~" /etc/logrotate.d/apache2
sed -ri -e "s~missingok~missingok\n\tsize 10M~" /etc/logrotate.d/apache2

usermod -u ${WORKER_UID} www-data
groupmod -g ${WORKER_UID} www-data

# Setup default vhost if no configuration in /var/www/conf/apache2
if [ ! -d /var/www/conf/apache2 ]; then
	mkdir -p /var/www/conf/apache2
fi
vhosts_total=$(find /var/www/conf/apache2 -name "*.vhost" | wc -l)
if [ $vhosts_total -eq 0 ]; then
	cp -f /etc/apache2/templates/default.* /var/www/conf/apache2/
fi
# Setup default certificates if not exists
if [ ! -d /var/www/conf/certificates ]; then
	mkdir -p /var/www/conf/certificates
fi
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

chown -R ${WORKER_UID} ${DATA_VOLUME_WWWW}/conf/apache2 ${DATA_VOLUME_WWWW}/logs ${DATA_VOLUME_WWWW}/conf/certificates

source /etc/apache2/envvars
exec apache2 -D FOREGROUND