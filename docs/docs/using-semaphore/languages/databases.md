---
description: Database access configuration
sidebar_position: 0
---

# Databases

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This page explains how to use databases and other services inside the CI environment.

## Overview

Starting databases and service in [Linux environments](../../reference/os-ubuntu) is easy with the [`sem-service`](../../reference/toolbox#sem-service) tool. Once started, create users, and tables, and populate the database with data so you can run your test suite.

### Postgres {#postgres}

You can start a PostgreSQL service with:

```shell
sem-service start postgres
```

To create users in PostgreSQL:

```shell
# normal user
psql -U postgres -h localhost -c "CREATE USER developer WITH PASSWORD 'developer';"

# admin user
psql -U postgres -h localhost -c "CREATE USER developer WITH PASSWORD 'developer';"
psql -U postgres -h localhost -c "ALTER USER developer WITH SUPERUSER;"
```

You can also create extensions to expand the capabilities of the database with:

```shell
psql -U postgres -h localhost -c "CREATE EXTENSION \"uuid-ossp\""
```

### MySQL {#mysql}

To start a MySQL database use:

```shell
sem-service start mysql
```

To create users in MySQL:

```shell
# normal user
mysql -h 127.0.0.1 -P 3306 -u root -e "CREATE USER 'newuser'@'localhost' IDENTIFIED BY 'password';"

# admin user
mysql -h 127.0.0.1 -P 3306 -u root -e "CREATE USER 'newuser'@'localhost' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON *.* TO 'newuser'@'localhost';"
```

If your repository contains a database dump, you can initialize the database in the CI environment like this:

```shell
checkout
sem-service start mysql
mysql -h 127.0.0.1 -P 3306 -u root < dump.sql
```

### Redis {#redis}

To start a Redis service:

```shell
sem-service start redis
```

To interact with the Redis service, use the following commands:

```shell
sem-service start redis
sudo apt install redis-tools -y
# Now you can use the redis-cli, e.g.
redis-cli incr mycounter
```

### MongoDB {#mongodb}

You can start a MongoDB database with:

```shell
sem-service start mongodb
```

Create users with:

```shell
# normal user
echo 'db.createUser( {user:"username", pwd:"password", roles:[], mechanisms:["SCRAM-SHA-1"]  } )' | mongo s2

# admin user
echo 'db.createUser({user:"username", pwd:"password", roles:[{role:"userAdminAnyDatabase",db:"admin"}], mechanisms:["SCRAM-SHA-1"]})' | mongo admin
```

To interact with the MongoDB service use:

```shell
sem-service start mongodb
sudo apt install mongodb-clients -y
# create user
echo 'db.createUser( {user:"username", pwd:"password", roles:[], mechanisms:["SCRAM-SHA-1"]  } )' | mongo s2
```

### Memcached {#memcached}

You can start a Memcached service with:

```shell
sem-service start memcached
```

To interact with the Memcached instance use:

```shell
sem-service start memcached
sudo apt install libmemcached-tools -y
memcstat --servers="127.0.0.1"
```

### Elasticsearch {#elasticsearch}

To start an Elasticsearch service:

```shell
sem-service start elasticsearch
```

You can create users with:

```shell
# normal user
sudo /usr/share/elasticsearch/bin/elasticsearch-users useradd new_user -p password -r reporting_user

# admin user
sudo /usr/share/elasticsearch/bin/elasticsearch-users useradd new_user -p password -r superuser
```

To use an Elasticsearch instance, follow these steps:

```shell
sem-service start elasticsearch
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.3.2.deb
sudo dpkg -i elasticsearch-6.3.2.deb
sudo /usr/share/elasticsearch/bin/elasticsearch-users useradd new_user -p password -r reporting_user
sudo /usr/share/elasticsearch/bin/elasticsearch-users list
```

## See also

- [sem-service reference](../../reference/toolbox#sem-service)
- [Ubuntu reference](../../reference/os-ubuntu)
