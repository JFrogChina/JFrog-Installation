#!/bin/bash

set -e

cd jfrog-images

for tar in *.tar; do
  echo "Loading $tar"
  docker load -i "$tar"
done

echo "✅ All images loaded into Docker"
