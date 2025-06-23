# Google Photos Takeout Metadata Processor

This tool processes Google Photos takeout folders and re-attaches metadata to images using exiftool. It focuses on "Photos from *" folders and creates output folders with processed images that have their metadata embedded.

## Overview

When you download your Google Photos data using Google Takeout, the metadata (like creation date, location, description, etc.) is often stored in separate JSON files rather than being embedded in the image files themselves. This script helps you re-attach that metadata to the actual image files.

## Features

- **Recursive Processing**: Automatically finds and processes all "Photos from *" folders in your takeout directories
- **Multiple Takeout Support**: Processes all takeout folders (Takeout 1, Takeout 2, etc.) in a directory
- **Metadata Conversion**: Converts Google Photos JSON metadata to EXIF format that can be embedded in images
- **Multiple Image Formats**: Supports JPG, PNG, HEIC, TIFF, BMP, and GIF files
- **Comprehensive Metadata**: Preserves titles, descriptions, creation dates, GPS coordinates, and Google Photos specific data
- **Safe Processing**: Creates output folders without modifying original files

## Requirements

- **exiftool**: For reading and writing image metadata
  ```bash
  brew install exiftool
  ```
- **jq**: For parsing JSON metadata files
  ```bash
  brew install jq
  ```

## Scripts

### 1. Basic Script (`process_takeout_metadata.sh`)
A simpler version that attempts to use exiftool's built-in JSON support.

### 2. Advanced Script (`process_takeout_metadata_advanced.sh`) ⭐ **Recommended**
A more sophisticated version that properly converts Google Photos JSON metadata to EXIF format.

## Usage

### Basic Usage
```bash
# Process current directory
./process_takeout_metadata_advanced.sh

# Process specific directory
./process_takeout_metadata_advanced.sh /path/to/takeouts

# Show help
./process_takeout_metadata_advanced.sh --help
```

### Example Directory Structure
```
takeouttool/
├── Takeout 1/
│   └── Google Photos/
│       ├── Photos from 2023/
│       │   ├── IMG_1821.PNG
│       │   ├── IMG_1821.PNG.supplemental-metadata.json
│       │   └── Photos from 2023 output/  ← Created by script
│       └── Photos from 2022/
│           └── ...
├── Takeout 2/
│   └── ...
└── process_takeout_metadata_advanced.sh
```

## What the Script Does

1. **Finds Takeout Folders**: Searches for folders named "Takeout *" in the specified directory
2. **Locates Photo Folders**: Within each takeout folder, finds "Photos from *" directories
3. **Creates Output Folders**: For each photo folder, creates a corresponding "output" folder
4. **Processes Images**: For each image file:
   - Copies the image to the output folder
   - Looks for corresponding metadata files (`.suppl.json` or `.supplemental-metadata.json`)
   - Converts Google Photos metadata to EXIF format
   - Embeds the metadata into the image using exiftool
5. **Reports Progress**: Shows detailed progress and results

## Metadata Preserved

The script preserves the following metadata from Google Photos:

- **Title**: Image title
- **Description**: Image description
- **Creation Date**: When the image was created/uploaded
- **Photo Taken Date**: When the photo was originally taken
- **GPS Coordinates**: Location data (if available and valid)
- **Google Photos Data**: Views, URL, device type (stored in UserComment field)

## Example Output

```
[INFO] Google Photos Takeout Metadata Processor (Advanced)
[INFO] ==================================================
[SUCCESS] exiftool found at /usr/local/bin/exiftool
[SUCCESS] jq found at /usr/bin/jq
[INFO] Target directory: /Users/username/Documents/takeouttool
[INFO] Processing all takeout folders in: /Users/username/Documents/takeouttool
[INFO] Found 4 takeout folder(s)
[INFO] Processing takeout folder: Takeout 1
[INFO] Searching for 'Photos from *' folders in: /Users/username/Documents/takeouttool/Takeout 1
[INFO] Found 6 photo folder(s) to process
[INFO] Processing folder: /Users/username/Documents/takeouttool/Takeout 1/Google Photos/Photos from 2023
[INFO] Created output folder: /Users/username/Documents/takeouttool/Takeout 1/Google Photos/Photos from 2023 output
[INFO] Processing: IMG_1821.PNG with metadata: IMG_1821.PNG.supplemental-metadata.json
[SUCCESS] Successfully attached metadata to: IMG_1821.PNG
[SUCCESS] Completed processing Photos from 2023: 45 images processed, 23 with metadata attached
```

## Troubleshooting

### Common Issues

1. **"exiftool is not installed"**
   ```bash
   brew install exiftool
   ```

2. **"jq is not installed"**
   ```bash
   brew install jq
   ```

3. **Permission denied**
   ```bash
   chmod +x process_takeout_metadata_advanced.sh
   ```

4. **No metadata attached**
   - Check that metadata files exist and are valid JSON
   - Some metadata might not be compatible with certain image formats
   - GPS coordinates with 0.0 values are ignored (these usually indicate no location data)

### Checking Results

To verify that metadata was successfully attached:

```bash
# Check metadata of a processed image
exiftool "Takeout 1/Google Photos/Photos from 2023 output/IMG_1821.PNG"

# Compare with original
exiftool "Takeout 1/Google Photos/Photos from 2023/IMG_1821.PNG"
```

## Notes

- The script creates output folders without modifying your original files
- GPS coordinates with 0.0 values (indicating no location data) are not embedded
- Some metadata might not be compatible with all image formats
- The script processes images recursively, so it will find all "Photos from *" folders in subdirectories
- Original metadata files are preserved alongside the processed images

## License

This script is provided as-is for personal use. Feel free to modify and adapt as needed. 