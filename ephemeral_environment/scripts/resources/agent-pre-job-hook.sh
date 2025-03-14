apt-get update
apt-get install -y --no-install-recommends curl bash make git wget locales openssh-client

# Install the Semaphore toolbox in the job
rm -rf ~/.toolbox

downloadPath="https://github.com/semaphoreci/toolbox/releases/latest/download/self-hosted-linux.tar"
if [ ! -z "${SEMAPHORE_TOOLBOX_VERSION}" ]; then
  downloadPath="https://github.com/semaphoreci/toolbox/releases/download/$SEMAPHORE_TOOLBOX_VERSION/self-hosted-linux.tar"
fi

echo "Downloading Semaphore toolbox from $downloadPath..."
curl -sL --retry 5 --connect-timeout 3 $downloadPath -o /tmp/toolbox.tar
tar -xvf /tmp/toolbox.tar
mv toolbox ~/.toolbox
if [ ! -d ~/.toolbox ]; then
  echo "Failed to download toolbox."
  return 1
fi

echo "Installing..."
bash ~/.toolbox/install-toolbox
if [ "$?" -ne "0" ]; then
  echo "Failed to install toolbox."
  rm -rf $SEMAPHORE_GIT_DIR
fi

source ~/.toolbox/toolbox
if [ "$?" -ne "0" ]; then
  echo "Failed to source toolbox."
  rm -rf $SEMAPHORE_GIT_DIR
fi

echo "Semaphore toolbox successfully installed."

# Create SSH configuration.
# This is required to avoid manually accepting the Server SSH key fingerprints on checkout.
mkdir -p ~/.ssh

#
# Do it for GitHub for backwards compatibility
#
echo 'Host github.com' | tee -a ~/.ssh/config
echo '  StrictHostKeyChecking no' | tee -a ~/.ssh/config
echo '  UserKnownHostsFile=/dev/null' | tee -a ~/.ssh/config

#
# Do it for currently used one
#
url="${SEMAPHORE_GIT_URL#ssh://}"  # Remove the "ssh://" scheme if present
url="${url#*@}"                    # Remove everything up to (and including) the '@' if present
host="${url%%[:/]*}"               # Now extract the host: it's the substring until the first occurrence of either ':' (port separator) or '/' (path separator)

echo "Host ${host}" | tee -a ~/.ssh/config
echo '  StrictHostKeyChecking no' | tee -a ~/.ssh/config
echo '  UserKnownHostsFile=/dev/null' | tee -a ~/.ssh/config