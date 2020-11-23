#!/bin/bash

REGION="us-west-2"
BASTION_SUFFIX="bastion"
CFN_TEMPLATE_URL="https://s3.amazonaws.com/lehto-bastion/templates/bastion.yaml"

# ----------------------------------------------------------------
# Function for exit due to fatal program error
#   Accepts 1 argument:
#     string containing descriptive error message
# ----------------------------------------------------------------
function error_exit()
{
  echo "$(basename $0): ${1:-"Unknown Error"}" 1>&2
  exit 1
}

function script_init() {
    # Useful paths
    readonly orig_cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"
    readonly script_params="$*"

    # Important to always set as we use it in the exit handler
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
}

# Echo usage if something isn't right.
usage() { 
    echo "Usage: $0 [-r <AWS region name>]" 1>&2; 
    exit 1; 
}

# function usage() {
#     echo "$0 <usage>"
#     echo " "
#     echo "options:"
#     echo -e "--help \t Show options for this script"
#     echo -e "--banner \t Enable or Disable Bastion Message"
#     echo -e "--enable \t SSH Banner"
#     echo -e "--tcp-forwarding \t Enable or Disable TCP Forwarding"
#     echo -e "--x11-forwarding \t Enable or Disable X11 Forwarding"
# }


while getopts "r:" o; do
    case "${o}" in
        r)
            REGION=${OPTARG}
            # todo: validate region else usage
            ;;
        :)  
            echo "ERROR: Option -$OPTARG requires an argument"
            usage
            ;;
        \?)
            echo "ERROR: Invalid option -$OPTARG"
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Check required switches exist
# if [ -z "${r}" ]; then
#     usage
# fi

echo "This script will create a bastion host in AWS region '${REGION}'"

# Fetch AWS IAM user name
AWS_USER=$(aws iam get-user | jq -r '.User.UserName')
echo "... found your AWS user name: ${AWS_USER}"

# Test whether bastion exists for this user
#AWS_CF_JSON=$(aws cloudformation describe-stacks --stack-name "${AWS_USER}-${BASTION_SUFFIX}") 2> /dev/null 
#if $AWS_CF_JSON; then 
    # Cloudformation stack was found
#    echo "A bastion host already exists for ${AWS_USER}. Multiple bastions are not allowed. Exiting."
#    exit
#fi

# Get my IP
MY_IP=$(curl -s 'https://api.ipify.org')
if [ -z $MY_IP ]; then
    error_exit "ERROR: Could not find your public IP address"
fi
printf "... found your IP address: %s\n" $MY_IP

# Create Cloudformation stack for bastion host
BASTION_NAME="${AWS_USER}-${BASTION_SUFFIX}"

# (re)create EC2 key pair for bastion host
printf "... (re)creating SSH key, saving to file: %s\n" $BASTION_NAME.pem
aws ec2 delete-key-pair --key-name $BASTION_NAME
EC2_KEYPAIR=$(aws ec2 create-key-pair --key-name $BASTION_NAME) > ./$BASTION_NAME.pem
EC2_KEYPAIR_ID=$(echo $EC2_KEYPAIR | jq -r '.KeyPairId')
aws ec2 create-tags --resources $EC2_KEYPAIR_ID --tags Key=environment,Value=DEV Key=owner,Value=$AWS_USER Key=expires,Value='2020-11-24 12:00:00'

# Now create the bastion host
printf "... Creating bastion host: %s\n" $BASTION_NAME
MY_BASTION=$(aws cloudformation create-stack --stack-name $BASTION_NAME --template-url $CFN_TEMPLATE_URL --parameters ParameterKey=KeyName,ParameterValue=$EC2_KEYPAIR ParameterKey=ClientCIDR,ParameterValue=$MY_IP/32 --capabilities "CAPABILITY_IAM")

#
exit 0;