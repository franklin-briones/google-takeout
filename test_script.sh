#!/bin/bash

# Test script to demonstrate the metadata processing functionality
# This script will process just one "Photos from *" folder as a test

set -e

echo "=== Google Photos Takeout Metadata Processor - Test Run ==="
echo ""

# Check if we're in the right directory
if [[ ! -d "Takeout 1" ]]; then
    echo "Error: Takeout 1 folder not found. Please run this from the takeouttool directory."
    exit 1
fi

# Find the first "Photos from *" folder
PHOTO_FOLDER=$(find "Takeout 1" -type d -name "Photos from *" | head -1)

if [[ -z "$PHOTO_FOLDER" ]]; then
    echo "Error: No 'Photos from *' folders found in Takeout 1"
    exit 1
fi

echo "Found photo folder: $PHOTO_FOLDER"
echo ""

# Count files in the folder
IMAGE_COUNT=$(find "$PHOTO_FOLDER" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" \) | wc -l)
METADATA_COUNT=$(find "$PHOTO_FOLDER" -maxdepth 1 -type f \( -iname "*.json" \) | wc -l)

echo "Files in folder:"
echo "  - Images: $IMAGE_COUNT"
echo "  - Metadata files: $METADATA_COUNT"
echo ""

# Show a few example files
echo "Example files:"
find "$PHOTO_FOLDER" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" \) | head -3 | while read file; do
    echo "  - $(basename "$file")"
done

echo ""
echo "Example metadata files:"
find "$PHOTO_FOLDER" -maxdepth 1 -type f \( -iname "*.json" \) | head -3 | while read file; do
    echo "  - $(basename "$file")"
done

echo ""
echo "To process all folders, run:"
echo "  ./process_takeout_metadata_advanced.sh"
echo ""
echo "To process just this folder for testing, run:"
echo "  ./process_takeout_metadata_advanced.sh ."
echo ""
echo "The script will create output folders with processed images that have metadata embedded." 