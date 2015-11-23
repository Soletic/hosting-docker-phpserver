#!/bin/bash

# php conf
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
    -e "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" \
    -e "s/^memory_limit.*/memory_limit = ${PHP_MEMORY_LIMIT}/" \
    -e "s/^;date\.timezone.*/date.timezone = $(echo ${PHP_TIME_ZONE} | sed -e 's/\//\\\//g')/" /etc/php5/apache2/php.ini

# apache conf
sed -ri -e "s/ServerName.*/ServerName ${HOST_DOMAIN_NAME}/" \
    -e "s/ServerAlias.*/ServerAlias www.${HOST_DOMAIN_NAME}/" /etc/apache2/sites-enabled/000-default.conf

usermod -u ${WORKER_UID} www-data
groupmod -g ${WORKER_UID} www-data

source /etc/apache2/envvars
exec apache2 -D FOREGROUND