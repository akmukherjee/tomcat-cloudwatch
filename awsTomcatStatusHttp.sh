#!/bin/bash

# Tomcat URL and port
TOMCAT_URL="http://localhost:8080"
# If one does not want to use a proxy
export no_proxy=169.254.169.254
# Proxy settings
PROXY_ENABLED=false
PROXY_HOST=$http_proxy
PROXY_PORT="8080"
PROXY_USERNAME="username"
PROXY_PASSWORD="password"



# Function to check if Tomcat is running
check_tomcat_status() {
  local response
  if [ "$PROXY_ENABLED" = true ]; then
    response=$(curl -s -o /dev/null -w "%{http_code}" -x "$PROXY_HOST:$PROXY_PORT" -U "$PROXY_USERNAME:$PROXY_PASSWORD" "$TOMCAT_URL")
  else
    response=$(curl -s -o /dev/null -w "%{http_code}" "$TOMCAT_URL")
  fi

  # If Tomcat returns ANY status
  if [ "$?" -eq 0 ]; then
    return 0
  else
    error_message="Curl request failed: $response"
  fi
}


# Check Tomcat status

  if check_tomcat_status; then

      echo "Tomcat is  online"
      TOMCAT_STATUS_AWS_VAL=0


  else

    echo "Tomcat is down"
    TOMCAT_STATUS_AWS_VAL=1

  fi


EC2_INSTANCE_ID="`curl http://169.254.169.254/latest/meta-data/instance-id || die \"Instance-id fetch has failed: $?\"`";
# Get the Availability Zone to retrieve the region
EC2_AZ="`curl http://169.254.169.254/latest/meta-data/placement/availability-zone || die \"Availability-zone fetch has failed: $?\"`";
# Get the AWS Region
EC2_REGION="`echo \"$EC2_AZ\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
# Get the Instance Name using AWS CLI (Ensure AWS CLI is installed at the alias path below)
alias aws='/usr/local/bin/aws'
# Retrive Instance Name using the Instance-id. (Ensure Instance has ec2 describe-tags IAM permission associated with the Instance Role
EC2_INSTANCE_NAME="`aws ec2 describe-tags --region $EC2_REGION --filters "Name=resource-id,Values=$EC2_INSTANCE_ID" "Name=key,Values=Name" --output text|cut -f5`"
# Specify the Name of the Cloudwatch Custom Metric
AWS_METRIC_NAME="TomcatUptimeActiveInstanceHttp"
# Specify the Cloudwatch Namespace
AWS_NAMESPACE="TomcatInstanceMonitoringHttp"

echo $EC2_INSTANCE_ID
# Send Custom Metrics to Cloudwatch
AWS_RESPONSE_STATUS=$(aws cloudwatch put-metric-data --namespace $AWS_NAMESPACE --metric-name $AWS_METRIC_NAME --value $TOMCAT_STATUS_AWS_VAL --unit Count --dimensions InstanceID=$EC2_INSTANCE_ID,"Instance Name"=$EC2_INSTANCE_NAME --region $EC2_REGION)
