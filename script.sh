#!/bin/bash

sudo yum update -y
sudo amazon-linux-extras enable nginx1
sudo yum clean metadata
sudo yum -y install nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "Nginx is running!!!" > /usr/share/nginx/html/index.html