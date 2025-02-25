Instruction for provisioning AWS infrastructure and installing the Semaphore app

## Prerequisites:

You must have a Route53 DNS that controls your domain.
A hosted Zone ID for your domain within Route 53 is used to create Semaphore infrastructure. Example of Zone ID: `Z05666441V6R4KFL4MJAA`

## Steps to provision infrastructure:

- (Connect the aws cli to your accout (run `aws configure`)) - This will ask you for the access key and your region

- Run terraform apply - 
```
TF_VAR_aws_region={your aws region} TF_VAR_route53_zone_id={zone id from above} TF_VAR_domain={domain you would like to use for semaphore} terraform apply
```

Example: 
```
TF_VAR_aws_region=eu-north-1 TF_VAR_route53_zone_id=Z05666441V6R4KFL4MJAA TF_VAR_domain=semaphore.testing.click terraform apply
```
Note: The domain you want to use for the semaphore installation has to be controlled by the DNS behind the route_53_zone_id

After this has been completed, terraform will output **certificate_arn** value, something like:

`certificate_arn = "arn:aws:acm:eu-north-1:571600846979:certificate/613a44f4-e2db-4806-a706-a03ec8b8bd01"`

This arn will be needed for the next step (helm install)

At this point, you should have a running EKS instance, which you can validate through the AWS UI Console.

## Installing Semaphore app:

1) Connect to the newly created k8s cluster to install semaphore: 
```
aws eks update-kubeconfig --name {name of your cluster} --region {your aws region}
```

2) Install necessary ambassador CRDs
```
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
```

3) Install semaphore
```
helm upgrade --install --debug semaphore semaphore_chart.tgz --timeout 20m  --set global.domain.name={domain you would like to you for semaphore} --set ingress.ssl.certName={certificate arn from the previous step} --set ingress.className=alb --set ssl.type=alb
```
Example:
```
helm upgrade --install --debug semaphore semaphore_chart.tgz --timeout 20m  --set global.domain.name=semaphore.testingclick --set ingress.ssl.certName="arn:aws:acm:us-east-1:451765615567:certificate/214a60be-f242-426d-a72e-a3ecbe77980e" --set ingress.className=alb --set ssl.type=alb
```

