# Install Semaphore CE

## Prerequisites

Install these tools

```shell
brew install certbot kubectl helm google-cloud-sdk openssl
```

Ensure you have:

- Google Cloud Account
- A domain and permissions to create A records in that domain

## Prepare environment

1. Create a Google Project and get the Project ID

2. Create `.env` file as follows:

```shell
export GOOGLE_CLOUD_PROJECT_ID=<your-google-cloud-project-id>
export DOMAIN=<your-domain> # domain without https, e.g. "example.com"
export ZONE=us-central1-a
export GOOGLE_STATIC_IP_NAME=my-semaphore-ip
export GOOGLE_CERTIFICATE_NAME=my-semaphore-certificate
export CLUSTER_NAME=my-semaphore-cluster
export CERTS_DIR=$HOME/mycerts
```

## SSL Certs generation

You only need to create the SSL certificate for your domain.

1. Execute the following command to create the certificates. Follow on-screen instructions. You will be asked to create a DNS TXT record with a specific value. Press enter only after you have created the DNS Record.

```shell
source .env
mkdir -p "${CERTS_DIR}"
certbot certonly --manual --preferred-challenges=dns \
    -d "*.${DOMAIN}" \
    --register-unsafely-without-email \
    --work-dir "${CERTS_DIR}" \
    --config-dir "${CERTS_DIR}" \
    --logs-dir "${CERTS_DIR}"
```

2. You can now delete the DNS TXT record used for the SSL Certificate.

## Google preparation

1. Login to your Google Account

```shell
gcloud auth login
```

2. Set you current project

```shell
gcloud config set project "${GOOGLE_CLOUD_PROJECT_ID}"
```

3. Install gke auth plugin (for kubectl)

```shell
gcloud components install gke-gcloud-auth-plugin
```

## Create Google SSL Certificate

Create an SSL Certificate as follows:

```shell
gcloud compute ssl-certificates create "${GOOGLE_CERTIFICATE_NAME}" \
 --certificate="${CERTS_DIR}/live/${DOMAIN}/fullchain.pem" \
 --private-key="${CERTS_DIR}/live/${DOMAIN}/privkey.pem" \
 --project="${GOOGLE_CLOUD_PROJECT_ID}"
```

## Reserve a Public IP

1. Execute the following command to reserve a public IP:

```shell
gcloud compute addresses create "${GOOGLE_STATIC_IP_NAME}" \
    --project "${GOOGLE_CLOUD_PROJECT_ID}" \
    --global
```

2. Retrieve the generated IP with:

```shell
IP_ADDRESS=$(gcloud compute addresses describe "${GOOGLE_STATIC_IP_NAME}" \
    --project "${GOOGLE_CLOUD_PROJECT_ID}" \
    --global \
    --format='get(address)')
echo $IP_ADDRESS
```

3. Take note of the value

## Configure DNS

Configure your DNS by creating two A records that point to the reserved IP:
- Go to your domain provider's DNS settings
- Create A records with:
  - Record 1 (Root domain):
    - Type: A
    - Name: `@` or empty (e.g., `example.com`)
    - Value: The IP address from previous step (`$IP_ADDRESS`)
  - Record 2 (Wildcard):
    - Type: A
    - Name: `*` or `*.<your-domain>` (e.g., `*.example.com`)
    - Value: The IP address from previous step (`$IP_ADDRESS`)
- Wait for DNS propagation (typically 15-30 minutes)

You can verify DNS propagation using:
```shell
# Check root domain
dig +short "$DOMAIN"

# Check wildcard domain
dig +short "*.$DOMAIN"
```
Both commands should return the IP address you configured.

## Create Kubernetes Cluster

1. Enable K8s API

```shell
gcloud services enable container.googleapis.com --project ${GOOGLE_CLOUD_PROJECT_ID}
```

2. Create Cluster

```shell
gcloud container clusters create "${CLUSTER_NAME}" \
    --project "${GOOGLE_CLOUD_PROJECT_ID}" \
    --zone "${ZONE}" \
    --num-nodes 1 \
    --machine-type e2-custom-8-16384 \
    --network "default" \
    --subnetwork "default" \
    --enable-ip-alias \
    --cluster-version latest \
    --no-enable-master-authorized-networks
kubectl get nodes
```

3. Install the CRDs
 
```shell
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system
```

## Install Semaphore with Helm Chart

1. Execute the following command to install Semaphore. The process can take up to 20 minutes

```shell
  helm upgrade --install --debug semaphore semaphore*.tgz \
  --timeout 20m \
  --set global.domain.ip=${IP_ADDRESS} \
  --set global.domain.name="${DOMAIN}" \
  --set ingress.staticIpName="${GOOGLE_STATIC_IP_NAME}" \
  --set ingress.enabled=true \
  --set ingress.ssl.enabled=true \
  --set ingress.ssl.certName="${GOOGLE_CERTIFICATE_NAME}" \
  --set ingress.ssl.type="google"
  ```

2. Once the installation is done, the following command should appear:


```shell
=============================================================================================
Congratulations, Semaphore has been installed successfully!

To start using the app, go to https://id.<your-domain>/login

You can fetch credentials for the login running this command:

echo "Email: $(kubectl get secret root-user -n default -o jsonpath='{.data.email}' | base64 -d)"; echo "Password: $(kubectl get secret root-user -n default -o jsonpath='{.data.password}' | base64 -d)"
=============================================================================================
```

3. Execute the command shown to retrieve your username and password. For example:


```shell
$ echo "Email: $(kubectl get secret root-user -n default -o jsonpath='{.data.email}' | base64 -d)"; echo "Password: $(kubectl get secret root-user -n default -o jsonpath='{.data.password}' | base64 -d)"

Email: test@example.com
Password: qZDbuPwNQGrgVmZCU9A7
```

## Verification Steps

1. Ensure all pods are running:
```shell
kubectl get pods
```
All pods should be in `Running` state with `READY` status showing all containers ready (e.g., `2/2`).

2. Verify ingress configuration:
```shell
kubectl get ingress semaphore
```
The ingress should show the IP address you configured and no error messages.

3. Verify SSL certificate:
```shell
gcloud compute ssl-certificates describe "${GOOGLE_CERTIFICATE_NAME}"
```
The certificate should be in `ACTIVE` state.

4. Verify you can log in:
```shell
# Get the login credentials
kubectl get secret root-user -o jsonpath='{.data.email}' | base64 -d; echo
kubectl get secret root-user -o jsonpath='{.data.password}' | base64 -d; echo
```
Open `https://id.${DOMAIN}/login` in your browser and try logging in with these credentials.

## Troubleshooting

### Common Issues

1. Pods not starting
```shell
# Check node resources
kubectl describe node

# View pod events
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name> --previous
```

2. SSL Certificate issues
```shell
# Check Google certificate status
gcloud compute ssl-certificates describe "${GOOGLE_CERTIFICATE_NAME}"

# Verify DNS propagation
dig +short id.${DOMAIN}
nslookup id.${DOMAIN}
```

3. Connection issues
```shell
# Check ingress status
kubectl get ingress
kubectl get events --field-selector involvedObject.kind=Ingress

# Verify services
kubectl get svc
kubectl describe svc semaphore

# Test network connectivity
curl -v -k https://id.${DOMAIN}/health
```

4. Authentication issues
```shell
# Verify root user secret exists
kubectl get secrets | grep root-user

# Check keycloak pod status
kubectl get pods | grep keycloak
kubectl logs $(kubectl get pods -l app=keycloak -o name)
```

### Collecting Information for Support

If issues persist, create a troubleshooting information file:

```shell
# Create directory for troubleshooting info
mkdir semaphore-troubleshoot
cd semaphore-troubleshoot

# Save cluster and pod information
kubectl get pods -o wide > pods.txt
kubectl get events --sort-by='.metadata.creationTimestamp' > events.txt
kubectl describe ingress semaphore > ingress.txt
gcloud compute ssl-certificates describe "${GOOGLE_CERTIFICATE_NAME}" > ssl-cert.txt

# Save pod logs
for pod in $(kubectl get pods -o name); do
  kubectl logs $pod > ${pod#pod/}_logs.txt 2>&1
done

# Create a compressed file
tar -czf semaphore-troubleshoot.tar.gz *
```

This will create a `semaphore-troubleshoot.tar.gz` file containing all relevant troubleshooting information. You can send this file to support when reporting issues.


## Uninstall and Cleanup

To completely remove Semaphore and clean up all resources:

```shell
# Remove Semaphore installation
helm uninstall semaphore

# Delete GKE cluster
gcloud container clusters delete \
    --zone "${ZONE}" \
    "${CLUSTER_NAME}"

# Delete reserved IP address
gcloud compute addresses delete "${GOOGLE_STATIC_IP_NAME}" \
    --global

# Delete SSL certificate
gcloud compute ssl-certificates delete "${GOOGLE_CERTIFICATE_NAME}"
```

Remember to also remove the DNS records you created during installation.
