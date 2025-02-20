#!/bin/bash

#
# A HTTPs git repository can be cloned with:
#
#   git clone https://<username>:<password>@github.com/<owner>/<repo>
#
# However, this approach saves the password in plaintext to .git/config.
#
# To avoid this, we are using this script as a dedicated GIT_ASKPASS program.
# Read more about GIT_ASKPASS: https://git-scm.com/docs/gitcredentials.
#
# Then, we run the clone with:
#
#   GIT_ASK_PASS=<path-to-this-script> \
#   GIT_PASSWORD=<pass> \
#   GIT_USERNAME=<user> \
#   git clone https://github.com/<owner>/<repo>
#
# The script is designed to respond to the Git prompt with the provided
# GIT_PASSWORD and GIT_USERNAME env vars.
#

if [[ $1 == *"Password"* ]]; then
  echo $GIT_PASSWORD
fi

if [[ $1 == *"Username"* ]]; then
  echo $GIT_USERNAME
fi
