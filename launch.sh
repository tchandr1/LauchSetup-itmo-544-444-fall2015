#! /bin/bash


echo “LaunchSetup”

aws ec2 run-instances --image-id ami-$1 --count $2 --instance-type $3 --key-name $6 --security-group-ids  $4 --subnet-id $5 --associate-public-ip-address --user-data file://install-env.sh --debug
