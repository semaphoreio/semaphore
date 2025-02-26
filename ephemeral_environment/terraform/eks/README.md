Instruction for provisioning AWS infrastructure and installing the Semaphore app

## Prerequisites:

You must have a Route53 DNS that controls your domain.
A hosted Zone ID for your domain within Route 53 is used to create Semaphore infrastructure. Example of Zone ID: `Z05666441V6R4KFL4MJAA`

## Steps to provision infrastructure:

- Connect the aws cli to your account (run `aws configure`)

- Set up env variables
```
export ZONE_ID={zone_id}                // Z05198331K5V9MQ90PSP4
export DOMAIN={domain for semaphore}    // semaphore.testing.com
export AWS_REGION={your aws region}     // eu-north-1
```

- Run terraform apply
```
TF_VAR_aws_region=$AWS_REGION TF_VAR_route53_zone_id=$ZONE_ID TF_VAR_domain=$DOMAIN terraform apply
```

After this has been completed, terraform will output **certificate_arn** value

- `export CERT_NAME=$(terraform output ssl_cert_name)`

You should have a running EKS instance, which you can validate through the AWS UI Console.

## Installing Semaphore app:

1) Connect to the newly created k8s cluster to install semaphore: 
```
aws eks update-kubeconfig --name {name of your cluster} --region $AWS_REGION
```

2) Install necessary ambassador CRDs
```
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
```

3) Install semaphore
```
helm upgrade --install --debug semaphore semaphore_chart.tgz \
  --timeout 20m  \
  --set global.domain.name=$DOMAIN \
  --set ingress.ssl.certName=$CERT_NAME \
  --set ingress.className=alb \
  --set ssl.type=alb
```

