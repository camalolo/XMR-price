#!/bin/bash

# --- Configuration ---
MANIFEST_FILE="./manifest.json"
GIT_REMOTE="origin"
# Detect the main branch automatically
if git ls-remote --heads "$GIT_REMOTE" refs/heads/main &> /dev/null; then
  MAIN_BRANCH="main"
elif git ls-remote --heads "$GIT_REMOTE" refs/heads/master &> /dev/null; then
  MAIN_BRANCH="master"
else
  echo "Error: Could not determine main branch (neither 'main' nor 'master' found on remote)."
  exit 1
fi

# --- Functions ---

# Function to get the extension name from manifest.json
get_extension_name() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: $MANIFEST_FILE not found in the current directory."
    exit 1
  fi
  # Extract name field from manifest.json
  sed -n 's/^[[:space:]]*"name":[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST_FILE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# Function to get the version from manifest.json using sed
get_manifest_version() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: $MANIFEST_FILE not found in the current directory."
    exit 1
  fi
  # Use sed to extract the version, handling potential whitespace
  sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST_FILE"
}

# Function to get the latest Git tag
get_latest_git_tag() {
  # Fetch all tags from the remote to ensure we have the latest
  git fetch "$GIT_REMOTE" --tags &> /dev/null

  # Get the latest tag, if any
  LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
  echo "$LATEST_TAG"
}

# Function to compare two semantic versions (v1 > v2 returns 0, v1 <= v2 returns 1)
# Returns 0 if version1 is greater than version2
# Returns 1 if version1 is less than or equal to version2
compare_versions() {
  local v1=$1
  local v2=$2

  # Remove 'v' prefix if present for consistent comparison
  v1=${v1#v}
  v2=${v2#v}

  # Use sort -V for semantic version comparison
  if [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n 1)" == "$v2" && "$v1" != "$v2" ]]; then
    return 0 # v1 is greater than v2
  else
    return 1 # v1 is less than or equal to v2
  fi
}

# Function to check if GitHub remote exists
check_github_remote() {
  if git remote get-url "$GIT_REMOTE" &> /dev/null; then
    REMOTE_URL=$(git remote get-url "$GIT_REMOTE")
    if [[ "$REMOTE_URL" == *"github.com"* ]]; then
      echo "GitHub remote found: $REMOTE_URL"
      return 0
    fi
  fi
  echo "No GitHub remote found"
  return 1
}

# Function to create GitHub repository
create_github_repo() {
  EXTENSION_NAME=$(get_extension_name)
  if [ -z "$EXTENSION_NAME" ]; then
    echo "Error: Could not determine extension name from manifest.json"
    exit 1
  fi

  echo "Creating GitHub repository: $EXTENSION_NAME"
  if ! gh repo create "$EXTENSION_NAME" --public --source=. --remote="$GIT_REMOTE" --push; then
    echo "Error: Failed to create GitHub repository. Make sure you're logged in with 'gh auth login'"
    exit 1
  fi
  echo "GitHub repository created successfully"
}

# --- Main Script ---

echo "--- Starting Version Tagging Script ---"

# 1. Get extension name
EXTENSION_NAME=$(get_extension_name)
if [ -z "$EXTENSION_NAME" ]; then
  echo "Error: Could not determine extension name from manifest.json"
  exit 1
fi
echo "Extension name: $EXTENSION_NAME"

# 2. Check GitHub remote
if ! check_github_remote; then
  echo "No GitHub remote found. Creating new repository..."
  create_github_repo
fi

# 3. Get current manifest version
CURRENT_MANIFEST_VERSION=$(get_manifest_version)
if [ -z "$CURRENT_MANIFEST_VERSION" ]; then
  echo "Error: Could not read version from $MANIFEST_FILE."
  exit 1
fi
echo "Current manifest version: $CURRENT_MANIFEST_VERSION"

# 4. Get latest Git tag
LATEST_GIT_TAG=$(get_latest_git_tag)
echo "Latest Git tag: ${LATEST_GIT_TAG:-"None found"}"

# 5. Compare versions
if [ -z "$LATEST_GIT_TAG" ]; then
  echo "No existing Git tags found. Creating initial tag."
  SHOULD_TAG=true
else
  if compare_versions "$CURRENT_MANIFEST_VERSION" "$LATEST_GIT_TAG"; then
    echo "Manifest version ($CURRENT_MANIFEST_VERSION) is newer than latest Git tag ($LATEST_GIT_TAG)."
    SHOULD_TAG=true
  else
    echo "Manifest version ($CURRENT_MANIFEST_VERSION) is not newer than or equal to latest Git tag ($LATEST_GIT_TAG). No new tag needed."
    SHOULD_TAG=false
  fi
fi

# 6. Create and push tag if needed
if [ "$SHOULD_TAG" = true ]; then
  echo "Creating new tag v$CURRENT_MANIFEST_VERSION..."

  # Ensure local branch is up-to-date before tagging
  echo "Fetching latest changes from $GIT_REMOTE/$MAIN_BRANCH..."
  git pull "$GIT_REMOTE" "$MAIN_BRANCH"

  # Check for uncommitted changes
  if ! git diff-index --quiet HEAD --; then
    echo "Warning: You have uncommitted changes. Please commit or stash them before tagging."
    echo "Aborting tagging process."
    exit 1
  fi

  # Create annotated tag
  git tag -a "v$CURRENT_MANIFEST_VERSION" -m "Release v$CURRENT_MANIFEST_VERSION"

  # Push the new tag first (GitHub CLI needs it to exist remotely)
  echo "Pushing tag v$CURRENT_MANIFEST_VERSION to $GIT_REMOTE..."
  if ! git push "$GIT_REMOTE" "v$CURRENT_MANIFEST_VERSION"; then
    echo "Error: Failed to push tag v$CURRENT_MANIFEST_VERSION. Aborting."
    exit 1
  fi

  # Pack extension to CRX and ZIP
  echo "Packing extension..."
  mkdir -p dist
  if ! npm run pack; then
    echo "Error: Failed to pack extension. Aborting."
    exit 1
  fi

   # Create GitHub release
   echo "Creating GitHub release..."
   CRX_FILE="dist/${EXTENSION_NAME}-v${CURRENT_MANIFEST_VERSION}.crx"
   ZIP_FILE="dist/${EXTENSION_NAME}-v${CURRENT_MANIFEST_VERSION}.zip"
   if ! gh release create "v$CURRENT_MANIFEST_VERSION" \
     --title "Release v$CURRENT_MANIFEST_VERSION" \
     --generate-notes \
     --latest \
     "$CRX_FILE" \
     "$ZIP_FILE"; then
     echo "Error: Failed to create GitHub release. Aborting."
     exit 1
   fi

  # Push current branch to origin
  echo "Pushing changes to $GIT_REMOTE/$MAIN_BRANCH..."
  git push "$GIT_REMOTE" "$MAIN_BRANCH"

   echo "Successfully created release v$CURRENT_MANIFEST_VERSION with extension package."
else
  echo "No new tag created."
fi

echo "--- Script Finished ---"