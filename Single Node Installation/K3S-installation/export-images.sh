#!/bin/bash

set -e

# Ensure required variables are set
if [[ -z "$MASTER_KEY" || -z "$JOIN_KEY" ]]; then
  echo "❌ Please set MASTER_KEY and JOIN_KEY environment variables"
  exit 1
fi

# Helm repo setup
helm repo add jfrog https://charts.jfrog.io
helm repo update

# Set default values
export JFROG_URL="http://artifactory-artifactory-nginx.artifactory.svc.cluster.local"
export RABBIT_PWD="SecureRabbit123"

# Render Artifactory images
helm template artifactory jfrog/artifactory --namespace artifactory \
  --set artifactory.masterKey=$MASTER_KEY \
  --set artifactory.joinKey=$JOIN_KEY \
  | grep image: | awk '{print $2}' | sort | uniq > artifactory-images.txt

# Render Xray images
cat <<EOF > xray-values-temp.yaml
xray:
  jfrogUrl: ${JFROG_URL}
rabbitmq:
  auth:
    password: ${RABBIT_PWD}
EOF

helm template xray jfrog/xray --namespace xray -f xray-values-temp.yaml \
  | grep image: | awk '{print $2}' | sort | uniq > xray-images.txt

# Merge and deduplicate
cat artifactory-images.txt xray-images.txt | sort | uniq > jfrog-images.txt

# Pull and save
mkdir -p jfrog-images

while read image; do
  echo "Pulling $image"
  docker pull "$image"
  fname=$(echo "$image" | tr '/:' '_')
  docker save "$image" -o "jfrog-images/${fname}.tar"
done < jfrog-images.txt

echo "✅ All images exported to ./jfrog-images/"
