#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Generates a gallery data JSON file from the image directories and embeds it into the HTML file
 * @param {number} limit - Maximum number of images to include
 * @param {string} outputJsonPath - Path to save the gallery data JSON file
 * @param {string} htmlPath - Path to the HTML file to update
 */
function generateGalleryData(limit = 100, outputJsonPath = './gallery-data.json', htmlPath = './index.html') {
    console.log(`Generating gallery data with limit: ${limit}`);
    
    // Get all image files from the resources directory
    const resourcesDir = path.resolve('./resources');
    const erasedDir = path.resolve('./erased');
    const outputDir = path.resolve('./output');
    
    // Check if directories exist
    if (!fs.existsSync(resourcesDir)) {
        console.error('Error: resources directory not found');
        process.exit(1);
    }
    
    // Get all files from resources directory
    let files = fs.readdirSync(resourcesDir)
        .filter(file => {
            // Only include image files
            const ext = path.extname(file).toLowerCase();
            return ['.jpg', '.jpeg', '.png', '.gif'].includes(ext);
        })
        .map(file => {
            const stats = fs.statSync(path.join(resourcesDir, file));
            return {
                filename: file,
                date: stats.mtime,
                size: stats.size
            };
        })
        .sort((a, b) => {
            // Sort by date, newest first
            return b.date - a.date;
        })
        .slice(0, limit); // Apply limit
    
    // Check if each file exists in all three directories
    files = files.filter(file => {
        const inErased = fs.existsSync(path.join(erasedDir, file.filename));
        const inOutput = fs.existsSync(path.join(outputDir, file.filename));
        
        if (!inErased || !inOutput) {
            console.warn(`Warning: ${file.filename} is missing from erased or output directory`);
        }
        
        return inErased && inOutput;
    });
    
    console.log(`Found ${files.length} images with all three versions`);
    
    // Write gallery data to JSON file (for compatibility with old code)
    fs.writeFileSync(outputJsonPath, JSON.stringify(files, null, 2));
    console.log(`Gallery data saved to ${outputJsonPath}`);
    
    // Embed gallery data into HTML file
    if (fs.existsSync(htmlPath)) {
        let htmlContent = fs.readFileSync(htmlPath, 'utf8');
        
        // Replace the placeholder with actual gallery data
        const galleryDataJson = JSON.stringify(files);
        
        // Find the line with the placeholder and replace it
        const placeholderPattern = /const galleryData = GALLERY_DATA_PLACEHOLDER;/;
        if (placeholderPattern.test(htmlContent)) {
            htmlContent = htmlContent.replace(placeholderPattern, `const galleryData = ${galleryDataJson};`);
            fs.writeFileSync(htmlPath, htmlContent);
            console.log(`Gallery data embedded into ${htmlPath}`);
        } else {
            console.warn(`Warning: Could not find placeholder in ${htmlPath}`);
            // Try a more aggressive approach
            const scriptPattern = /<script>[\s\S]*?<\/script>/;
            const scriptMatch = htmlContent.match(scriptPattern);
            
            if (scriptMatch) {
                const scriptContent = scriptMatch[0];
                const updatedScript = scriptContent.replace(
                    /const galleryData = .*?;/,
                    `const galleryData = ${galleryDataJson};`
                );
                
                htmlContent = htmlContent.replace(scriptPattern, updatedScript);
                fs.writeFileSync(htmlPath, htmlContent);
                console.log(`Gallery data embedded into ${htmlPath} using fallback method`);
            } else {
                console.error(`Error: Could not find script tag in ${htmlPath}`);
            }
        }
    } else {
        console.warn(`Warning: HTML file ${htmlPath} not found, skipping embedding`);
    }
    
    return files;
}

// If script is run directly
if (require.main === module) {
    const args = process.argv.slice(2);
    const limit = parseInt(args[0]) || 100;
    const outputJsonPath = args[1] || './gallery-data.json';
    const htmlPath = args[2] || './index.html';
    
    generateGalleryData(limit, outputJsonPath, htmlPath);
}

module.exports = { generateGalleryData }; 