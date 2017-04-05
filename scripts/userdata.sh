#!/bin/bash
#
# Script to install nginx and populate an HTML file
# with templatized variable "WEBSERVER_MESSAGE"
#
#

# Install nginx
apt-get update -y
apt-get install nginx -y

# format disk and add it to fsmount
mkfs.ext4 /dev/xvdb
mkdir /mnt/ebs_mounted_volume
mount /dev/xvdb /mnt/ebs_mounted_volume/



# Update document root to point to mounted volume
sed -i "s/.*root \/var\/www\/html;/root \/mnt\/ebs_mounted_volume;/g" /etc/nginx/sites-enabled/default

# Restart nginx and ensure it is enabled on boot
systemctl enable nginx
systemctl restart nginx

# Fill in html file with templatized parameter
echo ${WEBSERVER_MESSAGE} > /mnt/ebs_mounted_volume/index.html

# Ensure it is mounted on start (fstab)
echo >> /etc/fstab < EOF
/dev/xvdb    /mnt/ebs_mounted_volume   ext4    defaults    0    1
EOF
