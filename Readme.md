# A docker image to deploy VPS as container

This docker image is a based image to create apache php server

## Install

```
$ git clone https://github.com/Soletic/hosting-docker-ubuntu.git ./ubuntu
$ git clone https://github.com/Soletic/hosting-docker-mysql.git ./mysql
$ docker build --pull -t soletic/ubuntu ./ubuntu
$ docker build -t soletic/mysql ./mysql
```

## Run the image

### Basic example

```
$ docker run -d --name=example.phpserver -e WORKER_NAME=example WORKER_UID=10001 -e HOST_DOMAIN_NAME=example.org soletic/phpserver
```

* WORKER_NAME : a name without spaces and used to setup unix account
* HOST_DOMAIN_NAME : default domain name used to setup apache

### Full lamp example with data stored by docker host

Install mysql image

```
$ git clone https://github.com/Soletic/hosting-docker-mysql.git ./mysql
$ git clone https://github.com/Soletic/hosting-docker-phpmyadmin.git ./phpmyadmin
$ docker build -t soletic/mysql ./mysql
$ docker build -t soletic/phpmyadmin ./phpmyadmin
```

And run :

```
$ mkdir -p /path/example/www/{logs,conf,html,cgi-bin}
$ mkdir -p /path/example/www/conf/{apache2,certificates}
$ echo "Default page" > /path/example/www/index.html
$ docker run -d --name=example.mysql -e WORKER_NAME=example -v /path/example/backup:/var/lib/mysql/backup -p 20136:3306 soletic/mysql
$ docker run -d --name=example.dbadmin --link example.mysql:mysql -p 20181:80 soletic/phpmyadmin
$ docker run -d --name=example.phpserver -e WORKER_NAME=example -e WORKER_UID=10001 -e HOST_DOMAIN_NAME=example.org --link example.mysql:mysql -p 20180:80 -p 20143:443 -v /path/example/www:/var/www soletic/phpserver
```

## Running options

The image define many environment variables to configure the image running :

* PHP_TIME_ZONE (default  "Europe/Paris"
* PHP_UPLOAD_MAX_FILESIZE (default 10M)
* PHP_POST_MAX_SIZE (default 10M)
* PHP_MEMORY_LIMIT (default  256M)
* WORKER_UID : system user id used to set the user id of www-data, the owner of /var/www.