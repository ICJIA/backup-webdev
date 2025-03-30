#!/bin/bash
# update-changelog.sh - Updates CHANGELOG.md with recent commits and pushes to git
# This script will pull from remote, push local changes, and update CHANGELOG.md

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if changelog file exists, create if not
CHANGELOG_FILE="$SCRIPT_DIR/CHANGELOG.md"
if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "# Changelog" > "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo "All notable changes to the WebDev Backup Tool will be documented in this file." >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)." >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo "## [Unreleased]" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo "Initial changelog file created." >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Error: Not a git repository.${NC}"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes.${NC}"
    echo -e "Would you like to commit these changes before pushing? (y/n)"
    read -r commit_choice
    
    if [[ "$commit_choice" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Enter commit message:${NC}"
        read -r commit_message
        
        if [ -z "$commit_message" ]; then
            echo -e "${RED}Error: Commit message cannot be empty.${NC}"
            exit 1
        fi
        
        git add .
        git commit -m "$commit_message"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to commit changes.${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}Changes committed successfully.${NC}"
    else
        echo -e "${YELLOW}Continuing without committing changes...${NC}"
    fi
fi

# Get the current branch
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
echo -e "${CYAN}Current branch: $CURRENT_BRANCH${NC}"

# Pull from remote to ensure we're up to date
echo -e "${CYAN}Pulling latest changes from remote...${NC}"
git pull origin "$CURRENT_BRANCH"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to pull from remote. Please resolve conflicts and try again.${NC}"
    exit 1
fi

# Push to remote
echo -e "${CYAN}Pushing to remote...${NC}"
git push origin "$CURRENT_BRANCH"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to push to remote.${NC}"
    exit 1
fi

echo -e "${GREEN}Successfully pushed to remote.${NC}"

# Update CHANGELOG.md with commits since the latest version tag
echo -e "${CYAN}Updating CHANGELOG.md...${NC}"

# Get the most recent version tag (e.g., v1.0.0)
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LATEST_TAG" ]; then
    # If no tags exist, use all commits
    echo -e "${YELLOW}No version tags found. Using all commits.${NC}"
    
    # Update the Unreleased section
    TEMP_FILE=$(mktemp)
    
    # Copy the header part of the CHANGELOG
    sed -n '1,/## \[Unreleased\]/p' "$CHANGELOG_FILE" > "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # Add new commits
    git log --pretty=format:"- %h %s (%an, %ad)" --date=short | while read -r commit_line; do
        # Extract SHA for checking if it's already in changelog
        commit_sha=$(echo "$commit_line" | cut -d' ' -f2)
        
        # Only add if not already in changelog
        if ! grep -q "$commit_sha" "$CHANGELOG_FILE"; then
            echo "$commit_line" >> "$TEMP_FILE"
        fi
    done
    
    echo "" >> "$TEMP_FILE"
    
    # Add the rest of the original file (skip the Unreleased section header)
    sed -n '/## \[Unreleased\]/,$p' "$CHANGELOG_FILE" | tail -n +2 >> "$TEMP_FILE"
    
    # Replace the original file
    mv "$TEMP_FILE" "$CHANGELOG_FILE"
else
    # Get commits since the latest tag
    echo -e "${CYAN}Latest version tag: $LATEST_TAG${NC}"
    
    # Update the Unreleased section
    TEMP_FILE=$(mktemp)
    
    # Copy the header part of the CHANGELOG
    sed -n '1,/## \[Unreleased\]/p' "$CHANGELOG_FILE" > "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # Add new commits
    git log "$LATEST_TAG..HEAD" --pretty=format:"- %h %s (%an, %ad)" --date=short | while read -r commit_line; do
        # Extract SHA for checking if it's already in changelog
        commit_sha=$(echo "$commit_line" | cut -d' ' -f2)
        
        # Only add if not already in changelog
        if ! grep -q "$commit_sha" "$CHANGELOG_FILE"; then
            echo "$commit_line" >> "$TEMP_FILE"
        fi
    done
    
    echo "" >> "$TEMP_FILE"
    
    # Add the rest of the original file (skip the Unreleased section header)
    sed -n '/## \[Unreleased\]/,$p' "$CHANGELOG_FILE" | tail -n +2 >> "$TEMP_FILE"
    
    # Replace the original file
    mv "$TEMP_FILE" "$CHANGELOG_FILE"
fi

# Commit the updated CHANGELOG.md
git add "$CHANGELOG_FILE"
git commit -m "docs: update CHANGELOG.md with latest commits"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to commit CHANGELOG.md updates.${NC}"
    exit 1
fi

# Push the CHANGELOG commit
git push origin "$CURRENT_BRANCH"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to push CHANGELOG.md updates.${NC}"
    exit 1
fi

echo -e "${GREEN}CHANGELOG.md updated and pushed successfully.${NC}"

# Suggest creating a new version tag if there are significant changes
echo -e "${CYAN}Would you like to create a new version tag? (y/n)${NC}"
read -r tag_choice

if [[ "$tag_choice" =~ ^[Yy]$ ]]; then
    if [ -z "$LATEST_TAG" ]; then
        echo -e "${CYAN}No previous tag found. Suggested new tag: v1.0.0${NC}"
        echo -e "Enter new version tag (e.g., v1.0.0):"
        read -r new_tag
    else
        # Parse the current version
        MAJOR=$(echo "$LATEST_TAG" | sed -E 's/v([0-9]+)\.[0-9]+\.[0-9]+/\1/')
        MINOR=$(echo "$LATEST_TAG" | sed -E 's/v[0-9]+\.([0-9]+)\.[0-9]+/\1/')
        PATCH=$(echo "$LATEST_TAG" | sed -E 's/v[0-9]+\.[0-9]+\.([0-9]+)/\1/')
        
        # Increment patch version
        PATCH=$((PATCH + 1))
        
        echo -e "${CYAN}Current version: $LATEST_TAG${NC}"
        echo -e "${CYAN}Suggested new tag: v$MAJOR.$MINOR.$PATCH${NC}"
        echo -e "Enter new version tag (or press Enter to use suggestion):"
        read -r new_tag
        
        if [ -z "$new_tag" ]; then
            new_tag="v$MAJOR.$MINOR.$PATCH"
        fi
    fi
    
    # Create and push the new tag
    git tag -a "$new_tag" -m "Release $new_tag"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create tag $new_tag.${NC}"
        exit 1
    fi
    
    git push origin "$new_tag"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to push tag $new_tag.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Tag $new_tag created and pushed successfully.${NC}"
    
    # Update CHANGELOG.md with the new release
    TEMP_FILE=$(mktemp)
    
    # Copy everything up to the Unreleased section
    sed -n '1,/## \[Unreleased\]/p' "$CHANGELOG_FILE" > "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # Add new release section
    echo "## [$new_tag] - $(date +%Y-%m-%d)" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # Add all unreleased changes to the new release section
    UNRELEASED_CONTENT=$(sed -n '/## \[Unreleased\]/,/##/p' "$CHANGELOG_FILE" | tail -n +2 | sed '/##/d')
    echo "$UNRELEASED_CONTENT" >> "$TEMP_FILE"
    
    # Add the rest of the file (below the Unreleased section)
    sed -n '/## \[Unreleased\]/,$p' "$CHANGELOG_FILE" | tail -n +2 >> "$TEMP_FILE"
    
    # Replace the original file
    mv "$TEMP_FILE" "$CHANGELOG_FILE"
    
    # Commit and push the updated CHANGELOG
    git add "$CHANGELOG_FILE"
    git commit -m "docs: update CHANGELOG.md for release $new_tag"
    git push origin "$CURRENT_BRANCH"
    
    echo -e "${GREEN}CHANGELOG.md updated for release $new_tag and pushed successfully.${NC}"
fi

echo -e "${GREEN}All operations completed successfully.${NC}"
exit 0