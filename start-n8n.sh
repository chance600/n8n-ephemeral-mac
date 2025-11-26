#!/bin/bash
set -e

# Configuration
IMAGE_TAG="n8nio/n8n:latest"
PORT=5678
CONTAINER_NAME="n8n_ephemeral"

# Load environment variables from .env if it exists
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# Check if n8n is already running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
  echo "n8n is already running!"
  echo "Visit http://localhost:$PORT/ or run ./stop-n8n.sh to stop it."
  exit 1
fi

echo "Starting n8n Docker container..."
echo "This may take a moment on first run while downloading the image."

# Start n8n container
docker run --rm \
  --name $CONTAINER_NAME \
  -p $PORT:5678 \
  -v "$HOME/.n8n":/home/node/.n8n \
  -d $IMAGE_TAG

# Wait for n8n to be ready
echo "Waiting for n8n to start..."
sleep 3

# Check if container is still running
if [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
  echo "Error: n8n container failed to start."
  echo "Check Docker logs with: docker logs $CONTAINER_NAME"
  exit 1
fi

# Open browser
echo "Opening browser..."
open http://localhost:$PORT/ 2>/dev/null || echo "Please open http://localhost:$PORT/ in your browser"

echo ""
echo "✅ n8n is running!"
echo "📱 Access it at: http://localhost:$PORT/"
echo "💾 Data stored in: ~/.n8n"
echo "🛑 To stop: ./stop-n8n.sh"
echo ""
