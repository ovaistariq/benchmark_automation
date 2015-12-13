#!/bin/bash
# Provides functions to initiate and terminate ec2 instances for a benchmark 

. $(dirname $0)/aws_common.sh
check_if_configured

benchmark_sanity_check()
{
    [ -z "$BENCHMARK_NAME" ] && die 2 "BENCHMARK_NAME not set"
    [ -z "$BENCHMARK_KEY_PAIR" ] && die 3 "BENCHMARK_KEY_PAIR not set"
    [ -z "$BENCHMARK_SUBNET_ID" ] && die 4 "BENCHMARK_SUBNET_ID not set"
    [ -z "$BENCHMARK_AZ" ] && die 5 "BENCHMARK_AZ not set"
    [ -z "$BENCHMARK_INSTANCE_0_TYPE" ] && die 6 "BENCHMARK_INSTANCE_0_TYPE not set"
}

# Inner function so no sanity check on input
# Also, 'validate' here is a basic validation that the variable are set. 
# Eventually, it would be good to check that the type is a valid ec2 instance type, that the
# ami is available for the current region, etc. 
validate_instance()
{
    instance=$1
    #since we're not currently validating the type, the next line is commented out, as, if we got this far, 
    #it means we know there is a _TYPE defined for this instance
    #type=$(eval echo \$BENCHMARK_INSTANCE_${instance}_TYPE)
    ami=$(eval echo \$BENCHMARK_INSTANCE_${instance}_AMI)
    security_groups=$(eval echo \$BENCHMARK_INSTANCE_${instance}_SECURITY_GROUPS)
    [ -z "$ami" -o -z "$security_groups" ] && die 20 "Incomplete instance ($instance)"
}

# Inner function, so no sanity check on input args
create_volume()
{
    type=$1; iops=$2; size=$3
    arg_iops="--iops $iops" # this is a hack, so that if the volume type does not support an iops spec, we don't pass it on. In those cases, set it to 0 when calling. 
    [ $iops -eq 0 ] && arg_iops=""
    $AWS_CLI ec2 create-volume \
	     --size $size \
	     --volume-type $type \
	     --availability-zone $BENCHMARK_AZ \
	     $arg_iops
}

launch_instances()
{
    benchmark_sanity_check
    test -d $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME && die 10 "$AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME already exists. It must be removed manually or by terminate_instances before launch_instances can proceed"
    mkdir -p $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME
    i=0
    instance_type=$(eval echo \$BENCHMARK_INSTANCE_${i}_TYPE)
    while [ -n "$instance_type" ]; do
	echo "Processing instance $i"
	validate_instance $i
	name=$(eval echo \$BENCHMARK_INSTANCE_${i}_NAME)
	ami=$(eval echo \$BENCHMARK_INSTANCE_${i}_AMI)
	security_groups=$(eval echo \$BENCHMARK_INSTANCE_${i}_SECURITY_GROUPS)
	enable_public_ip=$(eval echo \$BENCHMARK_INSTANCE_${i}_ENABLE_PUBLIC_IP)
	[ -n "$enable_public_ip" -a $enable_public_ip -eq 1 ] && public_addr="--associate-public-ip-address"
	$AWS_CLI ec2 run-instances \
		 --image-id "$ami" \
		 --key-name "$BENCHMARK_KEY_PAIR" \
		 --instance-type "$instance_type" \
		 --security-group-ids $security_groups \
		 --subnet-id "$BENCHMARK_SUBNET_ID" \
		 --enable-api-termination $public_addr > $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME/instance_${i}.json
	instance_id=$(grep InstanceId $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME/instance_${i}.json|head -1|awk -F: '{print $2}'|tr -d '", ')
	[ -n "$name" ] && {
	    # only set the Name tag if a name was specified
	    name=$(whoami)-${BENCHMARK_NAME}-${name}
	    $AWS_CLI ec2 create-tags --resources "$instance_id" --tags Key="Name",Value="$name"
	}
	j=0; volsuf=g; is_running=0
	volume_type=$(eval echo \$BENCHMARK_INSTANCE_${i}_VOLUME_${j}_TYPE)
	while [ -n "$volume_type" ]; do
	    echo -n "Waiting for instance to start before creating and attaching volumes"
	    while [ $is_running -eq 0 ]; do
		echo -n "."; sleep 1
		is_running=$($AWS_CLI ec2 describe-instances --instance-ids $instance_id|grep -c running)
            done
	    echo 
	    iops=$(eval echo \$BENCHMARK_INSTANCE_${i}_VOLUME_${j}_IOPS)
	    size=$(eval echo \$BENCHMARK_INSTANCE_${i}_VOLUME_${j}_SIZE)
	    create_volume $volume_type $iops $size > $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME/i${i}_volume_${j}.json
	    volume_id=$(grep VolumeId $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME/i${i}_volume_${j}.json|head -1|awk -F: '{print $2}'|tr -d '", ')
	    volume_ready=0
	    echo -n "Waiting for volume to become ready before attaching"
	    while [ $volume_ready -eq 0 ]; do
		echo -n "."; sleep 1
		volume_ready=$($AWS_CLI ec2 describe-volumes --volume-ids $volume_id|grep State|grep -c available)
            done
	    echo
	    $AWS_CLI ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device xvd$volsuf > /dev/null
	    j=$((j+1)); volsuf=$(echo $volsuf|tr 'a-z' 'b-z') # this will obviously fail if we add volume z ...
	    volume_type=$(eval echo \$BENCHMARK_INSTANCE_${i}_VOLUME_${j}_TYPE)
	done
	i=$((i+1))
	instance_type=$(eval echo \$BENCHMARK_INSTANCE_${i}_TYPE)
    done
}

# TODO: Must wait until instance is terminated before attempting to delete the volume. 
# Alternatively, waitw until volume is 'available' before attempting the delete
terminate_instances()
{
    benchmark_sanity_check
    instances=
    for instance in $(ls $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME/instance_*json); do
	    instance_id=$(grep InstanceId $instance|head -1|awk -F: '{print $2}'|tr -d '", ')
	    instances="$instance_id $instances"
    done
    $AWS_CLI ec2 terminate-instances --instance-ids $instances || die 30 "terminate-instances failed, not removing working directory. Please inspect $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME and then manually terminate the instances"
    for volume in $(ls $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME/*_volume_*json); do
	    volume_id=$(grep VolumeId $volume|head -1|awk -F: '{print $2}'|tr -d '", ')
	    echo -n "Waiting for volume $volume_id to become available before deleting it"
	    available=0
	    while [ $available -eq 0 ]; do
		echo -n "."; sleep 1
		available=$($AWS_CLI ec2 describe-volumes --volume-ids $volume_id|grep State|grep -c available)
            done
	    echo
	    $AWS_CLI ec2 delete-volume --volume-id $volume_id
    done
    rm -rf $AWS_BENCHMARKS_WORKSPACE/$BENCHMARK_NAME
}

die()
{
    rc=$1; shift
    echo $*>&2
    exit $rc
}

[ $# -ne 2 ] && {
    cat<<EOF>&2
Usage: 
  $0 <command> <file> 

Where <command> is one of launch_instances or terminate_instances, and <file> is a path to a shell script with the environment variables that define the benchmark. 

The script should be based on this example: 

BENCHMARK_NAME=tokudb_inserts
BENCHMARK_KEY_PAIR=fipar
BENCHMARK_SUBNET_ID=subnet-5371333b
BENCHMARK_AZ=us-west-2

BENCHMARK_INSTANCE_0_TYPE=t2.medium
BENCHMARK_INSTANCE_0_NAME=client
BENCHMARK_INSTANCE_0_AMI=ami-f0011a91
BENCHMARK_INSTANCE_0_SECURITY_GROUPS="sg-10a48f73 sg-10d43b54"
BENCHMARK_INSTANCE_0_ENABLE_PUBLIC_IP=1

BENCHMARK_INSTANCE_1_TYPE=t2.medium
BENCHMARK_INSTANCE_1_NAME=server
BENCHMARK_INSTANCE_1_AMI=ami-f0011a91
BENCHMARK_INSTANCE_1_SECURITY_GROUPS="sg-10a48f73"
BENCHMARK_INSTANCE_1_ENABLE_PUBLIC_IP=1
BENCHMARK_INSTANCE_1_VOLUME_0_TYPE=io1
BENCHMARK_INSTANCE_1_VOLUME_0_IOPS=1500 #set this to 0 for volume types standard and gp2
BENCHMARK_INSTANCE_1_VOLUME_0_SIZE=500

EOF
    exit
}

command=$1; file=$2
[ -f $file ] || die 254 "Could not read $file"
[ "$command" == "launch_instances" -o "$command" == "terminate_instances" ] || die 253 "Unsupported command ($command). Supported ones are launch_instances or terminate_instances"

. $file
$command
