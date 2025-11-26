#!/bin/bash
set -e

CONTAINER_NAME="n8n_ephemeral"

echo "Stopping n8n..."

# Check if container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
  docker stop $CONTAINER_NAME
  echo "✅ n8n stopped successfully!"
  echo "All resources freed."
else
  echo "⚠️  No n8n_ephemeral container is running."
  echo "Nothing to stop."
fi
