STACK_NAME="bastion-shared"
CFN_TEMPLATE_URL="https://s3.amazonaws.com/lehto-bastion/templates/bastion-shared.yaml"

# Create Cloudformation stack
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --region "us-west-2" \
    --template-url $CFN_TEMPLATE_URL \
    --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
    --tags Key="environment",Value="DEV" Key="owner",Value="eric" Key="project",Value="INFRA" 

# Monitor stack creation progress
DONE=0
PREV_STATUS=0
printf "... Monitoring bastion host deployment:"
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
        printf "\n      %s " $CFN_STATUS
    else
        printf "."
    fi
    PREV_STATUS=$CFN_STATUS
done
printf "\n"

exit 0
