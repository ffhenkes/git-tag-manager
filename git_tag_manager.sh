#!/bin/bash
# git_tag_manager.sh
# ------------------------------------------------------------------------------
# Git Tag Manager - Script to manage Git tag versions and configure project settings
#
# Author: [Fabio Favero Henkes]
# Created: [25/02/2025]
# License: MIT
#
# Description:
#   This script simplifies version control management by handling Git tags
#   according to semantic versioning (major.minor.patch-build). It supports:
#     - Project configuration with aliases, local paths, and remote URLs.
#     - Tag version incrementation (major, minor, patch, build).
#     - Remote synchronization to ensure tags reflect the latest remote state.
#     - Dry-run mode to preview Git push commands without execution.
#
# Configuration:
#   Project details are stored in a configuration file.
#   Each line should follow the format:
#     alias|local_path|url
#
# Usage:
#   - Configure a project:
#       git-tag-manager --config "alias|/path/to/project|git@repository_url.git"
#   - Increment versions:
#       git-tag-manager --alias alias --build --inc         # Increment build
#       git-tag-manager --alias alias --patch --inc         # Increment patch
#       git-tag-manager --alias alias --minor --inc         # Increment minor
#       git-tag-manager --alias alias --major --inc         # Increment major
#   - Dry run (no push):
#       git-tag-manager --alias alias --patch --inc --dry-run
#
# Notes:
#   - Ensure SSH keys are configured for remote Git access.
#   - Tags are always synchronized with the remote before changes.
#   - If a local repository doesn't exist, it will be cloned automatically.
# ------------------------------------------------------------------------------

CONFIG_FILE="$HOME/.git_projects.conf"

# Function to display help/usage text
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

OPTIONS:
  --config "alias|path|url"   Add or update project configuration.
                              Provide project alias, local repository path, and remote URL separated by '|'.
  --alias <alias>             Specify the alias of the project (required for tag management).
  --build                   Include build number in tag (format: X.Y.Z-B).
  --inc                     Increment the version.
  --major                   Increment major version (with --build --inc, sets version to (major+1).0.0-1).
  --minor                   Increment minor version (with --build --inc, sets version to major.(minor+1).0-1).
  --patch                   Increment patch version (with --build --inc, sets version to major.minor.(patch+1)-1).
  --dry-run                 Print the git push command instead of pushing the tag.
  -h, --help                Display this help and exit.

Examples:
  # Add or update project configuration:
  $(basename "$0") --config "chest|/path/to/repo/|git@host:username/repo.git"

  # Increment only the build number:
  $(basename "$0") --alias chest --build --inc

  # Increment the patch version:
  $(basename "$0") --alias chest --build --patch --inc

  # Create a release tag (without build number):
  $(basename "$0") --alias chest --major
EOF
    exit 0
}

# If no parameters are provided, show help.
if [[ $# -eq 0 ]]; then
    usage
fi

# --- Configuration Block ---
# If the first argument is --config, process the addition/update of the project configuration
if [[ "$1" == "--config" ]]; then
    if [[ -z "$2" ]]; then
        echo "You must provide the data in the format: alias|path|url (enclose the string in quotes)."
        usage
    fi

    CONFIG_ENTRY="$2"
    # Extract fields using 'cut'
    ALIAS_CFG=$(echo "$CONFIG_ENTRY" | cut -d'|' -f1)
    PATH_CFG=$(echo "$CONFIG_ENTRY" | cut -d'|' -f2)
    URL_CFG=$(echo "$CONFIG_ENTRY" | cut -d'|' -f3)

    # Check if all fields are provided
    if [[ -z "$ALIAS_CFG" || -z "$PATH_CFG" || -z "$URL_CFG" ]]; then
        echo "Invalid format! Use: alias|path|url"
        exit 1
    fi

    # Check if the local repository exists
    if [[ -d "$PATH_CFG" ]]; then
        # Check if it's a valid Git repository (has a .git directory)
        if [[ -d "$PATH_CFG/.git" ]]; then
            CURRENT_REMOTE=$(git -C "$PATH_CFG" remote get-url origin 2>/dev/null)
            if [[ "$CURRENT_REMOTE" == "$URL_CFG" ]]; then
                echo "Repository for alias '$ALIAS_CFG' is already configured correctly."
            else
                echo "Remote URL mismatch for alias '$ALIAS_CFG'. Updating remote URL..."
                git -C "$PATH_CFG" remote set-url origin "$URL_CFG"
                if [[ $? -eq 0 ]]; then
                    echo "Remote URL updated successfully."
                else
                    echo "Failed to update remote URL."
                    exit 1
                fi
            fi
        else
            echo "Directory exists but is not a valid Git repository. Cloning repository into the directory..."
            git clone "$URL_CFG" "$PATH_CFG"
            if [[ $? -eq 0 ]]; then
                echo "Repository cloned successfully."
            else
                echo "Failed to clone repository."
                exit 1
            fi
        fi
    else
        echo "Local repository not found. Cloning repository..."
        git clone "$URL_CFG" "$PATH_CFG"
        if [[ $? -eq 0 ]]; then
            echo "Repository cloned successfully."
        else
            echo "Failed to clone repository."
            exit 1
        fi
    fi

    # Create the configuration file if it does not exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
    fi

    # Check if the alias already exists in the configuration file
    if grep -q "^$ALIAS_CFG|" "$CONFIG_FILE"; then
        echo "Updating configuration for alias '$ALIAS_CFG'."
        sed -i.bak "/^$ALIAS_CFG|/c\\$ALIAS_CFG|$PATH_CFG|$URL_CFG" "$CONFIG_FILE"
    else
        # Append a new line with the configuration details
        echo "$ALIAS_CFG|$PATH_CFG|$URL_CFG" >> "$CONFIG_FILE"
        echo "Configuration for alias '$ALIAS_CFG' added successfully."
    fi
    exit 0
fi
# --- End of Configuration Block ---

# Default variables for tag management
ALIAS=""
BUILD_FLAG=false
INC_FLAG=false
BUMP_TYPE=""
DRY_RUN=false

# Process arguments for tag management
while [[ $# -gt 0 ]]; do
    case "$1" in
        --alias)
            shift
            ALIAS="$1"
            ;;
        --build)
            BUILD_FLAG=true
            ;;
        --inc)
            INC_FLAG=true
            ;;
        --major)
            BUMP_TYPE="major"
            ;;
        --minor)
            BUMP_TYPE="minor"
            ;;
        --patch)
            BUMP_TYPE="patch"
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
    shift
done

if [[ -z "$ALIAS" ]]; then
    echo "The --alias parameter is required for tag management."
    usage
fi

# Check if the configuration file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Search for the project in the configuration file (format: alias|local_path|url)
PROJECT_LINE=$(grep "^$ALIAS|" "$CONFIG_FILE")
if [[ -z "$PROJECT_LINE" ]]; then
    echo "Project with alias '$ALIAS' not found in the configuration file."
    exit 1
fi

IFS='|' read -r proj_alias proj_path proj_url <<< "$PROJECT_LINE"
echo "Project found: $proj_alias"
echo "Local path: $proj_path"
echo "URL: $proj_url"

# Check if the project directory exists
if [[ ! -d "$proj_path" ]]; then
    echo "Project directory not found: $proj_path"
    exit 1
fi

# Change to the project directory
cd "$proj_path" || exit 1

# Synchronize local tags with remote tags
echo "Synchronizing local tags with remote..."
local_tags=$(git tag -l)
if [[ -n "$local_tags" ]]; then
    echo "$local_tags" | xargs -r git tag -d
fi
git fetch --tags

# Get the latest tag matching the pattern X.Y.Z or X.Y.Z-B
LAST_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$' | head -n 1)
if [[ -z "$LAST_TAG" ]]; then
    # If there are no tags, set a default base value (e.g., 0.0.0-0)
    LAST_TAG="0.0.0-0"
fi
echo "Last tag found: $LAST_TAG"

# Function to extract version components:
# Returns: major, minor, patch, and build (if present)
parse_version() {
    local ver="$1"
    local base build
    base="${ver%%-*}"  # everything before the first hyphen
    if [[ "$ver" == *"-"* ]]; then
        build="${ver##*-}"
    else
        build=0
    fi
    IFS='.' read -r major minor patch <<< "$base"
    echo "$major" "$minor" "$patch" "$build"
}

read major minor patch build <<< "$(parse_version "$LAST_TAG")"

# Calculate the new tag based on the parameters
if $BUILD_FLAG; then
    # If the --build flag is set, the new tag will include the build number.
    if $INC_FLAG; then
        case "$BUMP_TYPE" in
            major)
                major=$((major + 1))
                minor=0
                patch=0
                build=1
                ;;
            minor)
                minor=$((minor + 1))
                patch=0
                build=1
                ;;
            patch)
                patch=$((patch + 1))
                build=1
                ;;
            "")
                # Only increment the build while keeping the base version
                build=$((build + 1))
                ;;
        esac
    else
        echo "The --inc flag was not provided. No version update will be made."
        exit 0
    fi
    NEW_TAG="${major}.${minor}.${patch}-${build}"
else
    # If --build is not set, create a release tag (remove the build number)
    NEW_TAG="${major}.${minor}.${patch}"
fi

echo "New tag to be created: $NEW_TAG"

# Create the new Git tag
git tag "$NEW_TAG"
if [[ $? -ne 0 ]]; then
    echo "Error creating the tag."
    exit 1
fi

echo "Tag '$NEW_TAG' created successfully."

# Finally push the tag: if --dry-run is set, print the push command; otherwise, push.
if $DRY_RUN; then
    printf "git push origin %s\n" "$NEW_TAG"
else
    git push origin "$NEW_TAG"
fi

exit 0
