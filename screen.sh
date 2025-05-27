#!/bin/bash

# Configuration
IMGUR_API_KEY="f8f01de269e26920152bdea96ed4fdd4"  # Replace with your ImgBB API key
SCREENSHOT_PATH="/tmp/screenshot.png"

# Take a screenshot using scrot
scrot $SCREENSHOT_PATH

# Upload screenshot to ImgBB
UPLOAD_URL="https://api.imgbb.com/1/upload?key=$IMGUR_API_KEY"
RESPONSE=$(curl -s -X POST -F "image=@$SCREENSHOT_PATH" $UPLOAD_URL)

# Extract the image URL from the response
IMAGE_URL=$(echo $RESPONSE | jq -r '.data.url')

# Output the image URL
if [[ $IMAGE_URL != "null" ]]; then
    echo "Screenshot uploaded successfully! View it here: $IMAGE_URL"
else
    echo "Failed to upload screenshot"
    echo "Error: $(echo $RESPONSE | jq -r '.error.message')"
fi
