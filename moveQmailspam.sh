#!/bin/bash
# ------------------------------------------------------------------
# [José Gonçalves] <jose.goncalves@dlcproduction.ch>
#   moveQmailSpam
#       Scripts used to move all mail tagged as spam to the qmail
# 	    spam folder. 
#	    This scripts should not be used if you can change your MTA 
#	    to Dovecot. With Dovecot you can work with Sieve to do this
#       job.
# ------------------------------------------------------------------

VERSION=0.0.2
UID=$(uuidgen)
USAGE="Usage: command -dhv args"
MAIL_ADDR="root@localhost"
LOGFILE="logs.txt"
# --- History ------------------------------------------------------

# - [09.07.2017] Add - uidgenerator (lock section)
# - [08.07.2017] Add - Fix regex pattern.


# --- Options processing -------------------------------------------
if [ $# == 0 ] ; then
    echo $USAGE
    exit 1;
fi

while getopts ":d:vh" optname; do
    case "$optname" in
        "v")
            echo "Version $VERSION"
            exit 0;
            ;;
        "d")
            echo "-d argument: $OPTARG"
	        domain_name=$2
            ;;
        "h")
            echo $USAGE
            exit 0;
            ;;
        "?")
            echo "Unknown option $OPTARG"
            exit 0;
            ;;
        ":")
            echo "No argument value for option $OPTARG"
            exit 0;
            ;;
        *)
            echo "Unknown error while processing options"
            exit 0;
            ;;
    esac
done

shift $(($OPTIND - 1))

param=$1

# --- Locks -------------------------------------------------------
LOCK_FILE=/tmp/$UID.lock
if [ -f "$LOCK_FILE" ]; then
   echo "Script is already running"
   exit
fi

trap "rm -f $LOCK_FILE" EXIT
touch $LOCK_FILE

# --- Syslog ------------------------------------------------------
readonly SCRIPT_NAME=$(basename $0)

# log function send your message to stdout
log() {
  echo "$@"
  logger -p user.notice -t $SCRIPT_NAME "$@"
}

# err function send your message to stderr
err() {
  echo "$@" >&2
  logger -p user.error -t $SCRIPT_NAME "$@"
}

# Local file logs / debug
if [ -e $LOGFILE ]; then
	rm -f $LOGFILE
else
	touch $LOGFILE
fi

# --- Body --------------------------------------------------------
mailboxes=`ls /var/qmail/mailnames/$domain_name | awk '{print $1}'`

for box in $mailboxes; do
	mailbox_folder="/var/qmail/mailnames/${domain_name}/${box}/Maildir/cur/"
    spam_folder="/var/qmail/mailnames/${domain_name}/${box}/Maildir/.Spam/cur/"
    spam_list=`find ${mailbox_folder} -type f | xargs grep -E '^Subject: [* []+SPAM[] *]+' | awk -F ":" '{print $1":"$2}'`

    for line in $spam_list; do
        log "Moving $line to $spam_folder"
	    #echo "Moving $line to $spam_folder" >> $LOGFILE
        mv -v $line $spam_folder >> $LOGFILE
    done
done

# Resume job, and send mail 
cat $LOGFILE | mail -s "moveQmailSpam script --> Moving Spam [$domain_name]" ${MAIL_ADDR}

# Cleaning
unset $VERSION
unset $UID
unset $USAGE
unset $LOGFILE
unset $MAIL_ADDR
unset $domain_name
unset $spam_list
unset $spam_folder
unset $mailbox_folder

# Job done
exit 0;
# -----------------------------------------------------------------