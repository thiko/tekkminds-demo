# Thieme Image Gallery

A web-based image processing gallery that displays medical images in three different processing stages: original, erased (text removed), and final (translated text).

## Features

- Self-contained single HTML file with embedded CSS and JavaScript
- Responsive design that works on various devices
- Thumbnail gallery view with image cards
- Modal overlay for larger image viewing
- Navigation between the three versions of each image
- Keyboard navigation support (arrow keys, escape)
- No external dependencies to avoid CORS issues

## Project Structure

```
├── resources/    # Original images
├── erased/       # Images with text removed
├── output/       # Final images with translated text
├── cdk/          # AWS CDK infrastructure code
├── provisioning.sh  # AWS infrastructure setup script
├── generate_gallery.js  # Gallery HTML generator
├── deploy.sh     # Deployment script
└── index.html    # Generated gallery file
```

## Usage

### Prerequisites

- Node.js (for running the gallery generator)
- AWS CLI configured with appropriate credentials
- Images placed in the appropriate directories (resources, erased, output)

### Generating the Gallery

To generate the gallery HTML file locally:

```bash
# Make the script executable
chmod +x generate_gallery.js

# Generate with default settings (100 images)
./generate_gallery.js

# Or specify the number of images to include
./generate_gallery.js 50
```

This will create an `index.html` file that you can open locally in your browser.

### Deployment

The `deploy.sh` script handles generating the gallery, uploading to S3, and invalidating the CloudFront cache:

```bash
# Make the script executable
chmod +x deploy.sh

# Full deployment with default settings
./deploy.sh --profile your-aws-profile

# Specify number of images to include
./deploy.sh --profile your-aws-profile --num-images 50

# Only generate the HTML file locally
./deploy.sh --profile your-aws-profile --generate-only

# Only upload pre-generated files
./deploy.sh --profile your-aws-profile --upload-only

# Only invalidate CloudFront cache
./deploy.sh --profile your-aws-profile --invalidate-only

# Manually specify S3 bucket and CloudFront distribution (if CloudFormation lookup fails)
./deploy.sh --profile your-aws-profile --bucket your-bucket-name --distribution your-distribution-id
```

### Options

The `deploy.sh` script supports the following options:

- `-n, --num-images NUM`: Number of images to include (default: 100)
- `-g, --generate-only`: Only generate the HTML file locally, don't upload
- `-u, --upload-only`: Only upload pre-generated HTML and images, don't generate
- `-i, --invalidate-only`: Only invalidate CloudFront cache
- `-p, --profile PROFILE`: AWS profile to use (required)
- `-b, --bucket BUCKET`: Manually specify S3 bucket name (bypasses CloudFormation lookup)
- `-d, --distribution DIST`: Manually specify CloudFront distribution ID (bypasses CloudFormation lookup)
- `-h, --help`: Display help message

## Implementation Details

### Gallery Generator

The `generate_gallery.js` script:
- Scans the resources directory for images
- Checks if all three versions of each image exist
- Sorts images by modification date (newest first)
- Generates a self-contained HTML file with embedded CSS and JavaScript
- Limits the number of images based on the provided parameter

### HTML Gallery

The generated HTML file:
- Contains all CSS and JavaScript embedded directly in the file
- Displays images as thumbnail cards in a responsive grid
- Shows a modal overlay when an image is clicked
- Provides buttons to switch between original, erased, and final versions
- Supports keyboard navigation (arrow keys, escape)
- Works both locally and when deployed to S3/CloudFront

### Deployment Script

The `deploy.sh` script:
- Retrieves S3 bucket name and CloudFront distribution ID from CloudFormation
- Generates the gallery HTML file
- Uploads the HTML file and images to S3
- Invalidates the CloudFront cache
- Provides options for running steps independently

## Security

Authentication is handled by an existing Lambda@Edge function configured in the AWS infrastructure. 