#!/bin/bash -e
# Bastion Bootstrapping
# authors: tonynv@amazon.com, sancard@amazon.com, ianhill@amazon.com
# NOTE: This requires GNU getopt. On Mac OS X and FreeBSD you must install GNU getopt and mod the checkos function so that it's supported


# Configuration
PROGRAM='Linux Bastion'

##################################### Functions Definitions
function checkos () {
    platform='unknown'
    unamestr=`uname`
    if [[ "${unamestr}" == 'Linux' ]]; then
        platform='linux'
    else
        echo "[WARNING] This script is not supported on MacOS or FreeBSD"
        exit 1
    fi
    echo "${FUNCNAME[0]} Ended"
}

function setup_environment_variables() {
    REGION=$(curl -sq http://169.254.169.254/latest/meta-data/placement/availability-zone/)
      #ex: us-east-1a => us-east-1
    REGION=${REGION: :-1}

    ETH0_MAC=$(/sbin/ip link show dev eth0 | /bin/egrep -o -i 'link/ether\ ([0-9a-z]{2}:){5}[0-9a-z]{2}' | /bin/sed -e 's,link/ether\ ,,g')

    _userdata_file="/var/lib/cloud/instance/user-data.txt"

    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    EIP_LIST=$(grep EIP_LIST ${_userdata_file} | sed -e 's/EIP_LIST=//g' -e 's/\"//g')

    LOCAL_IP_ADDRESS=$(curl -sq 169.254.169.254/latest/meta-data/network/interfaces/macs/${ETH0_MAC}/local-ipv4s/)

    CWG=$(grep CLOUDWATCHGROUP ${_userdata_file} | sed 's/CLOUDWATCHGROUP=//g')


    export REGION ETH0_MAC EIP_LIST CWG LOCAL_IP_ADDRESS INSTANCE_ID
}

function verify_dependencies(){
    if [[ "a$(which aws)" == "a" ]]; then
      pip install awscli
    fi
    echo "${FUNCNAME[0]} Ended"
}

function usage() {
    echo "$0 <usage>"
    echo " "
    echo "options:"
    echo -e "--help \t Show options for this script"
    echo -e "--banner \t Enable or Disable Bastion Message"
    echo -e "--enable \t SSH Banner"
    echo -e "--tcp-forwarding \t Enable or Disable TCP Forwarding"
    echo -e "--x11-forwarding \t Enable or Disable X11 Forwarding"
}

function chkstatus () {
    if [[ $? -eq 0 ]]
    then
        echo "Script [PASS]"
    else
        echo "Script [FAILED]" >&2
        exit 1
    fi
}

function osrelease () {
    OS=`cat /etc/os-release | grep '^NAME=' |  tr -d \" | sed 's/\n//g' | sed 's/NAME=//g'`
    if [[ "${OS}" == "Ubuntu" ]]; then
        echo "Ubuntu"
    elif [[ "${OS}" == "Amazon Linux AMI" ]] || [[ "${OS}" == "Amazon Linux" ]]; then
        echo "AMZN"
    elif [[ "${OS}" == "CentOS Linux" ]]; then
        echo "CentOS"
    elif [[ "${OS}" == "SLES" ]]; then
        echo "SLES"
    else
        echo "Operating System Not Found"
    fi
    echo "${FUNCNAME[0]} Ended" >> /var/log/cfn-init.log
}

function setup_logs () {

    echo "${FUNCNAME[0]} Started"
    URL_SUFFIX="${URL_SUFFIX:-amazonaws.com}"

    if [[ "${release}" == "SLES" ]]; then
        curl "https://amazoncloudwatch-agent-${REGION}.s3.${REGION}.${URL_SUFFIX}/suse/amd64/latest/amazon-cloudwatch-agent.rpm" -O
        zypper install --allow-unsigned-rpm -y ./amazon-cloudwatch-agent.rpm
        rm ./amazon-cloudwatch-agent.rpm
    elif [[ "${release}" == "CentOS" ]]; then
        curl "https://amazoncloudwatch-agent-${REGION}.s3.${REGION}.${URL_SUFFIX}/centos/amd64/latest/amazon-cloudwatch-agent.rpm" -O
        rpm -U ./amazon-cloudwatch-agent.rpm
        rm ./amazon-cloudwatch-agent.rpm
    elif [[ "${release}" == "Ubuntu" ]]; then
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
        curl "https://amazoncloudwatch-agent-${REGION}.s3.${REGION}.${URL_SUFFIX}/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb" -O
        dpkg -i -E ./amazon-cloudwatch-agent.deb
        rm ./amazon-cloudwatch-agent.deb
    elif [[ "${release}" == "AMZN" ]]; then
        curl "https://amazoncloudwatch-agent-${REGION}.s3.${REGION}.${URL_SUFFIX}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm" -O
        rpm -U ./amazon-cloudwatch-agent.rpm
        rm ./amazon-cloudwatch-agent.rpm
    fi

    cat <<EOF >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "logs": {
        "force_flush_interval": 5,
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/auditd/auditd.log",
                        "log_group_name": "${CWG}",
                        "log_stream_name": "{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

    if [ -x /bin/systemctl ] || [ -x /usr/bin/systemctl ]; then
        systemctl enable amazon-cloudwatch-agent.service
        systemctl restart amazon-cloudwatch-agent.service
    else
        start amazon-cloudwatch-agent
    fi
}

function setup_os () {

    echo "${FUNCNAME[0]} Started"

    echo "Defaults env_keep += \"SSH_CLIENT\"" >> /etc/sudoers

    if [[ "${release}" == "Ubuntu" ]]; then
        user_group="ubuntu"
    elif [[ "${release}" == "CentOS" ]]; then
        user_group="centos"
    elif [[ "${release}" == "SLES" ]]; then
        user_group="users"
    else
        user_group="ec2-user"
    fi

    if [[ "${release}" == "CentOS" ]]; then
        /sbin/restorecon -v /etc/ssh/sshd_config
        systemctl restart sshd
    fi

    if [[ "${release}" == "SLES" ]]; then
        echo "0 0 * * * zypper patch --non-interactive" > ~/mycron
    elif [[ "${release}" == "Ubuntu" ]]; then
        apt-get install -y unattended-upgrades
        echo "0 0 * * * unattended-upgrades -d" > ~/mycron
    else
        echo "0 0 * * * yum -y update --security" > ~/mycron
    fi

    crontab ~/mycron
    rm ~/mycron

    echo "${FUNCNAME[0]} Ended"
}

function request_eip() {

    # Is the already-assigned Public IP an elastic IP?
    _query_assigned_public_ip

    set +e
    _determine_eip_assc_status ${PUBLIC_IP_ADDRESS}
    set -e

    if [[ ${_eip_associated} -eq 0 ]]; then
      echo "The Public IP address associated with eth0 (${PUBLIC_IP_ADDRESS}) is already an Elastic IP. Not proceeding further."
      exit 1
    fi

    EIP_ARRAY=(${EIP_LIST//,/ })
    _eip_assigned_count=0

    for eip in "${EIP_ARRAY[@]}"; do

      if [[ "${eip}" == "Null" ]]; then
        echo "Detected a NULL Value, moving on."
        continue
      fi

      # Determine if the EIP has already been assigned.
      set +e
      _determine_eip_assc_status ${eip}
      set -e
      if [[ ${_eip_associated} -eq 0 ]]; then
        echo "Elastic IP [${eip}] already has an association. Moving on."
        let _eip_assigned_count+=1
        if [[ "${_eip_assigned_count}" -eq "${#EIP_ARRAY[@]}" ]]; then
          echo "All of the stack EIPs have been assigned (${_eip_assigned_count}/${#EIP_ARRAY[@]}). I can't assign anything else. Exiting."
          exit 1
        fi
        continue
      fi

      _determine_eip_allocation ${eip}

      # Attempt to assign EIP to the ENI.
      set +e
      aws ec2 associate-address --instance-id ${INSTANCE_ID} --allocation-id  ${eip_allocation} --region ${REGION}

      rc=$?
      set -e

      if [[ ${rc} -ne 0 ]]; then

        let _eip_assigned_count+=1
        continue
      else
        echo "The newly-assigned EIP is ${eip}. It is mapped under EIP Allocation ${eip_allocation}"
        break
      fi
    done
    echo "${FUNCNAME[0]} Ended"
}

function _query_assigned_public_ip() {
  # Note: ETH0 Only.
  # - Does not distinguish between EIP and Standard IP. Need to cross-ref later.
  echo "Querying the assigned public IP"
  PUBLIC_IP_ADDRESS=$(curl -sq 169.254.169.254/latest/meta-data/public-ipv4/${ETH0_MAC}/public-ipv4s/)
}

function _determine_eip_assc_status(){
  # Is the provided EIP associated?
  # Also determines if an IP is an EIP.
  # 0 => true
  # 1 => false
  echo "Determining EIP Association Status for [${1}]"
  set +e
  aws ec2 describe-addresses --public-ips ${1} --output text --region ${REGION} 2>/dev/null  | grep -o -i eipassoc -q
  rc=$?
  set -e
  if [[ ${rc} -eq 1 ]]; then
    _eip_associated=1
  else
    _eip_associated=0
  fi

}

function _determine_eip_allocation(){
  echo "Determining EIP Allocation for [${1}]"
  resource_id_length=$(aws ec2 describe-addresses --public-ips ${1} --output text --region ${REGION} | head -n 1 | awk {'print $2'} | sed 's/.*eipalloc-//')
  if [[ "${#resource_id_length}" -eq 17 ]]; then
      eip_allocation=$(aws ec2 describe-addresses --public-ips ${1} --output text --region ${REGION}| egrep 'eipalloc-([a-z0-9]{17})' -o)
  else
      eip_allocation=$(aws ec2 describe-addresses --public-ips ${1} --output text --region ${REGION}| egrep 'eipalloc-([a-z0-9]{8})' -o)
  fi
}

function prevent_process_snooping() {
    # Prevent bastion host users from viewing processes owned by other users.
    mount -o remount,rw,hidepid=2 /proc
    awk '!/proc/' /etc/fstab > temp && mv temp /etc/fstab
    echo "proc /proc proc defaults,hidepid=2 0 0" >> /etc/fstab
    echo "${FUNCNAME[0]} Ended"
}

##################################### End Function Definitions

# Call checkos to ensure platform is Linux
checkos
# Verify dependencies are installed.
verify_dependencies
# Assuming it is, setup environment variables.
setup_environment_variables

## set an initial value
SSH_BANNER="LINUX BASTION"

# Read the options from cli input
TEMP=`getopt -o h --longoptions help,banner:,enable:,tcp-forwarding:,x11-forwarding: -n $0 -- "$@"`
eval set -- "${TEMP}"


if [[ $# == 1 ]] ; then echo "No input provided! type ($0 --help) to see usage help" >&2 ; exit 1 ; fi

# extract options and their arguments into variables.
while true; do
    case "$1" in
        -h | --help)
            usage
            exit 1
            ;;
        --banner)
            BANNER_PATH="$2";
            shift 2
            ;;
        --enable)
            ENABLE="$2";
            shift 2
            ;;
        --tcp-forwarding)
            TCP_FORWARDING="$2";
            shift 2
            ;;
        --x11-forwarding)
            X11_FORWARDING="$2";
            shift 2
            ;;
        --)
            break
            ;;
        *)
            break
            ;;
    esac
done

# BANNER CONFIGURATION
BANNER_FILE="/etc/ssh_banner"
if [[ ${ENABLE} == "true" ]];then
    if [[ -z ${BANNER_PATH} ]];then
        echo "BANNER_PATH is null skipping ..."
    else
        echo "BANNER_PATH = ${BANNER_PATH}"
        echo "Creating Banner in ${BANNER_FILE}"
        aws s3 cp "${BANNER_PATH}" "${BANNER_FILE}"  --region ${BANNER_REGION}
        if [[ -e ${BANNER_FILE} ]] ;then
            echo "[INFO] Installing banner ... "
            echo -e "\n Banner ${BANNER_FILE}" >>/etc/ssh/sshd_config
        else
            echo "[INFO] banner file is not accessible skipping ..."
            exit 1;
        fi
    fi
else
    echo "Banner message is not enabled!"
fi

#Enable/Disable TCP forwarding
TCP_FORWARDING=`echo "${TCP_FORWARDING}" | sed 's/\\n//g'`

#Enable/Disable X11 forwarding
X11_FORWARDING=`echo "${X11_FORWARDING}" | sed 's/\\n//g'`

echo "Value of TCP_FORWARDING - ${TCP_FORWARDING}"
echo "Value of X11_FORWARDING - ${X11_FORWARDING}"
if [[ ${TCP_FORWARDING} == "false" ]];then
    awk '!/AllowTcpForwarding/' /etc/ssh/sshd_config > temp && mv temp /etc/ssh/sshd_config
    echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config
fi

if [[ ${X11_FORWARDING} == "false" ]];then
    awk '!/X11Forwarding/' /etc/ssh/sshd_config > temp && mv temp /etc/ssh/sshd_config
    echo "X11Forwarding no" >> /etc/ssh/sshd_config
fi

release=$(osrelease)
if [[ "${release}" == "Operating System Not Found" ]]; then
    echo "[ERROR] Unsupported Linux Bastion OS"
    exit 1
else
    setup_os
    setup_logs
fi

prevent_process_snooping
request_eip

echo "Bootstrap complete."
