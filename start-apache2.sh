#!/bin/bash

# php conf
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
    -e "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" \
    -e "s/^memory_limit.*/memory_limit = ${PHP_MEMORY_LIMIT}/" \
    -e "s/^;date\.timezone.*/date.timezone = $(echo ${PHP_TIME_ZONE} | sed -e 's/\//\\\//g')/" /etc/php5/apache2/php.ini

# setup apache template 
sed -ri -e "s/ServerName.*/ServerName ${HOST_DOMAIN_NAME}/" \
    -e "s/ServerAlias.*/ServerAlias www.${HOST_DOMAIN_NAME}/" \
    -e "s/%HOST_DOMAIN_NAME%/${HOST_DOMAIN_NAME}/" /etc/apache2/templates/default.confsite

usermod -u ${WORKER_UID} www-data
groupmod -g ${WORKER_UID} www-data

# Setup default vhost if no configuration in /var/www/conf/apache2
vhosts_total=$(find /var/www/conf/apache2 -name "*.vhost" | wc -l)
if [ $vhosts_total -eq 0 ]; then
	cp -f /etc/apache2/templates/default.* /var/www/conf/apache2/
fi
# Setup default certificates if not exists
crt_total=$(find /var/www/conf/certificates -name "*.key" | wc -l)
if [ $crt_total -eq 0 ]; then
	ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /var/www/conf/certificates/default.pem
	ln -s /etc/ssl/private/ssl-cert-snakeoil.key /var/www/conf/certificates/default.key
fi;

source /etc/apache2/envvars
exec apache2 -D FOREGROUND