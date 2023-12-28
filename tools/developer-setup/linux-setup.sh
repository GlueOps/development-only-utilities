#!/bin/bash
set -e
# Prompt for GitHub username
echo ""
echo ""
read -p "Enter your GitHub username: " USERNAME

# Check if username is provided
if [ -z "$USERNAME" ]; then
    echo "No GitHub username entered. Exiting."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null ;
}

# Install jq if not present
if ! command_exists jq; then
    echo "jq is not installed. Installing jq..."
    sudo apt-get update -qq > /dev/null && sudo apt-get install -qq -y jq > /dev/null
fi


URL="https://api.github.com/users/$USERNAME/keys"

# Fetch the SSH keys
readarray -t KEYS < <(curl -s "$URL" | jq -r '.[].key')

# Check if keys are available
if [ ${#KEYS[@]} -eq 0 ]; then
    echo "No keys found for user $USERNAME."
    exit 1
fi

# Display keys and let user select one
echo -e "\n\nPlease select the public SSH key you want to use to authenticate with this node:\n"
for i in "${!KEYS[@]}"; do
    echo "$((i+1))) ${KEYS[$i]}"
done

read -p "Enter choice: " choice
choice=$((choice-1))

# Validate input
if [ "$choice" -lt 0 ] || [ "$choice" -ge "${#KEYS[@]}" ]; then
    echo "Invalid choice"
    exit 1
fi

echo -e "\n\nEverything is now getting setup. This process will take a few minutes...\n\n"

SELECTED_KEY="${KEYS[$choice]}"

# Create user glueops
sudo adduser --disabled-password --gecos "" glueops

# Create .ssh directory for glueops
sudo mkdir -p /home/glueops/.ssh
sudo chmod 700 /home/glueops/.ssh

# Add SSH key to glueops's authorized_keys
echo "$SELECTED_KEY" | sudo tee /home/glueops/.ssh/authorized_keys > /dev/null
sudo chmod 600 /home/glueops/.ssh/authorized_keys
sudo chown -R glueops:glueops /home/glueops/.ssh

# Give glueops sudo access without a password
echo "glueops ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/glueops > /dev/null

echo "User glueops created with selected SSH key and passwordless sudo access."

echo "Installing other requirements now"

curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && sudo apt-get update && sudo apt install tmux jq -y && sudo apt-get clean
#export DEBIAN_FRONTEND=noninteractive
#sudo apt-get -s dist-upgrade | grep "^Inst" | grep -i securi | awk -F " " {'print $2'} | xargs sudo apt-get install -y
sudo groupadd -f docker
sudo usermod -aG docker glueops
echo 'fs.inotify.max_user_instances=1024' | sudo tee -a /etc/sysctl.conf
echo 1024 | sudo tee /proc/sys/fs/inotify/max_user_instances
curl https://raw.githubusercontent.com/GlueOps/development-only-utilities/main/tools/developer-setup/.glueopsrc --output /home/glueops/.glueopsrc
echo "source /home/glueops/.glueopsrc" >> /home/glueops/.bashrc
sudo chown -R glueops:glueops /home/glueops
# disables the password for the current user (ex. root/admin/ubuntu users)
sudo passwd -d $USER
server_ip=$(echo $SSH_CONNECTION | awk '{print $3}')
echo -e "\n\n\n\n\nThis machine is now being restarted and will disconnect your session. \n\n"
echo -e "Please login with 'ssh glueops@$server_ip' using the SSH Key you selected earlier. \n\n"
sudo reboot
