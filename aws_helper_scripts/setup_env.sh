#!/bin/bash 
# Helper script that wrap aws commands

. $(dirname $0)/aws_common.sh

[ -z "$AWS_PROFILE" ] && {
    echo -n "No profile configured. Please enter a profile name so one is created (or Ctrl-C to cancel): "
    read profile
    aws --profile $profile configure
    sed -i bak "s/^AWS_PROFILE=$/AWS_PROFILE=$profile/g" $(dirname $0)/aws_common.sh
    echo "Profile saved. Please run this script one more time">&2
    exit 0
} 

