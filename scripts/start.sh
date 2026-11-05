#!/bin/bash
cd /home/ec2-user/app
BUCKET=mercadoandino-uploads-wpa-1627 PORT=80 nohup node server.js > /var/log/mercadoandino.log 2>&1 &
