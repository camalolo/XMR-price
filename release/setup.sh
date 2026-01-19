#!/bin/bash

# Setup script for Chrome Extension Release System
# This script copies release tools to the current directory and sets up dependencies

echo "Setting up Chrome Extension Release System..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: This is not a git repository. Please initialize git first."
    exit 1
fi

# Check if manifest.json exists
if [ ! -f "manifest.json" ]; then
    echo "Error: manifest.json not found. This doesn't appear to be a Chrome extension project."
    exit 1
fi

# Config files stay in release/config/ - ESLint will reference them directly

# Handle package.json
if [ -f "package.json" ]; then
    echo "package.json already exists. Merging release dependencies..."
    # Read existing package.json
    EXISTING_DEPS=$(node -e "console.log(JSON.stringify(require('./package.json').devDependencies || {}, null, 2))")
    RELEASE_DEPS=$(node -e "console.log(JSON.stringify(require('./release/config/package-template.json').devDependencies || {}, null, 2))")

    # Create a temporary script to merge dependencies
    cat > merge_deps.js << 'EOF'
const fs = require('fs');
const existing = JSON.parse(fs.readFileSync('./package.json', 'utf8'));
const release = JSON.parse(fs.readFileSync('./release/config/package-template.json', 'utf8'));

// Merge devDependencies
existing.devDependencies = existing.devDependencies || {};
Object.assign(existing.devDependencies, release.devDependencies);

// Add pack script if not present
existing.scripts = existing.scripts || {};
if (!existing.scripts.pack) {
    existing.scripts.pack = "node release/scripts/pack.mjs";
}

// Add lint script if not present
if (!existing.scripts.lint) {
    existing.scripts.lint = "eslint --config release/config/eslint.config.mjs .";
}

// Add publish script if not present
if (!existing.scripts.publish) {
    existing.scripts.publish = "bash release/scripts/tag_release.sh";
}

// Add test script if not present
if (!existing.scripts.test) {
    existing.scripts.test = "echo \"Error: no test specified\" && exit 1";
}

fs.writeFileSync('./package.json', JSON.stringify(existing, null, 2));
EOF

    node merge_deps.js
    rm merge_deps.js
    echo "Merged dependencies into existing package.json"
else
    echo "Creating new package.json from template..."
    cp release/config/package-template.json ./package.json
fi

# Copy .gitignore entries if needed
if [ -f ".gitignore" ]; then
    echo "Checking .gitignore..."
    # Add dist/ if not present
    if ! grep -q "^dist/$" .gitignore; then
        echo "dist/" >> .gitignore
    fi
    # Add other build artifacts
    if ! grep -q "^web-ext-artifacts/$" .gitignore; then
        echo "web-ext-artifacts/" >> .gitignore
    fi
    if ! grep -q "\*.crx$" .gitignore; then
        echo "*.crx" >> .gitignore
    fi
else
    echo "Creating .gitignore..."
    cat > .gitignore << 'EOF'
node_modules/
dist/

*.crx
web-ext-artifacts/
EOF
fi

# Make scripts executable
echo "Making scripts executable..."
chmod +x release/scripts/tag_release.sh

# Install dependencies
echo "Installing dependencies..."
npm install

echo "Setup complete!"
echo ""
echo "Usage:"
echo "  - Run 'npm run lint' to lint your code"
echo "  - Run 'npm run pack' to build CRX and ZIP files"
echo "  - Run './release/scripts/tag_release.sh' to create a new release"
echo ""
echo "Note: Make sure you have your private key at '../Chrome-Extension-Keys/key.pem' for CRX signing"