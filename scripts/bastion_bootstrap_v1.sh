#!/bin/bash -e
# Bastion Bootstraping 
# authors: tonynv@amazon.com, sancard@amazon.com
# NOTE: This requires GNU getopt.  On Mac OS X and FreeBSD you must install GNU getopt and mod the checkos fuction so its supported


# Configuration 
PROGRAM='Linux Bastion'

##################################### Functions
function checkos () {
platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
else
   echo "[WARINING] This script is not supported on MacOS or freebsd"
   exit 1
fi
}

function usage () {
echo "$0 <usage>"
echo " "
echo "options:"
echo -e "--help \t show options for this script"
echo -e "--banner \t Bastion Message"
echo -e "--enable \t SSH Banner"
}

function chkstatus () {
if [ $? -eq 0 ]
then
  echo "Script [PASS]"
else
  echo "Script [FAILED]" >&2
  exit 1
fi
}
##################################### Functions

# Call checkos to ensure platform is Linux
checkos

## set an initial value
SSH_BANNER="LINUX BASTION"

# Read the options from cli input
TEMP=`getopt -o h:  --long help,banner:,enable: -n $0 -- "$@"`
eval set -- "$TEMP"


if [ $# == 1 ] ; then echo "No input provided! type ($0 --help) to see usage help" >&2 ; exit 1 ; fi

# extract options and their arguments into variables.
while true; do
  case "$1" in
    -h | --help)
	usage
	exit 1
	;; 
    --banner )
	BANNER_PATH="$2"; 
	shift 2 
	;;
    --enable )
	ENABLE="$2"; 
	shift 2 
	;;
    -- ) 
	break;;
    *) break ;;
  esac
done


BANNER_FILE="/etc/ssh_banner"

if [[ $ENABLE == "True" ]];then 
   if [ -z ${BANNER_PATH} ];then
     echo "BANNER_PATH is null skipping ..."
   else 
      echo "BANNER_PATH = ${BANNER_PATH}"
      echo "Creating Banner in ${BANNER_FILE}"
      echo "curl  -s ${BANNER_PATH} > ${BANNER_FILE}"
      curl  -s ${BANNER_PATH} > ${BANNER_FILE}
      echo $?
      echo "done"

  if [ $BANNER_FILE ] ;then
     echo "[INFO] Installing banner ... "
     echo -e "\n Banner ${BANNER_FILE}" >>/etc/ssh/sshd_config && service sshd restart
  
  else
     echo "[INFO] banner file is not accessable skipping ..." 
     exit 1;
  fi
   fi 
else echo "Banner message is not enabled!"
fi