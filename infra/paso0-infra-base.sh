#!/bin/bash
# Paso 0 - Infraestructura base (ejecutado en AWS CloudShell, us-east-1)
# Nota: AWS no permite nombres de grupo de seguridad que empiecen con "sg-",
# por eso el GroupName es mercadoandino-sg-alb / mercadoandino-sg-app y la etiqueta Name es sg-alb / sg-app.
export AWS_DEFAULT_REGION=us-east-1
VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC Name=availability-zone,Values=us-east-1a,us-east-1b --query 'Subnets[].SubnetId' --output text)

# 1. Grupos de seguridad
SG_ALB=$(aws ec2 create-security-group --group-name mercadoandino-sg-alb --description 'sg-alb HTTP 80 desde internet' --vpc-id $VPC \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sg-alb},{Key=Project,Value=MercadoAndino}]' --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ALB --protocol tcp --port 80 --cidr 0.0.0.0/0
SG_APP=$(aws ec2 create-security-group --group-name mercadoandino-sg-app --description 'sg-app HTTP 80 solo desde sg-alb' --vpc-id $VPC \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sg-app},{Key=Project,Value=MercadoAndino}]' --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_APP --protocol tcp --port 80 --source-group $SG_ALB

# 2. Launch Template (Amazon Linux 2023, t3.micro, vockey, LabInstanceProfile, monitoreo detallado)
cat > ud.sh << 'UDEOF'
#!/bin/bash
dnf update -y
dnf install -y ruby wget nodejs amazon-cloudwatch-agent
cd /tmp
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x install
./install auto
systemctl enable --now codedeploy-agent
UDEOF
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
UD=$(base64 -w0 ud.sh)
cat > lt.json << JSON
{"ImageId":"$AMI","InstanceType":"t3.micro","KeyName":"vockey",
 "IamInstanceProfile":{"Name":"LabInstanceProfile"},"SecurityGroupIds":["$SG_APP"],
 "Monitoring":{"Enabled":true},"UserData":"$UD",
 "TagSpecifications":[{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"mercadoandino-app"},{"Key":"Project","Value":"MercadoAndino"}]},
                      {"ResourceType":"volume","Tags":[{"Key":"Project","Value":"MercadoAndino"}]}]}
JSON
aws ec2 create-launch-template --launch-template-name lt-mercadoandino --version-description v1 \
  --launch-template-data file://lt.json --tag-specifications 'ResourceType=launch-template,Tags=[{Key=Project,Value=MercadoAndino}]'

# 3. Target Group con health check en /health
TG_ARN=$(aws elbv2 create-target-group --name tg-mercadoandino --protocol HTTP --port 80 --vpc-id $VPC \
  --health-check-path /health --health-check-interval-seconds 15 --healthy-threshold-count 2 \
  --tags Key=Project,Value=MercadoAndino --query 'TargetGroups[0].TargetGroupArn' --output text)

# 4. Application Load Balancer (internet-facing, 2 AZ) + listener HTTP 80
ALB_ARN=$(aws elbv2 create-load-balancer --name alb-mercadoandino --type application --scheme internet-facing \
  --subnets $SUBNETS --security-groups $SG_ALB --tags Key=Project,Value=MercadoAndino \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN --tags Key=Project,Value=MercadoAndino

# 5. Auto Scaling Group (min 1, deseada 1, max 3, health check ELB) + target tracking CPU 50 %
aws autoscaling create-auto-scaling-group --auto-scaling-group-name asg-mercadoandino \
  --launch-template 'LaunchTemplateName=lt-mercadoandino,Version=$Latest' \
  --min-size 1 --max-size 3 --desired-capacity 1 \
  --vpc-zone-identifier "$(echo $SUBNETS | tr ' ' ',')" --target-group-arns $TG_ARN \
  --health-check-type ELB --health-check-grace-period 900 \
  --tags Key=Project,Value=MercadoAndino,PropagateAtLaunch=true
aws autoscaling put-scaling-policy --auto-scaling-group-name asg-mercadoandino --policy-name cpu50-target-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{"PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":50.0}'
aws autoscaling enable-metrics-collection --auto-scaling-group-name asg-mercadoandino --granularity 1Minute
