#!/bin/bash
set -e
# Prompt for GitHub username

echo -e "\n\nEverything is now getting setup. This process will take a few minutes...\n\n"

# Create user glueops
sudo adduser --disabled-password --gecos "" glueops

# Create .ssh directory for glueops
sudo mkdir -p /home/glueops/.ssh
sudo chmod 700 /home/glueops/.ssh

sudo touch /home/glueops/.ssh/authorized_keys 
sudo chmod 600 /home/glueops/.ssh/authorized_keys
sudo chown -R glueops:glueops /home/glueops/.ssh

# Give glueops sudo access without a password
echo "glueops ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/glueops > /dev/null

echo "Installing other requirements now"

curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && sudo apt-get update && sudo apt install tmux jq figlet -y && sudo apt-get clean
#export DEBIAN_FRONTEND=noninteractive
#sudo apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | awk -F " " {'print $2'} | xargs sudo apt-get install -y
sudo groupadd -f docker
sudo usermod -aG docker glueops
echo 'fs.inotify.max_user_instances=1024' | sudo tee -a /etc/sysctl.conf
echo 1024 | sudo tee /proc/sys/fs/inotify/max_user_instances
sudo curl https://raw.githubusercontent.com/GlueOps/development-only-utilities/main/tools/developer-setup/.glueopsrc --output /home/glueops/.glueopsrc
echo "source /home/glueops/.glueopsrc" | sudo tee -a /home/glueops/.bashrc
sudo chown -R glueops:glueops /home/glueops
# disables the password for the current user (ex. root/admin/ubuntu users)
sudo passwd -d $USER
server_ip=$(echo $SSH_CONNECTION | awk '{print $3}')
echo ""
echo ""
sudo figlet GlueOps | sudo tee /etc/motd
echo -e "\n\n\n\n\nThis machine is now being restarted and will disconnect your session. \n\n"

sudo reboot
