#!/bin/bash

# Google Photos Takeout Metadata Processor (Advanced)
# This script processes Google Photos takeout folders and re-attaches metadata to images
# using exiftool. It converts Google Photos JSON metadata to EXIF format.

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

# Function to check if jq is available (for JSON parsing)
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first."
        print_status "You can install it with: brew install jq"
        exit 1
    fi
    print_success "jq found at $(which jq)"
}

# Function to convert Google Photos JSON metadata to EXIF format
convert_metadata_to_exif() {
    local json_file="$1"
    local image_file="$2"
    
    # Extract metadata from JSON using jq
    local title=$(jq -r '.title // empty' "$json_file" 2>/dev/null)
    local description=$(jq -r '.description // empty' "$json_file" 2>/dev/null)
    local image_views=$(jq -r '.imageViews // empty' "$json_file" 2>/dev/null)
    local creation_timestamp=$(jq -r '.creationTime.timestamp // empty' "$json_file" 2>/dev/null)
    local photo_taken_timestamp=$(jq -r '.photoTakenTime.timestamp // empty' "$json_file" 2>/dev/null)
    local latitude=$(jq -r '.geoData.latitude // empty' "$json_file" 2>/dev/null)
    local longitude=$(jq -r '.geoData.longitude // empty' "$json_file" 2>/dev/null)
    local altitude=$(jq -r '.geoData.altitude // empty' "$json_file" 2>/dev/null)
    local url=$(jq -r '.url // empty' "$json_file" 2>/dev/null)
    local device_type=$(jq -r '.googlePhotosOrigin.mobileUpload.deviceType // empty' "$json_file" 2>/dev/null)
    
    # Build exiftool command arguments
    local exif_args=()
    
    # Add title if available
    if [[ -n "$title" ]]; then
        exif_args+=("-Title=$title")
    fi
    
    # Add description if available
    if [[ -n "$description" ]]; then
        exif_args+=("-Description=$description")
    fi
    
    # Add creation time if available
    if [[ -n "$creation_timestamp" ]]; then
        local creation_date=$(date -r "$creation_timestamp" "+%Y:%m:%d %H:%M:%S" 2>/dev/null || echo "")
        if [[ -n "$creation_date" ]]; then
            exif_args+=("-CreateDate=$creation_date")
            exif_args+=("-DateTimeOriginal=$creation_date")
        fi
    fi
    
    # Add photo taken time if available
    if [[ -n "$photo_taken_timestamp" ]]; then
        local photo_date=$(date -r "$photo_taken_timestamp" "+%Y:%m:%d %H:%M:%S" 2>/dev/null || echo "")
        if [[ -n "$photo_date" ]]; then
            exif_args+=("-DateTimeOriginal=$photo_date")
        fi
    fi
    
    # Add GPS coordinates if available and valid
    if [[ -n "$latitude" && -n "$longitude" && "$latitude" != "0.0" && "$longitude" != "0.0" ]]; then
        exif_args+=("-GPSLatitude=$latitude")
        exif_args+=("-GPSLongitude=$longitude")
        if [[ -n "$altitude" && "$altitude" != "0.0" ]]; then
            exif_args+=("-GPSAltitude=$altitude")
        fi
    fi
    
    # Add custom tags for Google Photos specific data
    if [[ -n "$image_views" ]]; then
        exif_args+=("-UserComment=Google Photos Views: $image_views")
    fi
    
    if [[ -n "$url" ]]; then
        exif_args+=("-UserComment=Google Photos URL: $url")
    fi
    
    if [[ -n "$device_type" ]]; then
        exif_args+=("-UserComment=Device Type: $device_type")
    fi
    
    # Apply metadata using exiftool
    if [[ ${#exif_args[@]} -gt 0 ]]; then
        if exiftool -overwrite_original "${exif_args[@]}" "$image_file" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
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
    local metadata_attached_count=0
    
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
        
        # Copy the image to output folder
        local output_image="${output_folder}/${image_name}"
        cp "$image_file" "$output_image"
        
        if [[ -n "$metadata_file" ]]; then
            print_status "Processing: $image_name with metadata: $(basename "$metadata_file")"
            
            # Try to convert and attach metadata
            if convert_metadata_to_exif "$metadata_file" "$output_image"; then
                print_success "Successfully attached metadata to: $image_name"
                metadata_attached_count=$((metadata_attached_count + 1))
            else
                print_warning "Could not attach metadata to: $image_name (metadata file available: $(basename "$metadata_file"))"
            fi
            
            processed_count=$((processed_count + 1))
        else
            # No metadata file found, just copy the image
            print_status "Copied image without metadata: $image_name"
            processed_count=$((processed_count + 1))
        fi
    done
    
    print_success "Completed processing $folder_name: $processed_count images processed, $metadata_attached_count with metadata attached"
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
    done < <(find "$current_dir" -maxdepth 1 -type d -name "Takeout*" -print0)
    
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

# Function to show usage
show_usage() {
    echo "Usage: $0 [directory]"
    echo ""
    echo "This script processes Google Photos takeout folders and re-attaches metadata to images."
    echo "It focuses on 'Photos from *' folders and creates output folders with processed images."
    echo ""
    echo "Arguments:"
    echo "  directory    Directory containing takeout folders (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Process current directory"
    echo "  $0 /path/to/takeouts  # Process specific directory"
    echo ""
    echo "Requirements:"
    echo "  - exiftool (install with: brew install exiftool)"
    echo "  - jq (install with: brew install jq)"
}

# Main script
main() {
    # Check for help flag
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    print_status "Google Photos Takeout Metadata Processor (Advanced)"
    print_status "=================================================="
    
    # Check if required tools are available
    check_exiftool
    check_jq
    
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
    print_status "Images with successfully attached metadata will have EXIF data embedded."
}

# Run the main function with all arguments
main "$@"
