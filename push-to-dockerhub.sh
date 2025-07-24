#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found!"
    echo "Please create a .env file from .env.example"
    exit 1
fi

# Check if DOCKER_HUB_USERNAME is set
if [ -z "$DOCKER_HUB_USERNAME" ]; then
    echo "Error: DOCKER_HUB_USERNAME not set in .env file"
    exit 1
fi

# Set default tag if not provided
TAG=${1:-$IMAGE_TAG}
if [ -z "$TAG" ]; then
    TAG="latest"
fi

echo "Building and pushing image: $DOCKER_HUB_USERNAME/postcode-tracker-app:$TAG"

# Login to Docker Hub
echo "Logging in to Docker Hub..."
docker login

# Build the image
echo "Building Docker image..."
docker-compose build app

# Tag the image (docker-compose already tags it based on the image field)
# docker tag postcode-tracker-app:latest $DOCKER_HUB_USERNAME/postcode-tracker-app:$TAG

# Push the image
echo "Pushing image to Docker Hub..."
docker push $DOCKER_HUB_USERNAME/postcode-tracker-app:$TAG

echo "Done! Image pushed to Docker Hub: $DOCKER_HUB_USERNAME/postcode-tracker-app:$TAG"
echo ""
echo "Others can now use your image by:"
echo "1. Using this image in their docker-compose.yml:"
echo "   image: $DOCKER_HUB_USERNAME/postcode-tracker-app:$TAG"
echo "2. Or pulling directly:"
echo "   docker pull $DOCKER_HUB_USERNAME/postcode-tracker-app:$TAG"