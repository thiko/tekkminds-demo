# Thieme Image Gallery

A web-based image processing gallery application that displays images in three variations: original, erased, and final output.

## Project Structure

- `index.html` - Main HTML gallery page with embedded CSS and JavaScript
- `generate-gallery.js` - Script to generate the gallery data and embed it into the HTML
- `deploy.sh` - Deployment script for uploading to AWS
- `resources/` - Directory containing original images
- `erased/` - Directory containing images with text removed
- `output/` - Directory containing final images with translated text
- `cdk/` - AWS CDK infrastructure setup

## Features

- Modern, responsive HTML gallery with grid and list views
- Thumbnail cards with image name and generation date
- Overlay view for larger image display
- Navigation between the three versions (original, erased, final) in the overlay
- Keyboard navigation support (arrow keys, escape)
- Works both locally and when deployed to S3/CloudFront
- Responsive design for various devices
- **No external dependencies** - All CSS and JavaScript are embedded in the HTML file
- **No CORS issues** - Gallery data is embedded directly in the HTML

## Usage

### Local Development

To generate the gallery data and view it locally:

```bash
# Generate gallery data with default limit (100 images)
node generate-gallery.js

# Or specify a custom limit
node generate-gallery.js 50
```

Then open `index.html` in your browser.

### Deployment

The `deploy.sh` script handles generating the gallery data, uploading to S3, and invalidating the CloudFront cache.

```bash
# Full deployment with default settings (100 images)
./deploy.sh -p your-aws-profile

# Specify a custom limit
./deploy.sh -p your-aws-profile -l 50

# Only generate the gallery locally without uploading
./deploy.sh -g

# Only upload pre-generated gallery without regenerating
./deploy.sh -p your-aws-profile -u

# Only invalidate CloudFront cache
./deploy.sh -p your-aws-profile -i
```

#### Options

- `-l, --limit <number>` - Maximum number of images to include (default: 100)
- `-g, --generate-only` - Only generate the HTML gallery locally without uploading
- `-u, --upload-only` - Only upload pre-generated HTML and images without regenerating
- `-i, --invalidate-only` - Only invalidate CloudFront cache
- `-p, --profile <profile>` - AWS profile to use
- `-h, --help` - Show help message

## Requirements

- Node.js for running the gallery generation script
- AWS CLI configured with appropriate credentials for deployment
- `jq` command-line tool for JSON processing in the deployment script

## Authentication

Authentication is handled by an existing Lambda@Edge function configured in the AWS CDK stack.

## Technical Details

The application uses a single HTML file with embedded CSS and JavaScript to avoid any CORS issues. The gallery data is embedded directly into the HTML file during the generation process, eliminating the need for separate CSS, JavaScript, and JSON files. 