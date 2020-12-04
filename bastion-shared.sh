REGION="us-west-2"
CFN_TEMPLATE_URL="https://s3.amazonaws.com/lehto-bastion/templates/bastion-shared.yaml"


function usage() {
    echo "$0 <usage>"
    echo " "
    echo "options:"
    echo -e "-r <region> \t Specify AWS region for the bastion.  Defaults to the region in your AWS CLI profile."
}

function error_exit()
{
  echo "$(basename $0): ${1:-"Unknown Error"}" 1>&2
  exit 1
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

echo "This script will create shared resources for bastion hosts in AWS region '${REGION}'"

# Create Cloudformation stack bastion-shared in each region
STACK_NAME="bastion-shared"
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --region $REGION \
    --template-url $CFN_TEMPLATE_URL \
    --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
    --tags Key="environment",Value="DEV" Key="owner",Value="eric" Key="project",Value="INFRA" 
if [ "$?" != "0" ]; then
    error_exit "Exiting due to Cloudformation create-stack error"
fi

# Monitor stack creation progress
DONE=0
PREV_STATUS=0
printf "... Monitoring stack deployment"
while [ $DONE -eq 0 ]
do
    sleep 5
    CFN=$(aws cloudformation --region $REGION describe-stacks --stack-name $STACK_NAME)
    if [ "$?" != "0" ]; then
        error_exit "Exiting due to Cloudformation stack error"
    fi

    CFN_STATUS=$(echo $CFN | jq -r '.Stacks[].StackStatus')
    case $CFN_STATUS in 
        "CREATE_COMPLETE" | "ROLLBACK_COMPLETE")
            DONE=1
            ;;
        *)
            ;;
    esac
    if [ "$CFN_STATUS" != "$PREV_STATUS" ]
    then
        printf "\n    %s " $CFN_STATUS
    else
        printf "."
    fi
    PREV_STATUS=$CFN_STATUS
done
printf "\n"

exit 0
