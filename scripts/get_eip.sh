#!/bin/bash

function osrelease () {
    OS=`cat /etc/os-release | grep '^NAME=' |  tr -d \" | sed 's/\n//g' | sed 's/NAME=//g'`
    if [ "$OS" == "Ubuntu" ]; then
        echo "Ubuntu"
    elif [ "$OS" == "Amazon Linux AMI" ]; then
        echo "AMZN"
    elif [ "$OS" == "CentOS Linux" ]; then
        echo "CentOS"
    else
        echo "Operating System Not Found"
    fi
}

function install_awscli() {
    release=$(osrelease)
    if [ "$release" == "Ubuntu" ]; then
          which aws
          if [ "$?" -eq 1 ]; then
              echo "Installing awscli..."
              apt install awscli -y            
          else
              echo "Installed. Nothing to do."
          fi
        

    # AMZN Linux
    elif [ "$release" == "AMZN" ]; then
          which aws-describe-addresses
          if [ "$?" -eq 1 ]; then
              echo "Installing awscli..."
              pip install awscli            
          else
              echo "Installed. Nothing to do."
          fi
    # CentOS Linux
    elif [ "$release" == "CentOS" ]; then
          which aws-describe-addresses
          if [ "$?" -eq 1 ]; then
              echo "Installing awscli..."
              pip install awscli            
          else
              echo "Installed. Nothing to do."
          fi                    
    fi
}

function request_eip() {

    source /etc/profile.d/aws-apitools-common.sh
    [ -z "$EC2_HOME" ] && EC2_HOME="/opt/aws/apitools/ec2"
    export EC2_HOME

    #Install awscli program if it isn't installed.
    install_awscli

    #Create a variable to hold path to the awscli program. The name is different based on OS.
    release=$(osrelease)
    describe=""
    associate=""
    export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
    if [ "$release" == "Ubuntu" ]; then
        associate="aws ec2 associate-address --instance-id"
        describe="aws ec2 describe-addresses --region $Region --output text"
    elif [ "$release" == "AMZN" ]; then
        associate="/opt/aws/bin/ec2-associate-address --instance"
        describe="/opt/aws/bin/ec2-describe-addresses  --region $Region"
    elif [ "$release" == "CentOS" ]; then
        associate="aws ec2 associate-address --instance-id"
        describe="aws ec2 describe-addresses --region $Region --output text"
    fi

    #Check if EIP already assigned.
    ALLOC=1
    ZERO=0
    INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
    ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
    if [ "$ASSIGNED" -gt "$ZERO" ]; then
        echo "Already assigned an EIP."
        exit 0;
    fi

    $describe > query.txt
    AVAILABLE_EIPs=`$describe | wc -l`

    if [ "$AVAILABLE_EIPs" -gt "$ZERO" ]; then
        FIELD_COUNT="5"
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        echo "Running associate_eip_now"
        while read name;
        do
            EIP_ENTRY=$(echo $name | grep eni | wc -l)
            echo "EIP: $EIP_ENTRY"
            if [ "$EIP_ENTRY" -eq 1 ]; then
                echo "Already associated with an instance"
                echo ""
            else
                export EIP=`echo "$name" | sed 's/[\s]+/,/g' | awk {'print $2'}`
                if [ "$release" == "Ubuntu" ]; then
                    EIPALLOC=`echo $name | awk {'print $2'}`
                    $associate $INSTANCE_ID --allocation-id $EIPALLOC --region $Region
                elif [ "$release" == "CentOS" ]; then
                    EIPALLOC=`echo $name | awk {'print $2'}`
                    $associate $INSTANCE_ID --allocation-id $EIPALLOC --region $Region
                else
                    $associate $INSTANCE_ID $EIP --region $Region 
                fi
                exit 0
            fi
        done < query.txt
    else
        echo "None available in this Region"
    fi

    #Retry
    INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
    ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
    if ["$ASSIGNED" -eq 1]; then
        exit 0;
    fi
    while [ "$ASSIGNED" -eq "$ZERO" ]
    do
        sleep 3
        request_eip
        INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
        ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
    done
}

function call_request_eip() {
  WAIT=$(shuf -i 1-30 -n 1)
  sleep "$WAIT"
  request_eip
}

call_request_eip

