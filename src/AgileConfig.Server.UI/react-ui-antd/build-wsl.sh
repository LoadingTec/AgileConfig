#!/bin/bash

# Build the project
npm run build:ssl-legacy

# Define target directory
TARGET_DIR="/mnt/c/Users/Administrator/source/repos/AgileConfig/src/AgileConfig.Server.Apisite/bin/Debug/net10.0/wwwroot/ui"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy dist contents to target
cp -rf dist/* "$TARGET_DIR/"

echo "Build completed and files copied to $TARGET_DIR"