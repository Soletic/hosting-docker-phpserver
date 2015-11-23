FROM soletic/ubuntu
MAINTAINER Sol&TIC <serveur@soletic.org>

# Environment variable for host
ENV WORKER_NAME soletic
ENV WORKER_UID 10001
ENV HOST_DOMAIN_NAME soletic.org

# Tools system
RUN apt-get update && \
  apt-get -y install software-properties-common python-software-properties && \
  add-apt-repository -y ppa:ondrej/php5-5.6

# APACHE GIT PHP5 MYSQL CLIENT
RUN apt-get -y update && \
  apt-get -y install git apache2 libapache2-mod-php5 mysql-client php5-mysql pwgen php-apc php5-mcrypt php5-intl php5-curl && \
  echo "ServerName ${HOST_DOMAIN_NAME}" >> /etc/apache2/apache2.conf 
RUN a2enmod rewrite

# Environment variables of data
ENV DATA_VOLUME_LOGS /var/log
ENV DATA_VOLUME_WWWW /var/www
ENV DATA_VOLUME_HOME /home

# Environment variables to configure apache
ENV APACHE_SERVER_NAME ${HOST_DOMAIN_NAME}

# Environment variables to configure php
ENV PHP_TIME_ZONE "Europe/Paris"
ENV PHP_UPLOAD_MAX_FILESIZE 10M
ENV PHP_POST_MAX_SIZE 10M
ENV PHP_MEMORY_LIMIT 256M

# VOLUMES
VOLUME ["${DATA_VOLUME_HOME}", "${DATA_VOLUME_LOGS}", "${DATA_VOLUME_WWWW}" ]

# ADD FILES TO FILE SYSTEM
ADD start-apache2.sh /root/scripts/start-apache2.sh
ADD supervisord-apache2.conf /etc/supervisor/conf.d/supervisord-apache2.conf
ADD apache_default /etc/apache2/sites-available/000-default.conf

# MAKE SCRIPT EXCUTABLE
RUN chmod 755 /root/scripts/*.sh

EXPOSE 80 443