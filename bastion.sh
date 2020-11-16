#!/bin/bash

REGION="us-west-2"
BASTION_SUFFIX="bastion"
CFN_TEMPLATE_URL="https://s3.amazonaws.com/lehto-bastion/templates/linux-bastion.template"

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
CFN_STACK_NAME="${AWS_USER}-${BASTION_SUFFIX}"
aws cloudformation create-stack --stack-name $CFN_STACK_NAME --template-url $CFN_TEMPLATE_URL --capabilities "CAPABILITY_IAM"

#
exit 0;