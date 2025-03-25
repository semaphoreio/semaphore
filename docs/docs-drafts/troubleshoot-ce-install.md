
## Troubleshooting guide

If you have trouble accessing your Semaphore installation follow these steps to debug your installation.

TODO: this guide is incomplete, it only shows some things you can look but not what to look for or what actions we can take for common problems

### Check Kubernetes deployments

Run the following commands to check your deployments:


```shell title="View Kubernetes deployments"
$ kubectl get deployments
NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
ambassador                             1/1     1            1           1d
artifacthub-bucketcleaner-scheduler    1/1     1            1           1d
artifacthub-bucketcleaner-worker       1/1     1            1           1d
artifacthub-internal-grpc-api          1/1     1            1           1d
artifacthub-public-grpc-api            1/1     1            1           1d
auth                                   1/1     1            1           1d
branch-hub                             1/1     1            1           1d
dashboardhub-v1alpha-public-grpc-api   1/1     1            1           1d
github-notifier-api                    1/1     1            1           1d
github-notifier-consumer               1/1     1            1           1d
guard-api                              1/1     1            1           1d
guard-authentication-api               1/1     1            1           1d
guard-consumers                        1/1     1            1           1d
guard-id-http-api                      1/1     1            1           1d
guard-instance-config                  1/1     1            1           1d
guard-organization-api                 1/1     1            1           1d
guard-user-api                         1/1     1            1           1d
hooks-processor                        1/1     1            1           1d
hooks-processor-api                    1/1     1            1           1d
hooks-receiver                         1/1     1            1           1d
job-page                               1/1     1            1           1d
loghub2-archivator                     1/1     1            1           1d
loghub2-internal-api                   1/1     1            1           1d
loghub2-public-api                     1/1     1            1           1d
monolith-hooks                         1/1     1            1           1d
monolith-repo-proxy-api                1/1     1            1           1d
monolith-sidekiq                       1/1     1            1           1d
monolith-sidekiq-web                   1/1     1            1           1d
notifications                          1/1     1            1           1d
periodic-scheduler                     1/1     1            1           1d
plumber                                1/1     1            1           1d
plumber-public                         1/1     1            1           1d
project-page                           1/1     1            1           1d
projecthub-public                      1/1     1            1           1d
projecthub-standalone-grpc             1/1     1            1           1d
projecthub-workers                     1/1     1            1           1d
public-api                             1/1     1            1           1d
public-api-gateway                     1/1     1            1           1d
rbac-api                               1/1     1            1           1d
repository-hub                         1/1     1            1           1d
scouter-api                            1/1     1            1           1d
secrethub                              1/1     1            1           1d
self-hosted-hub-agent-cleaner          1/1     1            1           1d
self-hosted-hub-internal-api           1/1     1            1           1d
self-hosted-hub-public-api             1/1     1            1           1d
semaphore-controller                   1/1     1            1           1d
ui-cache-reactor                       1/1     1            1           1d
zebra-db-worker                        1/1     1            1           1d
zebra-internal-api                     1/1     1            1           1d
zebra-message-worker                   1/1     1            1           1d
zebra-public-api                       1/1     1            1           1d
zebra-self-hosted-dispatcher           1/1     1            1           1d
```

Check the "AVAILABLE" column. All deployments should have one available deployment.

### Check failed deployments

If any of the deployments has a 0 in the "AVAILABLE" column, you can view more details with the following command:

```shell
kubectl get deployment/<deployment-name>
```

Check for any error messages or other abnormal conditions.

### Check pods

You can view the pods in a deployment with the following command:

```shell
kubectl get pods --selector=app=<deployment-name>
```

If any pods are unavailable or in a status that is not "Running" you can obtain more information about the failed pod with the following commands:

```shell
kubectl describe pod/<pod-name>
kubectl logs <pod-name>
```

Checking the logs and the pod status can help you determine the problem.
