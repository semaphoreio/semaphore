#!/usr/bin/env python3
#
# The gcloud auth print-identity-token command does not work
# for external account (workload identity federation).
# See: https://issuetracker.google.com/issues/215555124
#
# Due to that issue, we use the SDK directly.
#

import sys
from google.auth import credentials
from google.cloud import iam_credentials_v1
import google.auth
from google.auth.transport import requests

if len(sys.argv) != 3:
  print("Usage: {} <project_id> <service_account_name>".format(sys.argv[0]))
  sys.exit(1)

project_id = sys.argv[1]
service_account_name = sys.argv[2]
if project_id == "" or service_account_name == "":
  print("Usage: {} <project_id> <service_account_name>".format(sys.argv[0]))
  sys.exit(1)

client = iam_credentials_v1.services.iam_credentials.IAMCredentialsClient()
name = "projects/-/serviceAccounts/{}@{}.iam.gserviceaccount.com".format(service_account_name, project_id)
id_token = client.generate_id_token(name=name,audience="sigstore", include_email=True)
print(id_token.token)
