#!/bin/bash

# Deployment script for Thieme Image Gallery
# Usage: ./deploy.sh [options]
#
# Options:
#   -l, --limit <number>       Maximum number of images to include (default: 100)
#   -g, --generate-only        Only generate the HTML gallery locally without uploading
#   -u, --upload-only          Only upload pre-generated HTML and images without regenerating
#   -i, --invalidate-only      Only invalidate CloudFront cache
#   -p, --profile <profile>    AWS profile to use
#   -h, --help                 Show this help message

set -e

# Default values
LIMIT=100
GENERATE=true
UPLOAD=true
INVALIDATE=true
AWS_PROFILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--limit)
      LIMIT="$2"
      shift 2
      ;;
    -g|--generate-only)
      UPLOAD=false
      INVALIDATE=false
      shift
      ;;
    -u|--upload-only)
      GENERATE=false
      shift
      ;;
    -i|--invalidate-only)
      GENERATE=false
      UPLOAD=false
      shift
      ;;
    -p|--profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./deploy.sh [options]"
      echo ""
      echo "Options:"
      echo "  -l, --limit <number>       Maximum number of images to include (default: 100)"
      echo "  -g, --generate-only        Only generate the HTML gallery locally without uploading"
      echo "  -u, --upload-only          Only upload pre-generated HTML and images without regenerating"
      echo "  -i, --invalidate-only      Only invalidate CloudFront cache"
      echo "  -p, --profile <profile>    AWS profile to use"
      echo "  -h, --help                 Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check if AWS profile is provided
if [ "$UPLOAD" = true ] || [ "$INVALIDATE" = true ]; then
  if [ -z "$AWS_PROFILE" ]; then
    echo "Error: AWS profile is required for upload or invalidation"
    echo "Use -p or --profile to specify an AWS profile"
    exit 1
  fi
  
  # Check if AWS profile exists
  if ! aws configure list-profiles | grep -q "^$AWS_PROFILE$"; then
    echo "Error: AWS profile '$AWS_PROFILE' does not exist"
    exit 1
  fi
fi

# Get S3 bucket name and CloudFront distribution ID from CloudFormation stack
if [ "$UPLOAD" = true ] || [ "$INVALIDATE" = true ]; then
  echo "Retrieving deployment information from CloudFormation stack..."
  
  STACK_INFO=$(aws cloudformation describe-stacks --stack-name ThiemeImageGalleryStack --profile "$AWS_PROFILE" --query "Stacks[0].Outputs" --output json)
  
  S3_BUCKET=$(echo "$STACK_INFO" | jq -r '.[] | select(.OutputKey=="BucketName") | .OutputValue')
  DISTRIBUTION_ID=$(echo "$STACK_INFO" | jq -r '.[] | select(.OutputKey=="DistributionId") | .OutputValue')
  
  if [ -z "$S3_BUCKET" ] || [ -z "$DISTRIBUTION_ID" ]; then
    echo "Error: Failed to retrieve S3 bucket name or CloudFront distribution ID"
    exit 1
  fi
  
  echo "S3 Bucket: $S3_BUCKET"
  echo "CloudFront Distribution ID: $DISTRIBUTION_ID"
fi

# Generate gallery data and HTML
if [ "$GENERATE" = true ]; then
  echo "Generating gallery data with limit: $LIMIT"
  node generate-gallery.js "$LIMIT" "./gallery-data.json" "./index.html"
  
  echo "Gallery generation completed"
fi

# Upload to S3
if [ "$UPLOAD" = true ]; then
  echo "Uploading files to S3 bucket: $S3_BUCKET"
  
  # Upload HTML file (now contains embedded gallery data)
  aws s3 cp index.html "s3://$S3_BUCKET/" --profile "$AWS_PROFILE"
  
  # Upload images from all three directories
  echo "Uploading images from resources directory..."
  aws s3 sync resources/ "s3://$S3_BUCKET/resources/" \
    --profile "$AWS_PROFILE" \
    --exclude "*" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png" \
    --include "*.gif"
  
  echo "Uploading images from erased directory..."
  aws s3 sync erased/ "s3://$S3_BUCKET/erased/" \
    --profile "$AWS_PROFILE" \
    --exclude "*" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png" \
    --include "*.gif"
  
  echo "Uploading images from output directory..."
  aws s3 sync output/ "s3://$S3_BUCKET/output/" \
    --profile "$AWS_PROFILE" \
    --exclude "*" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png" \
    --include "*.gif"
  
  echo "Upload completed"
fi

# Invalidate CloudFront cache
if [ "$INVALIDATE" = true ]; then
  echo "Invalidating CloudFront cache for distribution: $DISTRIBUTION_ID"
  
  INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "/*" \
    --profile "$AWS_PROFILE" \
    --query "Invalidation.Id" \
    --output text)
  
  echo "Invalidation created with ID: $INVALIDATION_ID"
  echo "Waiting for invalidation to complete..."
  
  aws cloudfront wait invalidation-completed \
    --distribution-id "$DISTRIBUTION_ID" \
    --id "$INVALIDATION_ID" \
    --profile "$AWS_PROFILE"
  
  echo "Invalidation completed"
fi

echo "Deployment process finished successfully!"

# Print URL if upload was performed
if [ "$UPLOAD" = true ]; then
  DISTRIBUTION_DOMAIN=$(echo "$STACK_INFO" | jq -r '.[] | select(.OutputKey=="DistributionDomainName") | .OutputValue')
  echo "Gallery is available at: https://$DISTRIBUTION_DOMAIN/"
fi 