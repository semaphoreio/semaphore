# Cleaning artifact buckets

The bucket cleaner is responsible for enforcing retention policy rules
for every bucket. The retention policies are a set of rules that define
how long can objects stay alive in the bucket.

For example, a retention policy might define the following:

```
scope: workflow 
path: test-results/**/*
age: 7 days
```

The above would configure the system to delete any object from the bucket
that matches the following path `workflow/**/test-results/**/*` and is older
than 7 days.

## Components of the cleaner

The bucket cleaner is a distributed system based on supervisor/worker pattern.
In this system, we have:

- A supervisor called "Scheduler" that schedules which buckets need to be cleaned up
- A worker called "Worker" which listens to the supervisor and executes the cleanup

Communication between the supervisor and the worker is done via AMQP.
The recommended setup for the system is to have one instance (in kubernetes a pod)
that runs the scheduler, and multiple instances that listen and do the work.

Diagram of communication:

```
+-----------+                    +----------+
| Scheduler | ---(rabbit)-- +--> | Worker 1 | ---> Cleans a bucket
+-----------+               |    +----------+
                            |
                            |    +----------+
                            |--> | Worker 2 | ---> Cleans a bucket
                            |    +----------+
                            |
                            |    +----------+
                            |--> | Worker 3 | ---> Cleans a bucket
                            |    +----------+
                            .
                            .
                            |    +----------+
                            +--> | Worker N | ---> Cleans a bucket
                                 +----------+
```

The scheduler can also be setup to work in a HA configuration for redundancy:

```
+-----------+                    +----------+
| Scheduler | ---(rabbit)-- +--> | Worker 1 | ---> Cleans a bucket
+-----------+   |           |    +----------+
                |           |
+-----------+   |           |    +----------+
| Scheduler | --+           |--> | Worker 2 | ---> Cleans a bucket
+-----------+               |    +----------+
                            |
                            |    +----------+
                            |--> | Worker 3 | ---> Cleans a bucket
                            |    +----------+
                            .
                            .
                            |    +----------+
                            +--> | Worker N | ---> Cleans a bucket
                                 +----------+
```

It is recommended to keep the number of workers much higher than the number of
schedulers to gain optimal performance.

For example, a production ready setup could be (2 schedulers, 10 workers).

## Operating the cleaner

Operators of the bucket cleaner need to pay attention to the number
of rabbit messages on the bucket cleaner list.

If the number of messages is increasing, the system is most likely not able to
process the cleaning fast enough. 

The recommended action is to increase the number of workers, which will 
parallelize the work.