#!/bin/bash
# Operacion 02 - Supervision (AWS CloudShell)
TOPIC_ARN=$(aws sns create-topic --name mercadoandino-alertas --tags Key=Project,Value=MercadoAndino --query TopicArn --output text)
aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint <correo>

# 2.3 CloudWatch Agent: se envio cw-agent.json a la instancia con SSM Run Command (AWS-RunShellScript)
# 2.4 Alarma CPU > 70 % durante 5 minutos (5 periodos de 60 s, monitoreo detallado)
aws cloudwatch put-metric-alarm --alarm-name MercadoAndino-CPU-Alta \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=asg-mercadoandino \
  --statistic Average --period 60 --evaluation-periods 5 --datapoints-to-alarm 5 \
  --threshold 70 --comparison-operator GreaterThanThreshold \
  --alarm-actions $TOPIC_ARN --tags Key=Project,Value=MercadoAndino

# 2.5 Dashboard (CPU del ASG, RequestCount del ALB, BucketSizeBytes de S3)
aws cloudwatch put-dashboard --dashboard-name MercadoAndino --dashboard-body file://dashboard.json
