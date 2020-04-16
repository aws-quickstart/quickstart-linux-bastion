FROM lambci/lambda:build-python3.7


RUN mkdir pkg &&\
    curl 'https://amazoncloudwatch-agent.s3.us-east-1.amazonaws.com/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm' -o pkg/amazon-cloudwatch-agent-al.rpm && \
    curl 'https://amazoncloudwatch-agent.s3.us-east-1.amazonaws.com/centos/amd64/latest/amazon-cloudwatch-agent.rpm' -o pkg/amazon-cloudwatch-agent-centos.rpm && \
    curl 'https://amazoncloudwatch-agent.s3.us-east-1.amazonaws.com/suse/amd64/latest/amazon-cloudwatch-agent.rpm' -o pkg/amazon-cloudwatch-agent-suse.rpm && \
    curl 'https://amazoncloudwatch-agent.s3.us-east-1.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb' -o pkg/amazon-cloudwatch-agent-ubnt.deb


CMD mv pkg/* /output/
