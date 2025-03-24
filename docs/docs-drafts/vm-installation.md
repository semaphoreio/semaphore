## Prerequisites

- Domain and SSL certificate for it - same steps about creating SSL certificates for GKE can be used
- A Ubuntu machine with a public IP assigned to it, and at least 8 CPUs and 16GB of RAM.

### Example: create and connect to an Ubuntu machine on AWS

```bash
# Create security group
security_group_name="semaphore-instance-sg"
security_group_id=$(aws ec2 create-security-group \
  --group-name $security_group_name \
  --description "Security group for Semaphore instance" \
  --output text \
  --query 'GroupId')

# Configure security group to allow SSH access (just from your IP)
# and HTTP/HTTPS requests from everywhere.
ip=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 22 --cidr $ip/32
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 443 --cidr 0.0.0.0/0

# Create key pair for accessing the instance with SSH
key_name="semaphore-instance-key"
aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > $key_name.pem
chmod 600 $key_name.pem

# Run instance using key and security group created above
instance_id=$(aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --instance-type t2.2xlarge \
  --security-group-ids $security_group_id \
  --key-name $key_name \
  --count 1 \
  --associate-public-ip-address \
  --output text \
  --query 'Instances[0].InstanceId')

# Fetch the IP address for the instance
ip=$(aws ec2 describe-instances --instance-ids $instance_id \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# Once the instance is running, you can connect to it with:
ssh -i $key_name.pem ubuntu@$ip
```

### Example: create and connect to an Ubuntu machine on GCP

```bash
# Replace these values with the ones that make sense to you
instance_name=test-lpinheiro
gcp_project=semaphore2-stg
gcp_zone=us-east4-b

# Create instance
# NOTE: replace the key used in `--metadata` to use your own
gcloud compute instances create ${instance_name} \
    --zone=${gcp_zone} \
    --project=${gcp_project} \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --tags=http-server,https-server \
    --machine-type=e2-standard-8 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=64GB \
    --metadata "ssh-keys=$(whoami):$(cat ~/.ssh/id_ed25519.pub)"

# Fetch the IP of the instance created
ip=$(gcloud compute instances describe ${instance_name} --zone ${gcp_zone} --format='text(networkInterfaces.[].accessConfigs.[].natIP)' | awk -F': ' '{print $2}')

# Connect to the VM
gcloud compute ssh --zone=${gcp_zone} --project=${gcp_project} --ssh-key-file ~/.ssh/id_ed25519 ${instance_name}
```

## Installation

### 1. Install Helm

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh
```

### 2. Install k3s

```bash
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### 3. Install ambassador CRDs

```bash
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system
```

### 4. Install Semaphore chart:

```bash
helm upgrade --install --debug semaphore semaphore_chart.tgz \
  --timeout 20m \
  --set global.domain.ip=${ip} \
  --set global.domain.name=${DOMAIN} \
  --set ingress.enabled=true \
  --set ingress.ssl.enabled=true \
  --set ingress.className=traefik \
  --set ingress.ssl.type=custom \
  --set ingress.ssl.crt=$(cat cert.fullchain.cer | base64 -w 0) \
  --set ingress.ssl.key=$(cat cert.key | base64 -w 0)
```
