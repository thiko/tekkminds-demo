#!/bin/bash

# Thieme Image Gallery Deployment Script
# This script generates the HTML gallery and uploads it to S3

set -e

# Default values
MAX_IMAGES=100
GENERATE_ONLY=false
UPLOAD_ONLY=false
INVALIDATE_ONLY=false
AWS_PROFILE=""
S3_BUCKET_MANUAL=""
CF_DISTRIBUTION_MANUAL=""

# Function to display usage information
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -n, --num-images NUM     Number of images to include (default: 100)"
  echo "  -g, --generate-only      Only generate the HTML file locally, don't upload"
  echo "  -u, --upload-only        Only upload pre-generated HTML and images, don't generate"
  echo "  -i, --invalidate-only    Only invalidate CloudFront cache"
  echo "  -p, --profile PROFILE    AWS profile to use"
  echo "  -b, --bucket BUCKET      Manually specify S3 bucket name (bypasses CloudFormation lookup)"
  echo "  -d, --distribution DIST  Manually specify CloudFront distribution ID (bypasses CloudFormation lookup)"
  echo "  -h, --help               Display this help message"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--num-images)
      MAX_IMAGES="$2"
      shift 2
      ;;
    -g|--generate-only)
      GENERATE_ONLY=true
      shift
      ;;
    -u|--upload-only)
      UPLOAD_ONLY=true
      shift
      ;;
    -i|--invalidate-only)
      INVALIDATE_ONLY=true
      shift
      ;;
    -p|--profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    -b|--bucket)
      S3_BUCKET_MANUAL="$2"
      shift 2
      ;;
    -d|--distribution)
      CF_DISTRIBUTION_MANUAL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Check if AWS profile is provided
if [ -z "$AWS_PROFILE" ]; then
  echo "Error: AWS profile is required."
  echo "Please provide an AWS profile using the -p or --profile option."
  exit 1
fi

# Get S3 bucket name and CloudFront distribution ID
if [ -n "$S3_BUCKET_MANUAL" ] && [ -n "$CF_DISTRIBUTION_MANUAL" ]; then
  # Use manually provided values
  S3_BUCKET="$S3_BUCKET_MANUAL"
  CF_DISTRIBUTION="$CF_DISTRIBUTION_MANUAL"
  echo "Using manually provided values:"
else
  # Get values from CloudFormation
  echo "Retrieving deployment information from CloudFormation..."
  CF_OUTPUTS=$(aws cloudformation describe-stacks --stack-name ThiemeImageGalleryStack --profile "$AWS_PROFILE" --query "Stacks[0].Outputs" --output json)
  
  # More robust parsing using jq if available
  if command -v jq &> /dev/null; then
    S3_BUCKET=$(echo "$CF_OUTPUTS" | jq -r '.[] | select(.OutputKey=="BucketName") | .OutputValue')
    CF_DISTRIBUTION=$(echo "$CF_OUTPUTS" | jq -r '.[] | select(.OutputKey=="DistributionId") | .OutputValue')
  else
    # Fallback to grep/sed parsing if jq is not available
    S3_BUCKET=$(echo "$CF_OUTPUTS" | grep -o '"OutputKey": "BucketName".*"OutputValue": "[^"]*"' | sed 's/.*"OutputValue": "\([^"]*\)".*/\1/')
    CF_DISTRIBUTION=$(echo "$CF_OUTPUTS" | grep -o '"OutputKey": "DistributionId".*"OutputValue": "[^"]*"' | sed 's/.*"OutputValue": "\([^"]*\)".*/\1/')
  fi
  
  # If manual values were provided for one but not both, use them
  if [ -n "$S3_BUCKET_MANUAL" ]; then
    S3_BUCKET="$S3_BUCKET_MANUAL"
  fi
  
  if [ -n "$CF_DISTRIBUTION_MANUAL" ]; then
    CF_DISTRIBUTION="$CF_DISTRIBUTION_MANUAL"
  fi
fi

if [ -z "$S3_BUCKET" ] || [ -z "$CF_DISTRIBUTION" ]; then
  # Print the raw output for debugging
  echo "Debug - Raw CloudFormation output:"
  echo "$CF_OUTPUTS"
  
  echo "Error: Could not retrieve S3 bucket name or CloudFront distribution ID."
  echo "Please check if the stack name 'ThiemeImageGalleryStack' is correct and if it has outputs named 'BucketName' and 'DistributionId'."
  echo "Alternatively, provide them manually using the --bucket and --distribution options."
  exit 1
fi

echo "S3 Bucket: $S3_BUCKET"
echo "CloudFront Distribution: $CF_DISTRIBUTION"

# Function to generate the HTML gallery
generate_gallery() {
  echo "Generating HTML gallery with $MAX_IMAGES images..."
  
  # Make the script executable if it's not already
  chmod +x generate_gallery.js
  
  # Run the gallery generator
  ./generate_gallery.js "$MAX_IMAGES"
  
  if [ ! -f "index.html" ]; then
    echo "Error: Failed to generate index.html"
    exit 1
  fi
  
  echo "Gallery generated successfully: index.html"
}

# Function to upload files to S3
upload_to_s3() {
  echo "Uploading files to S3 bucket: $S3_BUCKET"
  
  # Upload the HTML file
  echo "Uploading index.html..."
  aws s3 cp index.html "s3://$S3_BUCKET/index.html" --profile "$AWS_PROFILE" --content-type "text/html" --cache-control "max-age=3600"
  
  # Upload images from all three directories
  echo "Uploading images from resources directory..."
  aws s3 sync resources/ "s3://$S3_BUCKET/resources/" --profile "$AWS_PROFILE" --content-type "image/jpeg" --cache-control "max-age=86400" --size-only
  
  echo "Uploading images from erased directory..."
  aws s3 sync erased/ "s3://$S3_BUCKET/erased/" --profile "$AWS_PROFILE" --content-type "image/jpeg" --cache-control "max-age=86400" --size-only
  
  echo "Uploading images from output directory..."
  aws s3 sync output/ "s3://$S3_BUCKET/output/" --profile "$AWS_PROFILE" --content-type "image/jpeg" --cache-control "max-age=86400" --size-only
  
  echo "Upload completed successfully."
}

# Function to invalidate CloudFront cache
invalidate_cache() {
  echo "Invalidating CloudFront cache for distribution: $CF_DISTRIBUTION"
  
  # Create invalidation for all files
  aws cloudfront create-invalidation --distribution-id "$CF_DISTRIBUTION" --paths "/*" --profile "$AWS_PROFILE"
  
  echo "Cache invalidation initiated."
}

# Main execution logic based on flags
if [ "$INVALIDATE_ONLY" = true ]; then
  invalidate_cache
  exit 0
fi

if [ "$GENERATE_ONLY" = true ]; then
  generate_gallery
  exit 0
fi

if [ "$UPLOAD_ONLY" = true ]; then
  if [ ! -f "index.html" ]; then
    echo "Error: index.html not found. Generate it first or use without --upload-only flag."
    exit 1
  fi
  upload_to_s3
  invalidate_cache
  exit 0
fi

# Default behavior: generate, upload, and invalidate
generate_gallery
upload_to_s3
invalidate_cache

echo "Deployment completed successfully!"
echo "Your gallery should be available at the CloudFront URL in a few minutes." 