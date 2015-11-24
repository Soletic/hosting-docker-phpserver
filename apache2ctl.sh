#!/bin/bash

if [ -f /var/www/conf/apache2.restart ]; then
	service apache2 stop
	# Supervisor restart auto :-)
	rm /var/www/conf/apache2.restart
fi
if [ -f /var/www/conf/apache2.reload ]; then
	service apache2 reload
	rm /var/www/conf/apache2.reload
fi