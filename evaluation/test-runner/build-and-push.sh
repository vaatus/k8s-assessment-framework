#!/bin/bash
set -e

# Build and push test-runner Docker image
# This script should be run from the test-runner directory

REGISTRY="${DOCKER_REGISTRY:-public.ecr.aws}"
REPOSITORY="${DOCKER_REPOSITORY:-k8s-eval}"
IMAGE_NAME="test-runner"
VERSION="${VERSION:-latest}"

FULL_IMAGE_NAME="${REGISTRY}/${REPOSITORY}/${IMAGE_NAME}:${VERSION}"

echo "Building test-runner image..."
echo "Image: ${FULL_IMAGE_NAME}"

# Build image
docker build -t ${IMAGE_NAME}:${VERSION} .

# Tag for registry
docker tag ${IMAGE_NAME}:${VERSION} ${FULL_IMAGE_NAME}

echo "Image built successfully!"
echo ""
echo "To push to registry, run:"
echo "  docker push ${FULL_IMAGE_NAME}"
echo ""
echo "To use in Lambda, set environment variable:"
echo "  TEST_RUNNER_IMAGE=${FULL_IMAGE_NAME}"
