#!/bin/bash

# Config based domain
echo "${HOST_DOMAIN_NAME}" > /etc/nullmailer/defaultdomain
echo "${HOST_DOMAIN_NAME}" > /etc/nullmailer/defaulthost
echo "${HOST_DOMAIN_NAME}" > /etc/nullmailer/me
echo "${HOST_DOMAIN_NAME}" > /etc/mailname
export HELOHOST="${HOST_DOMAIN_NAME}"
echo 900 >  /etc/nullmailer/pausetime

# Mail subdirectories
dirsmail=("queue" "sent" "failed" "log")
for dirmail in "${dirsmail[@]}"; do
	if [ ! -d ${DATA_VOLUME_MAIL}/$dirmail ]; then
		mkdir -p ${DATA_VOLUME_MAIL}/$dirmail
	fi
done
chown -R ${WORKER_UID}:${WORKER_UID} ${DATA_VOLUME_MAIL}

# ##########
# Log rotate
# ##########
if [ ! -f ${DATA_VOLUME_MAIL}/log/mail.log ]; then
	touch ${DATA_VOLUME_MAIL}/log/mail.log
fi
cat > /etc/logrotate.d/nullmailer <<-EOF
			${DATA_VOLUME_MAIL}/log/mail.log {
				monthly
				missingok
				rotate 3
				compress
				delaycompress
				notifempty
				size 10M
			}
		EOF

# ##########
# Build smtp command with $MAILER_SMTP if it sets
# ##########
if [ "${MAILER_SMTP}" != "" ]; then
	# Configure smtp command
	IFS=':' read -ra smtp_parameters <<< "${MAILER_SMTP}"
	smtp_options="--insecure"
	for (( i = 0; i < ${#smtp_parameters[@]}; i++ )); do
		case "$i" in
			0)
				smtp_options="$smtp_options ${smtp_parameters[$i]}"
				;;
			1)
				smtp_options="--port=${smtp_parameters[$i]} $smtp_options"
				;;
			2)
				if [ "${smtp_parameters[$i]}" != "" ]; then
					smtp_options="--user=${smtp_parameters[$i]} $smtp_options"
				fi
				;;
			3)
				if [ "${smtp_parameters[$i]}" != "" ]; then
					smtp_options="--pass=${smtp_parameters[$i]} $smtp_options"
				fi
				;;
			*)
				;;
		esac
		case "${smtp_parameters[$i]}" in
			ssl)
				smtp_options="--ssl $smtp_options"
				;;
			starttls)
				smtp_options="--starttls $smtp_options"
				;;
			*)
				;;
		esac
	done
fi

echo "[nullmailer] config set !"
echo "[nullmailer] start waiting message"

function nullmailer_alert_hack {

	if [ ! -f ${DATA_VOLUME_MAIL}/stopped ]; then
		return;
	fi
	if [ "${SERVER_MAIL}" = "" ]; then
		return;
	fi

	local to_mail=${SERVER_MAIL} 
	local host_mail=${HOST_DOMAIN_NAME}
	local body_mail=$(cat ${DATA_VOLUME_MAIL}/stopped)
	local date_mail=$(LC_ALL=en_GB.utf8 date)
	local id_mail=$(uuidgen)
	cat > ${DATA_VOLUME_MAIL}/stopped.mail <<-EOF
				nullmailer@$host_mail
				$to_mail

				To: $to_mail
				Subject: $host_mail : problème avec les emails
				Date: $date_mail
				From: nullmailer@$host_mail
				Message-ID: <$id_mail@example.org>
				MIME-Version: 1.0
				Content-Type: text/plain; charset=utf-8
				Content-Transfer-Encoding: 8bit

				$body_mail

			EOF

	nullmailer_override_envelope ${DATA_VOLUME_MAIL}/stopped.mail
	if [ "${MAILER_SMTP}" = "" ]; then
		mv ${DATA_VOLUME_MAIL}/stopped.mail ${DATA_VOLUME_MAIL}/queue/$(date +"%s").alert
	else
		/usr/lib/nullmailer/smtp $smtp_options < ${DATA_VOLUME_MAIL}/stopped.mail
		rm ${DATA_VOLUME_MAIL}/stopped.mail
	fi
}

function nullmailer_override_envelope {
	if [ "${MAILER_SENDER}" = "" ]; then
		return;
	fi
	local mailfile=$1

	if [ ! -f $mailfile ]; then
		return;
	fi

	local sender_parameters
	IFS=':' read -ra sender_parameters <<< "${MAILER_SENDER}"

	# Move from to reply-to if no reply-to
	if [ $(cat $mailfile | grep ^Reply-To | wc -l) -eq 0 ]; then
		sed -ri -e 's/From:/Reply-To:/' $mailfile
		sed -i "$(grep -n ^Reply-To $mailfile | grep -Eo '^[^:]+') a From: contact@${HOST_DOMAIN_NAME}" $mailfile
	fi
	
	# Replace from with mailadress envelope
	if [ ${#sender_parameters[@]} -eq 2 ]; then
		sed -ri -e "s/^From.*/From: ${sender_parameters[1]} <${sender_parameters[0]}>/" $mailfile
	elif [ ${#sender_parameters[@]} -eq 1 ]; then
		sed -ri -e "s/^From.*/From: ${sender_parameters[0]}/" $mailfile
	else
		echo "[`date +"%Y-%m-%d %H:%I:%S"`][crit] Bad format for MAILER_SENDER : $MAILER_SENDER" >> ${DATA_VOLUME_MAIL}/log/mail.log
		cat > ${DATA_VOLUME_MAIL}/stopped <<-EOF
					Madame, Monsieur,

					Votre site ou application internet ${HOST_DOMAIN_NAME} est mal configurée pour envoyer des emails.
					Veuillez contacter votre hébergeur pour fixer le problème.

					Cordialement.

				EOF

		nullmailer_alert_hack
	fi

	# Replace envelope sender (the first line)
	sed -i "1s/.*/${sender_parameters[0]}/" $mailfile
}

last_queue_checking=$(date +"%s")
mails_queued_last_120s=0
while true
do
	sleep 2

	# ###### 
	# Rm older mails
	# ######
	find ${DATA_VOLUME_MAIL} -iregex "${DATA_VOLUME_MAIL}/.+/[0-9]+\..+" -type f -mtime +90 -exec rm {} \;

	# ###### 
	# Alert hack every days
	# ######
	if [ -f ${DATA_VOLUME_MAIL}/stopped ]; then
		# If file has existed for one day, we alert again and recreate it
		file_timestamp=$(stat -c %Y ${DATA_VOLUME_MAIL}/stopped)
		now_timestamp=$(date +"%s")
		if [ $(expr $(expr 3600 \* 24) - $(expr $now_timestamp - $file_timestamp)) -lt 0 ]; then
			echo "[`date +"%Y-%m-%d %H:%I:%S"`][crit] Too much mails queued. New alert sent" >> ${DATA_VOLUME_MAIL}/log/mail.log
			nullmailer_alert_hack
			# Change last access and modify date for next time
			touch -d "1 minutes ago" ${DATA_VOLUME_MAIL}/stopped
		fi
		mails_queued_last_120s=0
		continue
	fi

	# ###### 
	# Check if app hasn't been hacked and send too much mails
	# ######
	mails_queued=$(find /var/spool/nullmailer/queue -iregex '/var/spool/nullmailer/queue/.+\..+' | wc -l)
	mails_queued_last_120s=$(expr $mails_queued + $mails_queued_last_120s)
	now_queue_checking=$(date +"%s")
	timespan_queue_checking=$(expr $now_queue_checking - $last_queue_checking)
	if [ $timespan_queue_checking -gt 120 ] && [ $mails_queued_last_120s -gt ${MAILER_LIMIT_QUEUE_HACK} ]; then
		echo "[`date +"%Y-%m-%d %H:%I:%S"`][crit] Too much mails queued : $mails_queued_last_120s / Hack ???" >> ${DATA_VOLUME_MAIL}/log/mail.log
		cat > ${DATA_VOLUME_MAIL}/stopped <<-EOF
					Madame, Monsieur,

					Votre site ou application internet fonctionnant sous le nom de domaine ${HOST_DOMAIN_NAME} 
					a envoyé plus de $mails_queued_last_120s mails dans les deux dernières minutes et dépassant 
					la limite autorisée de ${MAILER_LIMIT_QUEUE_HACK} mails.

					Nous vous rappellons que l'envoi de lettres d'informations ou mailing n'est pas autorisé. 
					Si vous n'êtes pas dans ce cas, il est possible que votre site internet rencontre un problème 
					de sécurité et qu'un pirate l'utilise pour envoyer des emails en masse. Veuillez contacter 
					votre développeur ou webmaster pour fixer le problème.

					En attendant, l'envoi des emails a été coupé. Une fois le problème résolu, merci de contacter
					votre hébergeur pour réactiver les envois.

					Cordialement.

				EOF

		nullmailer_alert_hack
		continue
	fi
	if [ $timespan_queue_checking -gt 120 ]; then
		last_queue_checking=$(date +"%s")
	fi

	# #######
	# Move or send queued files
	# To avoid problem with mail queuing, we move only mails whose size will not change during 0.1 seconds
	#######
	shopt -s nullglob
	mails=(/var/spool/nullmailer/queue/*)
	for mailfile in "${mails[@]}"; do
		mailsize=$(du -k $mailfile | cut -f 1)
		sleep 0.1
		mailsize2=$(du -k $mailfile | cut -f 1)
		if [ $mailsize -eq $mailsize2 ]; then
			# Change sender
			nullmailer_override_envelope $mailfile
			# Send/Move
			if [ "${MAILER_SMTP}" = "" ]; then
				# Move the home mail queue
				mv $mailfile ${DATA_VOLUME_MAIL}/queue/$(basename $mailfile)
				chown -R ${WORKER_UID}:${WORKER_UID} ${DATA_VOLUME_MAIL}/queue/$(basename $mailfile)
			else
				# Send mail
				cmd="/usr/lib/nullmailer/smtp $smtp_options < $mailfile"
				eval "$( (/usr/lib/nullmailer/smtp $smtp_options < $mailfile && exitcode=$? >&2 ) 2> >(errorlog=$(cat); typeset -p errorlog) > >(stdoutlog=$(cat); typeset -p stdoutlog); exitcode=$?; typeset -p exitcode )"
				#errorlog=$( { /usr/lib/nullmailer/smtp $smtp_options $smtp_options < $mailfile; } 2>&1 )
				if [ $exitcode -gt 0 ]; then
					echo "[`date +"%Y-%m-%d %H:%I:%S"`] $cmd" >> ${DATA_VOLUME_MAIL}/log/mail.log
					echo "[`date +"%Y-%m-%d %H:%I:%S"`][failed] $errorlog" >> ${DATA_VOLUME_MAIL}/log/mail.log
					mv $mailfile ${DATA_VOLUME_MAIL}/failed/$(basename $mailfile)
				else 
					echo "[`date +"%Y-%m-%d %H:%I:%S"`] $cmd" >> ${DATA_VOLUME_MAIL}/log/mail.log
					echo "[`date +"%Y-%m-%d %H:%I:%S"`][done] $stdoutlog" >> ${DATA_VOLUME_MAIL}/log/mail.log
					mv $mailfile ${DATA_VOLUME_MAIL}/sent/$(basename $mailfile)
				fi
			fi
		fi
	done

done

# Unexpected because must always run
exit 1