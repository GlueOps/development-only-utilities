#!/bin/bash

set -e 


set_region() {
export AWS_REGION=$1
export AWS_DEFAULT_REGION=$1
}
# Fetch the list of Lightsail regions using AWS CLI
set_region "us-west-2"

# Fetch the list of Lightsail regions using AWS CLI
regions=$(aws lightsail get-regions --query 'regions[*].name' --output text | tr '\t' '\n')

# Convert the regions into an array
IFS=$'\n' read -r -a region_array <<< "$regions"

# Display the regions and prompt the user to select one
echo "Please select a region:"
for i in "${!region_array[@]}"; do
    printf "%d) %s\n" $((i+1)) "${region_array[i]}"
done

# Read user input
read -p "Enter the number of your choice (1-${#region_array[@]}): " choice

# Validate input
if [[ $choice -ge 1 && $choice -le ${#region_array[@]} ]]; then
    selected_region=${region_array[$((choice-1))]}
    echo "You selected: $selected_region"
    # Call set_region function with the selected region
    set_region "$selected_region"
else
    echo "Invalid choice. Please run the script again and select a valid number."
    exit 1
fi

# Rest of your script




read -p "Enter your CAPTAIN_DOMAIN: " temp_captain_domain
captain_domain=$(echo "$temp_captain_domain" | tr -d '[:space:]')



# Rest of your script using $selected_region_code

credentials_for_chisel=$(< /dev/random tr -dc 'A-Za-z0-9' | head -c 15; echo)":"$(< /dev/random tr -dc 'A-Za-z0-9' | head -c 15; echo)





# Define common parameters
# these vary by region so we assume the first one is always the cheapest
bundle_id=$(aws lightsail get-bundles --query 'bundles[0].bundleId' --output text)
blueprint_id="debian_12"  # Example: Debian 12 OS


# Get the first availability zone in the detected region
first_az=$(aws ec2 describe-availability-zones --region $AWS_REGION --query "AvailabilityZones[0].ZoneName" --output text)
if [ -z "$first_az" ]; then
    echo "No availability zone found in region $AWS_REGION. Exiting..."
    exit 1
fi

echo "Detected Region: $AWS_REGION"
echo "Using Availability Zone: $first_az"
echo "Chisel credentials: $credentials_for_chisel"
echo "Lightsail bundle_id: $bundle_id"
echo "OS: $blueprint_id"

user_data='#!/bin/bash
# Install docker

curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && sudo apt install tmux -y

# Run chisel
sudo docker run -d -p 9090:9090 -p 443:443 -p 80:80 -it jpillora/chisel server --reverse --port=9090 --auth='"'"'$credentials_for_chisel'"'"'
'

## To debug the userdata/launch script just open up a terminal in the vm and cat /var/log/cloud-init-output.log
## ref: https://aws.amazon.com/blogs/compute/create-use-and-troubleshoot-launch-scripts-on-amazon-lightsail/

# Function to create a Lightsail instance
create_instance() {
    echo "About to create instance $1"

    local instance_name=$1
    local user_data=$2  # Cloud-init user data script content

    echo "Creating instance $instance_name with cloud-init..."
    aws lightsail create-instances --instance-names "$instance_name" \
                                   --bundle-id "$bundle_id" \
                                   --blueprint-id "$blueprint_id" \
                                   --availability-zone "$first_az" \
                                   --user-data "$user_data"
                                       instance_name=$1
    #aws lightsail create-instances --instance-names "$instance_name" --bundle-id "$bundle_id" --blueprint-id "$blueprint_id" --availability-zone "$first_az"
    echo "Instance $instance_name is being created..."
}

open_firewall() {
    instance_name=$1
    echo "About to  open ports for $instance_name"

    # Open all ports
    aws lightsail open-instance-public-ports --instance-name "$instance_name" --port-info fromPort=0,toPort=65535,protocol=all
    echo "All ports have been opened for the instance $instance_name."
    
}

# Array of instances
suffixes=("exit1" "exit2")

# Loop through each suffix and perform operations
for suffix in "${suffixes[@]}"; do
    create_instance "${captain_domain}-${suffix}" "${user_data}"
done
echo "Waiting 60 seconds before continuining...."
sleep 60

# Loop through each suffix again to configure firewalls
for suffix in "${suffixes[@]}"; do
    open_firewall "${captain_domain}-${suffix}"
done


# Function to get and store the IPv4 address of an instance
declare -A ip_addresses
get_and_store_ipv4() {
    local instance_name=$1
    local ipv4_address=$(aws lightsail get-instance --instance-name "$instance_name" --query "instance.publicIpAddress" --output text)
    ip_addresses[$instance_name]=$ipv4_address
    echo "Instance $instance_name IPv4 Address: $ipv4_address"
}

# Retrieve and store IPv4 addresses for each instance
for suffix in "${suffixes[@]}"; do
    get_and_store_ipv4 "${captain_domain}-${suffix}"
done

# Function to generate Kubernetes manifest

generate_k8s_manifest() {
echo ""
echo ""
echo "Apply this manifest to your development cluster:"
echo ""
echo ""
cat <<EOF
kubectl apply -k https://github.com/FyraLabs/chisel-operator?ref=v0.3.0-alpha.2

kubectl apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: selfhosted
  namespace: chisel-operator-system
type: Opaque
stringData:
  auth: "$credentials_for_chisel"
---
apiVersion: chisel-operator.io/v1
kind: ExitNode
metadata:
  name: exit1
  namespace: chisel-operator-system
spec:
  host: "${ip_addresses["${captain_domain}-exit1"]}"
  port: 9090
  auth: selfhosted
---
apiVersion: chisel-operator.io/v1
kind: ExitNode
metadata:
  name: exit2
  namespace: chisel-operator-system
spec:
  host: "${ip_addresses["${captain_domain}-exit2"]}"
  port: 9090
  auth: selfhosted
YAML
EOF
echo ""
echo ""
}

# Generate and output the Kubernetes manifest
generate_k8s_manifest
