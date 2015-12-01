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
$ docker run -d -h example.org --name=example.phpserver -e WORKER_NAME=example WORKER_UID=10001 -e HOST_DOMAIN_NAME=example.org soletic/phpserver
```

* WORKER_NAME : a name without spaces and used to setup unix account
* HOST_DOMAIN_NAME : default domain name used to setup apache

#### Running options

The image define many environment variables to configure the image running :

* PHP_TIME_ZONE (default  "Europe/Paris"
* PHP_UPLOAD_MAX_FILESIZE (default 10M)
* PHP_POST_MAX_SIZE (default 10M)
* PHP_MEMORY_LIMIT (default  256M)
* WORKER_UID : system user id used to set the user id of www-data, the owner of /var/www.
* SERVER_MAIL : email used to setup admin information of certificates and vhosts
* HOST_DOMAIN_ALIAS : List of domains and subdomains as alias of default vhost

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
$ docker run -d --name=example.phpserver -e WORKER_NAME=example -e WORKER_UID=10001 -e HOST_DOMAIN_NAME=example.org -e SERVER_MAIL=admin@example.org --link example.mysql:mysql -p 20180:80 -p 20143:443 -v /path/example/www:/var/www soletic/phpserver
```

### Send mail

We use nullmailer to queue email sent by php. If you want to send email from the php server you have to precise a smtp config as env environment variable. Otherwise the mails will be stored in ```/home/mail/queue```. You will have to setup another contaier to parse this directory and send each mail.

```
$ docker run -d --name=example.phpserver -e WORKER_NAME=example -e WORKER_UID=10001 -e HOST_DOMAIN_NAME=example.org --link example.mysql:mysql -p 20180:80 -p 20143:443 -v /path/example/www:/var/www -e MAILER_SMTP=smpt.example.org:port:user:password:no:no -e SERVER_MAIL=admin@example.org soletic/phpserver
```

Example to store mail in queue folder mounted from the host

```
$ docker run -d --name=example.phpserver -e WORKER_NAME=example -e WORKER_UID=10001 -e HOST_DOMAIN_NAME=example.org --link example.mysql:mysql -p 20180:80 -p 20143:443 -v /path/example/www:/var/www -v /path/example/home/mail:/home/mail -e SERVER_MAIL=admin@example.org soletic/phpserver
```

#### How does it work ?

The script start-nullmailer.sh checks the /var/spool/nullmailer/queue every two seconds and decides to send mail (if MAILER_SMTP has been configured) or move it in /home/mail/queue (changeable with DATA_VOLUME_MAIL env variable). The script runs within supervisord to keep it running all the time.

The script will create a directory tree in $DATA_VOLUME_MAIL with 4 sub directories : queue, sent, failed, log

**Notes** : we tried to share the directory /var/spool/nullmailer/queue by mounting it as a volume, but a error occurs probably for permissions reasons (even with 777 permissions !) :

```
nullmailer-queue: Could not open temporary file for writing
nullmailer-inject: nullmailer-queue failed.
```

#### More options

* MAILER_LIMIT_QUEUE_HACK : If the app queue more than this limit in 120 seconds, the nullmailer stop to send mails and send an alert at $SERVER_MAIL (environment variable) because we guess a hack of the app sending spam mails. Default : 200. A file ${DATA_VOLUME_MAIL}/stopped is created. To start again after fixing the problem, remove this file.
* MAILER_SENDER : override the sender (From header) and move from field to Replay-To if doesn't exist. Format : <email>:<name>

## Documentation

* [nullmailer](http://www.troubleshooters.com/linux/nullmailer/#_YOUR_FIRST_STEP) : description of the package and capabilities
* [Using nullmailer with STARTTLS and SMTP-Auth](http://metz.gehn.net/2012/11/nullmailer-with-starttls/)