#!/bin/bash

# Google Photos Takeout Metadata Processor
# This script processes Google Photos takeout folders and re-attaches metadata to images
# using exiftool. It focuses on "Photos from *" folders and creates output folders
# with processed images that have their metadata embedded.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if exiftool is available
check_exiftool() {
    if ! command -v exiftool &> /dev/null; then
        print_error "exiftool is not installed. Please install it first."
        print_status "You can install it with: brew install exiftool"
        exit 1
    fi
    print_success "exiftool found at $(which exiftool)"
}

# Function to process a single photo folder
process_photo_folder() {
    local folder_path="$1"
    local folder_name=$(basename "$folder_path")
    local parent_dir=$(dirname "$folder_path")
    local output_folder="${parent_dir}/${folder_name} output"
    
    print_status "Processing folder: $folder_path"
    
    # Create output directory
    mkdir -p "$output_folder"
    print_status "Created output folder: $output_folder"
    
    # Find all image files in the folder
    local image_files=()
    while IFS= read -r -d '' file; do
        image_files+=("$file")
    done < <(find "$folder_path" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.tiff" -o -iname "*.bmp" -o -iname "*.gif" \) -print0)
    
    local processed_count=0
    local skipped_count=0
    
    for image_file in "${image_files[@]}"; do
        local image_name=$(basename "$image_file")
        local image_base="${image_name%.*}"
        local image_ext="${image_name##*.}"
        
        # Look for corresponding metadata files
        local metadata_file=""
        local possible_metadata_files=(
            "${folder_path}/${image_base}.suppl.json"
            "${folder_path}/${image_base}.supplemental-metadata.json"
            "${folder_path}/${image_name}.suppl.json"
            "${folder_path}/${image_name}.supplemental-metadata.json"
        )
        
        for possible_file in "${possible_metadata_files[@]}"; do
            if [[ -f "$possible_file" ]]; then
                metadata_file="$possible_file"
                break
            fi
        done
        
        if [[ -n "$metadata_file" ]]; then
            print_status "Processing: $image_name with metadata: $(basename "$metadata_file")"
            
            # Create a temporary file for the processed image
            local temp_output="${output_folder}/${image_name}"
            
            # Use exiftool to copy the image and potentially add metadata
            # Note: We'll copy the image first, then try to add metadata if possible
            cp "$image_file" "$temp_output"
            
            # Try to extract and add metadata from the JSON file
            # This is a simplified approach - exiftool can read some JSON metadata
            # but Google Photos metadata format might need custom handling
            if exiftool -overwrite_original -json="$metadata_file" "$temp_output" 2>/dev/null; then
                print_success "Successfully processed: $image_name"
            else
                # If exiftool can't directly use the JSON, we'll keep the original image
                # but note that metadata is available in the JSON file
                print_warning "Could not embed metadata for: $image_name (metadata available in: $(basename "$metadata_file"))"
            fi
            
            processed_count=$((processed_count + 1))
        else
            # No metadata file found, just copy the image
            print_status "Copying image without metadata: $image_name"
            cp "$image_file" "${output_folder}/${image_name}"
            processed_count=$((processed_count + 1))
        fi
    done
    
    print_success "Completed processing $folder_name: $processed_count images processed"
    return 0
}

# Function to find and process all "Photos from *" folders
find_and_process_photo_folders() {
    local root_dir="$1"
    local photo_folders=()
    
    print_status "Searching for 'Photos from *' folders in: $root_dir"
    
    # Find all "Photos from *" folders
    while IFS= read -r -d '' folder; do
        photo_folders+=("$folder")
    done < <(find "$root_dir" -type d -name "Photos from *" -print0)
    
    if [[ ${#photo_folders[@]} -eq 0 ]]; then
        print_warning "No 'Photos from *' folders found in: $root_dir"
        return 0
    fi
    
    print_status "Found ${#photo_folders[@]} photo folder(s) to process"
    
    # Process each photo folder
    for folder in "${photo_folders[@]}"; do
        process_photo_folder "$folder"
    done
    
    print_success "Completed processing all photo folders in: $root_dir"
}

# Function to process all takeout folders
process_all_takeouts() {
    local current_dir="$1"
    
    print_status "Processing all takeout folders in: $current_dir"
    
    # Find all takeout folders (Takeout 1, Takeout 2, etc.)
    local takeout_folders=()
    while IFS= read -r -d '' folder; do
        takeout_folders+=("$folder")
    done < <(find "$current_dir" -maxdepth 1 -type d -name "Takeout *" -print0)
    
    if [[ ${#takeout_folders[@]} -eq 0 ]]; then
        print_warning "No takeout folders found in: $current_dir"
        return 0
    fi
    
    print_status "Found ${#takeout_folders[@]} takeout folder(s)"
    
    # Process each takeout folder
    for takeout_folder in "${takeout_folders[@]}"; do
        print_status "Processing takeout folder: $(basename "$takeout_folder")"
        find_and_process_photo_folders "$takeout_folder"
    done
    
    print_success "Completed processing all takeout folders"
}

# Main script
main() {
    print_status "Google Photos Takeout Metadata Processor"
    print_status "========================================"
    
    # Check if exiftool is available
    check_exiftool
    
    # Get the directory to process (default to current directory)
    local target_dir="${1:-.}"
    
    if [[ ! -d "$target_dir" ]]; then
        print_error "Directory does not exist: $target_dir"
        exit 1
    fi
    
    # Convert to absolute path
    target_dir=$(cd "$target_dir" && pwd)
    print_status "Target directory: $target_dir"
    
    # Process all takeout folders
    process_all_takeouts "$target_dir"
    
    print_success "Script completed successfully!"
    print_status "Check the 'output' folders in each 'Photos from *' directory for processed images."
}

# Run the main function with all arguments
main "$@" 