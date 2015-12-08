#!/bin/bash
# Just a silly wrapper on ec2 describe-instances, to test that the configuration set up works ok 

. $(dirname $0)/aws_common.sh
check_if_configured

$AWS_CLI ec2 describe-instances
