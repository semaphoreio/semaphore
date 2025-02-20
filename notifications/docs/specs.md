# Specifications

User stories:

1. My team is managing 20 services. We want to get notified in our team's slack
   channel on every red build on the master branch on any of our services.

2. My team is automatically shipping every merge from the master branch to
   production. Out deployment takes around 1h. We want to get notified the
   deployment starts, and when the deployment finishes.

3. We have one big monolithic service. Every merge to the master branch is
   automatically shipped to production. We want to notify everyone in the
   company when a new release is shipped. We want to see these notifications on
   the #engineering channel on Slack.

4. We have a dedicated devops and security team that is responsible for shipping
   new releases of our software every Wednesday. We want to notify our security
   and devops teams via email on every green build on the master branch of our
   product, so that they can review and prepare for a new release. Once ready
   for delivery the master branch is promoted to the release branch, every
   release is a big event in our company, and we want to get notified on Slack.

5. Our QA team wants to get notified via Slack every time someone merges into
   the `staging` branch.

6. We run stress/security tests on our production cluster every day at 10am. We
   want to get notified on the #stress channel if something breaks so we can
   take the failure into consideration on our daily standup.

7. We automatically spin up 10 QA clusters for our QA team every morning in 8am,
   and shut it down at 6pm. We want to get notified every time the cluster is
   created or destroyed. We also want to track each deployment to these QA
   clusters.

8. We initiate a DB backup every morning at 8am from Semaphore. If everything
   goes smoothly we want to get an email notification. If something breaks, we
   want a big angry notification on our main engineering channel.

Requirements:

- All use cases from Semaphore 1.0 are covered
- Cover multiple repositories with one notification rule
- Branches, tags, and pipelines(deployments) are used for filtering events
- Optimize for large teams with many repositories

- Optimize for "automation via notifications" vs. "notification for observability"
  - Focus on use cases "I want the QA team to take over when I merge into X"
  - Don't focus on "I want to get a notification when my build passes as DM"

- Optimize for simple bootstrapping vs. DRY resources
  - Focus on "Give me a command to copy in my terminal"
  - Don't focus on "I don't want to repeat myself".
  - Repetition is better than complex generic rules.

Data necessary to cover user stories:

1. Example for product team, notify on every red master build:

``` yaml
# listing data only, YAML resource is different

projects:
 - semaphore2
 - front
 - cli
 - zebra

branches:
 - master
 - ref/tags/*

status:
 - failed
 - stopped

slack:
 - channel: "#product-hq"
   message: "{{ project.name }}/{{ branch.name }} has failed :warning:"
   endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"
```

``` bash
sem create notification product-team-failed-master-builds \
  --projects "semaphore2,front,cli,zebra" \
  --statuses "failed,stopped" \
  --branches "master,ref/tags/*" \
  --slack-channel "#product-hq" \
  --slack-message "{{ project.name }}/{{ branch.name }} has failed :warning:" \
  --slack-endpoint "https://slack.com/api/12345678-1234-5678-0000-010101010101"
```

3. Example for Semaphore 1.0 monolith:

``` yaml
projects:
 - semaphore

branches:
 - master

status:
  - failed
  - passed
  - stopped

pipelines:
  - .semahore/prod.yaml

slack:
 - channel: "#engineering"
   message: "{{ commiter.username}} deployed :tada: &mdash; [{{ commit.message }}]({{ commit.url }}) to [production]({{ pipeline.link }})"
   endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"

emails:
 - devs@example.com
 - support@example.com
```

``` bash
sem create notification semaphore-prod-deployments \
  --projects "semaphore" \
  --branches "master" \
  --pipelines ".semaphore/prod.yaml" \
  --slack-channel "#engineering" \
  --slack-message "{{ commiter.username}} deployed :tada: &mdash; [{{ commit.message }}]({{ commit.url }}) to [production]({{ pipeline.link }})"
  --slack-endpoint "https://slack.com/api/12345678-1234-5678-0000-010101010101"
  --emails "devs@example.com,support@example.com"
```

4. Devops and Secops teams (gated releases)

``` yaml
projects:
  - job-runner
  - job-runner-api
  - agent
  - bonfire

branches:
  - master

pipelines:
  - .semaphore/semaphore.yml

slack:
  - channels: "#product,#devops,#secops"
  - messsage: "New release of {{ project.name }} - {{ commit.message }}"
  - endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"

emails:
  - devops@example.com
  - secops@example.com
```

``` bash
sem create notification new-platform-component \
  --projects "job-runner,job-runner-api,agent,bonfire" \
  --branches "master" \
  --pipelines ".semaphore/semaphore.yml" \
  --slack-channels "#devops,#secops" \
  --slack-message "New release of {{ project.name }} - {{ commit.message }}"
  --slack-endpoint "https://slack.com/api/12345678-1234-5678-0000-010101010101"
  --emails "devops@example.com,secops@example.com"
```

5. QA cluster notifications (a bit more complex, needs to be done manually)

``` yaml
kind: Notification
metadata:
  name: QA Cluster Notifications

spec:
  rules:
    - name: "On QA cluster creation"
      filter:
        projects:
          - cluster-creator
        pipelines:
          - .semaphore/qa-*.yml
      notify:
        slack:
          endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"
          message: "QA cluster {{ pipeline.name }} created"
          channels:
            - "#qa"

    - name: "On new code deployed to QA cluster"
      filter:
        projects:
          - semaphore
          - job-runner
        pipelines:
          - .semaphore/qa-*.yml
      notify:
        slack:
          endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"
          message: "New code deployed to QA cluster {{ project.name }} {{ commit.message }}"
          channels:
            - "#qa"
```

6. DB backup (complex)

``` yaml
kind: Notification
metadata:
  name: Database Backup
spec:
  rules:
    - name: "On failure"
      filter:
        projects:
          - backuper
        statuses:
          - failed
          - stopped
      notify:
        slack:
          endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"
          message: "QA cluster {{ pipeline.name }} created"
          channels:
            - #db-backup

    - name: "On success"
      filter:
        projects:
          - backuper
        statuses:
          - passed
      notify:
        email:
          subject: "DB success finished"
          cc:
            - devops@example.com
```

7. Stress tests

``` yaml
kind: Notification
metadata:
  name: Stress tests
spec:
  rules:
    - name: "On kaosz start"
      filter:
        projects:
          - kaosz
        state:
          - started
      notify:
        slack:
          message: "Stress test starts"
          endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"
          channels:
            - "#stress"
        email:
          subject: "Stress test started"
          addresses:
             - devs@example.com

    - name: "On kaosz finish"
      filter:
        projects:
          - kaosz
        state:
          - finished
      notify:
        slack:
          endpoint: "https://slack.com/api/12345678-1234-5678-0000-010101010101"
          message: "Stress test finished {{ pipeline.result }} {{ pipeline.duration }}"
          channels:
            - "#stress"
```
