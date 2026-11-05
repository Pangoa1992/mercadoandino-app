#!/bin/bash
# Operacion 01 - Bucket seguro para las fotos (AWS CloudShell)
export BUCKET=mercadoandino-uploads-wpa-1627
aws s3 mb s3://$BUCKET --region us-east-1
aws s3api put-public-access-block --bucket $BUCKET \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
aws s3api put-bucket-tagging --bucket $BUCKET --tagging 'TagSet=[{Key=Project,Value=MercadoAndino}]'
aws s3api put-bucket-policy --bucket $BUCKET --policy file://policy.json          # solo HTTPS
aws s3api put-bucket-cors --bucket $BUCKET --cors-configuration \
  '{"CORSRules":[{"AllowedMethods":["PUT","GET"],"AllowedOrigins":["*"],"AllowedHeaders":["*"],"MaxAgeSeconds":3000}]}'
aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET --lifecycle-configuration file://lifecycle.json

# 1.6 Evidencia
echo "foto de prueba" > prueba.txt
aws s3 cp prueba.txt s3://$BUCKET/uploads/prueba.txt
aws s3 ls s3://$BUCKET --recursive --human-readable --summarize
