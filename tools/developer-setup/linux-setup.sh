#!/bin/bash

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null ;
}

# Install jq if not present
if ! command_exists jq; then
    echo "jq is not installed. Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi


# Prompt for GitHub username
read -p "Enter your GitHub username: " USERNAME

# Check if username is provided
if [ -z "$USERNAME" ]; then
    echo "No GitHub username entered. Exiting."
    exit 1
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
echo "Select a key by number:"
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
