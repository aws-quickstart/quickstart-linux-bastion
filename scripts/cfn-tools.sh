#!/usr/bin/env bash
# AWS Reference Common Linux Tools
# authors: tonynv@amazon.com, andglenn@amazon.com
#

# Supported only while bootstrapping Amazon EC2:
#
# -Amazon Linux 2
# -Amazon Linux 2022
# -CentOS 7
# -SUSE Linux Enterprise Server 15
# -Ubuntu 20.04 & 22.04
#
#

# Configuration
#
PROGRAM='AWS Reference Linux Common Tools'

# Usage
#
# To use the functions defined here (source this file):
# Example:
#   load script into scripts
#   source quickstart-cfn-tools.source
#   # To print os type to std out
#   get_os-type
#   # to assign the os type to a variable OS
#   get_os-type OS
#


# Detects operating system type and return value
# If no variable is passed in function will print to std-out
#
qs_int_set_svc_executable() {
  if [[ $(which systemctl) ]]; then
    export qs_svc_executable="systemd"
  else
    export qs_svc_executable="sysvinit"
  fi
}

qs_int_is_svc_active() {
  case ${qs_svc_executable} in
    systemd)
      systemctl is-active --quiet ${1}.service
      ;;
    sysvinit)
      service ${1} status
      ;;
  esac
}

qs_int_service_restart() {
  case ${qs_svc_executable} in
    systemd)
      systemctl restart ${1}.service
      ;;
    sysvinit)
      service ${1} restart
      ;;
  esac
}

qs_get-ostype() {
  local __return=$1
  DETECTION_STRING="/etc/*-release"
  if [[ $(ls ${DETECTION_STRING}) ]]; then
    OS=$( cat /etc/*-release |
      grep ^ID= |awk -F= '{print $2}' |
      tr -cd [:alpha:])

    if [ "${OS}" == "ol" ]; then
      OS="rhel"
    fi
    if [ $? -eq 0 ] && [ "$__return" ]; then
      eval $__return="${OS}"
      return 0
    elif [ $OS ]; then
      echo $OS
      return 0;
    else
      echo "Unknown"
    fi
  else
    if [ "$__return" ]; then
      __return="Unknown"
      return 1
    else
      echo "Unknown"
      return 1;
    fi
  fi
}

# Returns operating system version or return 1
# If no variable is passed in function will print to std-out
#
qs_get-osversion () {
  local __return=$1
  DETECTION_STRING="/etc/*-release"
  if [[ $(ls ${DETECTION_STRING})  ]]; then
    OSLEVEL=$(cat ${DETECTION_STRING} |
      grep VERSION_ID |
      tr -d \" |
      awk -F= '{print $2}')

    if [ $? -eq 0 ] && [ "$__return" ]; then
      eval $__return="${OSLEVEL}"
      return 0
    elif [ $OS ]; then
      echo $OSLEVEL
      return 0;
    else
      echo "Unknown"
    fi
  else
    if [ "$__return" ]; then
      __return="Unknown"
      return 1
    else
      echo "Unknown"
      return 1;
    fi
  fi
}

# If python is install returns default python path
# If no variable is passed in function will print to std-out
#
qs_get-python-path() {
  local __return=$1
  # Set PYTHON_EXECUTEABLE to default python version
  if command -v python > /dev/null 2>&1; then
    PYTHON_EXECUTEABLE=$(which python)
  else
    PYTHON_EXECUTEABLE=$(which python3)
  fi

  #Return python path or return code (1)
  if [ $PYTHON_EXECUTEABLE ] && [ "$__return" ]; then
    eval $__return="${PYTHON_EXECUTEABLE}"
    return 0
  elif [ $PYTHON_EXECUTEABLE ]; then
    echo $PYTHON_EXECUTEABLE
    return 0;
  else
    echo "Python Not installed"
    return 1
  fi
}

# Relax require tty
#
qs_notty() {
  qs_get-ostype INSTANCE_OSTYPE
  qs_get-osversion INSTANCE_OSVERSION
  echo "[INFO] Relax tty requirement"
  if [ "$INSTANCE_OSTYPE" == "centos" ]; then
    sed -i -e "s/Defaults    requiretty/Defaults    \!requiretty/" /etc/sudoers
  fi
}

# Installs pip from bootstrap.pypa
#
qs_bootstrap_pip() {
  qs_notty
  echo "[INFO] Check for python/pip"
  qs_get-python-path PYTHON_EXECUTEABLE
  if [ $? -eq 0 ] ;then
    command -v pip > /dev/null 2&>1
    if [ $? -eq 1 ]; then
      curl -sS --retry 5 https://bootstrap.pypa.io/pip/2.7/get-pip.py |
        $PYTHON_EXECUTEABLE
    fi
  else
    echo $PYTHON_EXECUTEABLE
    exit 1
  fi
}

# Installs and configures cloudwatch
# Then adds /var/log/syslog to log collection
#
qs_cloudwatch_tracklog() {
  local -r __log="$@"
  cat cloudwatch_logs.stub | sed s,__LOG__,$__log,g >> /var/awslogs/etc/awslogs.conf
  qs_int_service_restart awslogs
}

# Added EPEL enabler
#
qs_enable_epel() {
  qs_get-ostype INSTANCE_OSTYPE
  qs_get-osversion INSTANCE_OSVERSION
  echo "[INFO] Enable epel-release-latest-7"
  if [ "$INSTANCE_OSTYPE" == "centos" ]; then
    yum install -y epel-release
  else
    exit 1
  fi
}

# Updates supported operating systems to latest
# or
# exit with code (1)
#
# If no variable is passed in function will print to std-out
#
qs_update-os() {
  # Assigns values to INSTANCE_OSTYPE
  qs_get-ostype INSTANCE_OSTYPE
  qs_get-osversion INSTANCE_OSVERSION

  echo "[INFO] Start OS Updates"
  if [ "$INSTANCE_OSTYPE" == "amzn" ]; then
    yum update -y
  elif [ "$INSTANCE_OSTYPE" == "ubuntu" ]; then
    apt-get update -y
  elif [ "$INSTANCE_OSTYPE" == "centos" ]; then
    yum update -y
  elif [ "$INSTANCE_OSTYPE" == "sles" ]; then
    zypper -n refresh && zypper -n update
  else
    exit 1
  fi
  echo "[INFO] Finished OS Updates"
}

# Install aws-cfn-bootstrap tools
#
qs_aws-cfn-bootstrap() {
  # Assigns values to INSTANCE_OSTYPE
  qs_get-ostype INSTANCE_OSTYPE
  qs_get-osversion INSTANCE_OSVERSION

  echo "[INSTALL aws-cfn-bootstrap tools]"
  if [[ "$INSTANCE_OSTYPE" == "amzn" && ( "$INSTANCE_OSVERSION" == "2" || "$INSTANCE_OSVERSION" == "2022" ) ]]; then
    cp scripts/opt-aws.sh /etc/profile.d/
    ln -s /opt/aws/bin/cfn-* /usr/bin/
    export PATH=$PATH:/opt/aws/bin
    yum install -y python3-pip
    if [ "$INSTANCE_OSVERSION" == "2" ]; then
      alternatives --set python /usr/bin/python3
    fi
  elif [ "$INSTANCE_OSTYPE" == "ubuntu" ]; then
    apt-get -y update
    apt-get -y install python2.7
    curl -sS https://bootstrap.pypa.io/pip/2.7/get-pip.py --output /tmp/get-pip2.7.py
    python2.7 /tmp/get-pip2.7.py
    pip2 install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
  elif [ "$INSTANCE_OSTYPE" == "centos" ]; then
    yum update -y
    qs_bootstrap_pip
    pip install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
  elif [ "$INSTANCE_OSTYPE" == "sles" ]; then
    zypper -n refresh && zypper -n update
    pip install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz
  else
    exit 1
  fi

  if [ $(which cfn-signal) ];then
    echo "[FOUND] (cfn-signal)"
  else
    echo "[ERROR] (cfn-signal) not installed!!"
    exit 1
  fi
}

qs_err() {
  touch /var/tmp/stack_failed
  echo "[FAILED] @ $1" >>/var/tmp/stack_failed
  echo "[FAILED] @ $1"
}

qs_status() {
  if [ -f /var/tmp/stack_failed ]; then
    printf 1;
    return 1
  else
    printf 0
    return 0;
  fi
}

qs_status.clean() {
  if [ -f /var/tmp/stack_failed ]; then
    echo "clean failed state"
    rm /var/tmp/stack_failed
  else
    echo "failed state not active"
  fi
}

available_functions() {
  echo "--------------------------------"
  echo "Available quickstart_functions:
    #qs_err
    #qs_status
    #qs_get-ostype
    #qs_get-osversion
    #qs_get-python-path
    #qs_bootstrap_pip
    #qs_update-os
    #qs_enable_epel
    #qs_notty
    #qs_aws-cfn-bootstrap
    #qs_cloudwatch_tracklog
    #qs_retry_command"
  echo "--------------------------------"
}

# Install dependencies
# Assigns values to INSTANCE_
#
install_dependancies() {
  qs_get-ostype INSTANCE_OSTYPE
  qs_get-osversion INSTANCE_OSVERSION


  check_cmd() {
    if hash $1 &>/dev/null; then
      echo "[INFO] Dependencies met!"
      return 0
    else
      echo "[INFO] Installing dependencies"
      return 1
    fi
  }

  if [ "$INSTANCE_OSTYPE" == "amzn" ]; then
    check_cmd curl
    [[ $? -eq 1 ]] && yum clean all && yum install -y curl || return 0

  elif [ "$INSTANCE_OSTYPE" == "ubuntu" ]; then
    check_cmd curl
    [[ $? -eq 1 ]] && apt update && apt install -y curl || return 0

  elif [ "$INSTANCE_OSTYPE" == "centos" ]; then
    check_cmd curl
    [[ $? -eq 1 ]] && yum clean && yum install -y curl || return 0

  elif [ "$INSTANCE_OSTYPE" == "sles" ]; then
    check_cmd curl
    [[ $? -eq 1 ]] && zypper -n refresh && zypper -n install curl || return 0
  else
    echo "[FAIL] : Dependencies not satisfied!"
    exit 1
  fi
}

# $1 = NumberOfRetries $2 = Command
# qs_retry_command 10 some_command.sh
# Command will retry with linear back-off
#
qs_retry_command() {
  local -r __tries="$1"; shift
  local -r __run="$@"
  local -i __backoff_delay=2

  until $__run
  do
    if (( __current_try == __tries ))
    then
      echo "Tried $__current_try times and failed!"
      return 1
    else
      echo "Retrying ...."
      sleep $((((__backoff_delay++)) + ((__current_try++))))
    fi
  done
}

# start exec
available_functions
install_dependancies
# end exec
