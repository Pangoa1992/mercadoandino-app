#!/bin/bash
# Operacion 04 - CodeDeploy (ejecutar desde la carpeta del proyecto en AWS CloudShell)
export ART=mercadoandino-artifacts-wpa-1627
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://$ART
aws deploy create-application --application-name mercadoandino-app --compute-platform Server
aws deploy push --application-name mercadoandino-app --s3-location s3://$ART/app-v1.zip --source .
aws deploy create-deployment-group \
  --application-name mercadoandino-app \
  --deployment-group-name dg-mercadoandino \
  --service-role-arn arn:aws:iam::$ACCOUNT_ID:role/LabRole \
  --auto-scaling-groups asg-mercadoandino \
  --deployment-config-name CodeDeployDefault.AllAtOnce
aws deploy create-deployment \
  --application-name mercadoandino-app \
  --deployment-group-name dg-mercadoandino \
  --s3-location bucket=$ART,key=app-v1.zip,bundleType=zip
