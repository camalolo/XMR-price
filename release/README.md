# Chrome Extension Release System

This is a portable release system for Chrome extensions that can be copied to any extension project. It provides automated versioning, building, and GitHub releases.

## Features

- **Auto-detection**: Automatically detects extension name from `manifest.json`
- **GitHub Integration**: Automatically creates GitHub repositories if none exist
- **Version Management**: Compares manifest versions with Git tags to determine releases
- **Build Tools**: Creates both ZIP and CRX files for distribution
- **Linting**: Includes ESLint configuration for consistent code quality

## Setup

1. Copy the entire `release/` folder to your Chrome extension project root
2. Run the setup script:
   ```bash
   ./release/setup.sh
   ```
3. The setup script will:
   - Configure linting to use config files from `release/config/`
   - Merge dependencies into your `package.json` (or create one if missing)
   - Install all required Node.js dependencies
   - Update `.gitignore` with build artifacts
    - Keep all scripts and config files contained within the `release/` directory

### Alternative: Using as Git Submodule

For projects that want to receive updates to the release tools automatically, add this system as a Git submodule instead of copying:

1. Ensure your project is a Git repository.
2. Add the submodule:
   ```bash
   git submodule add https://github.com/camalolo/chrome-ext-release.git release
   ```
3. Initialize the submodule:
   ```bash
   git submodule update --init
   ```
4. Commit the changes:
   ```bash
   git add .gitmodules release
   git commit -m "Add release/ submodule for Chrome extension tooling"
   ```
5. Run the setup script:
   ```bash
   ./release/setup.sh
   ```

**Note**: The submodule points to a private repository. Ensure you have access (e.g., as a collaborator) or request it from the owner. For updates, run `git submodule update --remote` in your project.

## Requirements

- **Node.js** and **npm** installed
- **Git** repository initialized
- **GitHub CLI** (`gh`) installed and authenticated (`gh auth login`)
- Private key for CRX signing at `../Chrome-Extension-Keys/key.pem`

## Usage

### Building Extension
```bash
npm run pack
```
This creates `dist/{extension-name}-v{version}.zip` and `dist/{extension-name}-v{version}.crx` files.

**Note**: The build process ignores common development files. If you need to exclude extension-specific files (like `PRIVACY_POLICY.md`, `LICENSE`, etc.), you can modify the `ignoreFiles` array in `release/scripts/pack.mjs`:

```javascript
const ignoreFiles = [
  "dist/",
  "package.json",
  "package-lock.json",
  "eslint.config.mjs",
  "jsconfig.json",
  "pack.mjs",
  "tag_release.sh",
  ".git/",
  ".gitignore",
  "node_modules/",
  // Add your extension-specific files here:
  "PRIVACY_POLICY.md",
  "LICENSE",
  "CONTRIBUTING.md"
].join('" "');
```

### Creating a Release
```bash
./tag_release.sh
```
This will:
1. Check if a GitHub repository exists (creates one if not)
2. Compare current manifest version with latest Git tag
3. Create a new tag if version is newer
4. Build the extension packages
5. Create a GitHub release with the packages

### Linting
```bash
npm run lint
```
*Uses ESLint configuration from `release/config/eslint.config.mjs`*

## File Structure After Setup

```
your-extension/
├── manifest.json
├── package.json          # Updated with release dependencies
├── release/              # Self-contained release system
│   ├── scripts/
│   │   ├── tag_release.sh    # Release script (executable)
│   │   └── pack.mjs          # Build script
│   ├── config/
│   │   ├── eslint.config.mjs # Linting configuration
│   │   ├── jsconfig.json     # JavaScript configuration
│   │   └── package-template.json
│   └── ...
├── dist/                 # Build output directory
├── .gitignore            # Updated to ignore build artifacts
└── ...your extension files
```

## Configuration

The system uses these defaults (can be modified in the scripts):
- **Remote name**: `origin`
- **Main branch**: `main`
- **Manifest file**: `manifest.json`
- **Private key**: `../Chrome-Extension-Keys/key.pem`

## Extension Naming

The extension name is automatically derived from the `manifest.json` "name" field:
- Converted to lowercase
- Non-alphanumeric characters replaced with hyphens
- Multiple hyphens collapsed to single
- Leading/trailing hyphens removed

Example: `"My Awesome Extension"` → `"my-awesome-extension"`

## Troubleshooting

### GitHub CLI Issues
```bash
gh auth login
```
Make sure you're authenticated with GitHub CLI.

### Private Key Not Found
Ensure your CRX signing key is at `../Chrome-Extension-Keys/key.pem` relative to your extension directory.

### Permission Denied on Scripts
```bash
chmod +x release/scripts/tag_release.sh
```

### Build Fails
Make sure all dependencies are installed:
```bash
npm install
```

## Files in This Release System

- `setup.sh` - Initialization script
- `scripts/tag_release.sh` - Main release automation script
- `scripts/pack.mjs` - Extension building script
- `config/package-template.json` - Template package.json with dependencies
- `config/eslint.config.mjs` - ESLint configuration (used in-place)
- `config/jsconfig.json` - JavaScript configuration (used in-place)