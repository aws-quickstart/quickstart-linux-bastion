REGION="us-west-2"
GLOBAL_TEMPLATE_URL="https://s3.amazonaws.com/lehto-bastion/templates/bastion-global.yaml"
SHARED_TEMPLATE_URL="https://s3.amazonaws.com/lehto-bastion/templates/bastion-shared.yaml"


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

echo "This script will create shared resources for bastion hosts in AWS region '${REGION}'"

# Create Cloudformation stack for bastion-global
STACK_NAME="bastion-global"

aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --region $REGION \
    --template-url $GLOBAL_TEMPLATE_URL \
    --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
    --tags Key="environment",Value="DEV" Key="owner",Value="eric" Key="project",Value="INFRA" 

# STACK_NAME="bastion-shared"
# Create Cloudformation stack for bastion-shared in each region
# aws cloudformation create-stack \
#     --stack-name $STACK_NAME \
#     --region $REGION \
#     --template-url $SHARED_TEMPLATE_URL \
#     --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
#     --tags Key="environment",Value="DEV" Key="owner",Value="eric" Key="project",Value="INFRA" 

# Monitor stack creation progress
DONE=0
PREV_STATUS=0
printf "... Monitoring stack deployment"
while [ $DONE -eq 0 ]
do
    sleep 5
    CFN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME)
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
