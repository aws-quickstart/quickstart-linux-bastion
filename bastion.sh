#!/bin/bash

REGION="us-west-2"
BASTION_SUFFIX="bastion"
CFN_TEMPLATE_URL="https://s3.amazonaws.com/lehto-bastion/templates/bastion.yaml"
CFN_ROLE="arn:aws:iam::182548631247:role/bastion-global-cfn-role"

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
# usage() { 
#     echo "Usage: $0 [-r <AWS region name>]" 1>&2; 
#     exit 1; 
# }

function usage() {
    echo "$0 <usage>"
    echo " "
    echo "options:"
    echo -e "-r <region> \t Specify AWS region for the bastion.  Defaults to the region in your AWS CLI profile."
}

while getopts "r:" o; do
    case "${o}" in
        r)
            REGION=${OPTARG}
            # todo: validate region, else usage
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

echo "This script will create a bastion host in AWS region '${REGION}'"

# Fetch AWS IAM user name
AWS_USER=$(aws iam get-user | jq -r '.User.UserName')
echo "... found your AWS user name: ${AWS_USER}"

# Get my IP
MY_IP=$(curl -s 'https://api.ipify.org')
if [ -z $MY_IP ]; then
    error_exit "ERROR: Could not find your public IP address"
fi
printf "... found your IP address: %s\n" $MY_IP

# Create Cloudformation stack for bastion host
BASTION_NAME="${AWS_USER}-${BASTION_SUFFIX}"

# (re)create EC2 key pair for bastion host
KEYPAIR_NAME=$BASTION_NAME-$REGION
printf "... (re)creating SSH key, saving to file: %s\n" $KEYPAIR_NAME.pem
aws ec2 --region $REGION delete-key-pair --key-name $KEYPAIR_NAME
aws ec2 --region $REGION create-key-pair \
    --key-name $KEYPAIR_NAME \
    --tag-specifications 'ResourceType=key-pair,Tags=[{Key=environment,Value=DEV},{Key=owner,Value=$AWS_USER},{Key=expires,Value="2020-11-24 13:00:00"}]' \
    --query 'KeyMaterial' \
    --output text > ./$KEYPAIR_NAME.pem
chmod 600 $KEYPAIR_NAME.pem

# Now create the bastion host
printf "... Creating bastion host: %s\n" $BASTION_NAME
aws cloudformation delete-stack --stack-name $BASTION_NAME # First, delete any existing bastion host
sleep 2
MY_BASTION=$(aws cloudformation create-stack \
    --stack-name $BASTION_NAME \
    --region $REGION \
    --template-url $CFN_TEMPLATE_URL \
    --parameters ParameterKey=KeyName,ParameterValue=$KEYPAIR_NAME ParameterKey=ClientCIDR,ParameterValue=$MY_IP/32 \
    --capabilities "CAPABILITY_IAM" \
    --role-arn $CFN_ROLE \
    --on-failure DO_NOTHING)
if [ "$?" != "0" ]; then
    error_exit "Exiting due to Cloudformation create-stack error"
fi

DONE=0
PREV_STATUS=0
printf "... Monitoring bastion host deployment"
while [ $DONE -eq 0 ]
do
    sleep 5
    CFN=$(aws cloudformation --region $REGION describe-stacks --stack-name $BASTION_NAME)
    if [ "$?" != "0" ]; then
        error_exit "Exiting due to Cloudformation stack error"
    fi

    CFN_STATUS=$(echo $CFN | jq -r '.Stacks[].StackStatus')
    case $CFN_STATUS in 
        "CREATE_COMPLETE" | "CREATE_FAILED")
            DONE=1
            BASTION_INSTANCE=$(aws cloudformation --region us-west-2 describe-stack-resource --stack-name eric-bastion --logical-resource-id BastionHost | jq -r '.StackResourceDetail.PhysicalResourceId')
            BASTION_PUBLIC_IP=$(aws ec2 describe-instances --instance-id $BASTION_INSTANCE | jq -r '.Reservations[].Instances[].PublicIpAddress')
            echo "SSH command:"
            echo "ssh -i $KEYPAIR_NAME ec2-user@$BASTION_PUBLIC_IP"
            ;;
        "DELETE_IN_PROGRESS" | "ROLLBACK_COMPLETE")
            DONE=1
            ;;
        *)
            ;;
    esac
    if [ "$CFN_STATUS" != "$PREV_STATUS" ]
    then
        printf "\n    %s" $CFN_STATUS
    else
        printf "."
    fi
    PREV_STATUS=$CFN_STATUS
done
printf "\n"

exit 0