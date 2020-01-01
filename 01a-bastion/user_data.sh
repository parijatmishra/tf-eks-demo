yum update -y
yum install figlet jq

# generate system banner
figlet "${welcome_message}" > /etc/motd
