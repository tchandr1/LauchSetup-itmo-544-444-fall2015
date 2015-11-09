#! /bin/bash 

echo "Test shell script"

./cleanup.sh

# Create db subnet grop
#aws rds create-db-subnet-group --db-subnet-group-name mp1 --db-subnet-group-description "group for mp1" --subnet-ids subnet-7afc890d subnet-faffa89f

#declare an array in bash
declare -a instanceARR

mapfile -t instanceARR < <(aws ec2 run-instances --image-id ami-5189a661 --count $1 --instance-type t2.micro --key-name itmo544-444-fall2015-surface-laptop --security-group-ids sg-3456df50 --subnet-id subnet-7afc890d --associate-public-ip-address --iam-instance-profile Name=phpdeveloperRole --user-data file://EnvironmentalSetup-itmo-544-444-fall2015/install-webserver.sh --output table | grep InstanceId | sed "s/|//g" | sed "s/ //g" | sed "s/InstanceId//g")

echo "\n"
echo ${instanceARR[@]}
echo "\n"
echo "InstanceArray printed"

aws ec2 wait instance-running --instance-ids ${instanceARR[@]}
echo “instances are running”

# Create db subnet grop
aws rds create-db-subnet-group --db-subnet-group-name mp1 --db-subnet-group-description "group for mp1" --subnet-ids subnet-7afc890d subnet-faffa89f

#Create db instance
#aws rds create-db-instance --db-name customerrecords --db-instance-identifier tch-db --db-instance-class db.t1.micro --engine MySQL --master-username controller --master-user-password ilovebunnies --publicly-accessible --allocated-storage 5 --db-subnet-group-name mp1

#aws rds wait db-instance-available --db-instance-identifier tch-db

echo "Run setup.php"
php ./EnvironmentalSetup-itmo-544-444-fall2015/setup.php

# Create Load balancer
ELBURL=(`aws elb create-load-balancer --load-balancer-name itmo544tchandr1-lb --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets subnet-7afc890d --security-groups sg-3456df50 --output=text`); echo $ELBURL

echo -e "\nFinished launching ELB and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.';sleep 1;done
echo "\n"

echo "\nRegistering instances with load balancer"

aws elb register-instances-with-load-balancer --load-balancer-name itmo544tchandr1-lb --instances ${instanceARR[@]}

echo "\nAttach health check"

aws elb configure-health-check --load-balancer-name itmo544tchandr1-lb --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

echo "Create Launch Configuration"

aws autoscaling create-launch-configuration --launch-configuration-name itmo544tchandr1-launch-config --image-id ami-5189a661 --key-name itmo544-444-fall2015-surface-laptop --security-groups sg-3456df50 --instance-type t2.micro --user-data file://EnvironmentalSetup-itmo-544-444-fall2015/install-webserver.sh --iam-instance-profile "phpdeveloperRole"

echo "Create AutoScaling Configuration"

aws autoscaling create-auto-scaling-group --auto-scaling-group-name itmo-544-tchandra-extended-auto-scaling-group-2 --launch-configuration-name itmo544tchandr1-launch-config --load-balancer-names itmo544tchandr1-lb --health-check-type ELB --min-size 3 --max-size 6 --desired-capacity 3 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier subnet-7afc890d


echo "Cloud metrics when CPU exceeds 30 percent"

aws cloudwatch put-metric-alarm --alarm-name itmo544-tchandr1-CPU30 --alarm-description "Alarm when CPU exceeds 30 percent" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold  --dimensions Name=AutoScalingGroupName,Value=itmo-544-tchandra-extended-auto-scaling-group-2 --evaluation-periods 2 --alarm-actions arn:aws:sns:us-west-2:111122223333:MyTopic --unit Percent


echo "Cloud metrics When CPU scales down to 10"

aws cloudwatch put-metric-alarm --alarm-name itmo545-tchandr1-CPU10 --alarm-description "Alarm when CPU lessens 10 percent" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 10 --comparison-operator LessThanOrEqualToThreshold  --dimensions Name=AutoScalingGroupName,Value=itmo-544-tchandra-extended-auto-scaling-group-2 --evaluation-periods 2 --alarm-actions arn:aws:sns:us-west-2:111122223333:MyTopic --unit Percent

~                                                             
