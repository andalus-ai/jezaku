#!/bin/bash

# Miku Desktop - Release Helper Script
# Automates the process of creating a new desktop release

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Get current version from pubspec.yaml
get_current_version() {
    grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//'
}

# Increment version
increment_version() {
    local version=$1
    local part=$2
    
    IFS='.' read -r -a parts <<< "$version"
    major=${parts[0]}
    minor=${parts[1]}
    patch=${parts[2]}
    
    case $part in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Main script
print_header "Miku Desktop Release Helper"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found in $PROJECT_DIR."
    exit 1
fi

# Get current version
CURRENT_VERSION=$(get_current_version)
print_info "Current version: $CURRENT_VERSION"

# Ask for version bump type
echo ""
echo "Select version bump type:"
echo "  1) Patch (bug fixes)      - $CURRENT_VERSION -> $(increment_version $CURRENT_VERSION patch)"
echo "  2) Minor (new features)   - $CURRENT_VERSION -> $(increment_version $CURRENT_VERSION minor)"
echo "  3) Major (breaking changes) - $CURRENT_VERSION -> $(increment_version $CURRENT_VERSION major)"
echo "  4) Custom version"
echo "  5) Cancel"
echo ""
read -p "Enter choice [1-5]: " choice

case $choice in
    1)
        NEW_VERSION=$(increment_version $CURRENT_VERSION patch)
        ;;
    2)
        NEW_VERSION=$(increment_version $CURRENT_VERSION minor)
        ;;
    3)
        NEW_VERSION=$(increment_version $CURRENT_VERSION major)
        ;;
    4)
        read -p "Enter new version (e.g., 1.0.0): " NEW_VERSION
        ;;
    5)
        print_info "Cancelled"
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

print_info "New version will be: $NEW_VERSION"

# Get current build number
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | sed 's/.*+//')
NEW_BUILD=$((CURRENT_BUILD + 1))

print_info "Build number: $CURRENT_BUILD -> $NEW_BUILD"

# Confirm
echo ""
read -p "Update version to $NEW_VERSION+$NEW_BUILD? [y/N]: " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_info "Cancelled"
    exit 0
fi

# Update pubspec.yaml
print_header "Updating pubspec.yaml"
sed -i.bak "s/^version:.*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml
rm pubspec.yaml.bak
print_success "Updated pubspec.yaml"

# Ask for changelog entry
echo ""
read -p "Enter changelog entry (or press Enter to skip): " changelog
if [ -n "$changelog" ]; then
    if [ ! -f "CHANGELOG.md" ]; then
        echo "# Changelog" > CHANGELOG.md
        echo "" >> CHANGELOG.md
    fi
    
    # Add entry to CHANGELOG.md
    {
        echo "## [$NEW_VERSION] - $(date +%Y-%m-%d)"
        echo ""
        echo "- $changelog"
        echo ""
        cat CHANGELOG.md
    } > CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
    
    print_success "Updated CHANGELOG.md"
fi

# Git operations
print_header "Git Operations"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_warning "You have uncommitted changes"
    read -p "Commit changes? [y/N]: " commit_changes
    
    if [[ $commit_changes =~ ^[Yy]$ ]]; then
        git add pubspec.yaml
        [ -f "CHANGELOG.md" ] && git add CHANGELOG.md
        git commit -m "Bump version to $NEW_VERSION"
        print_success "Changes committed"
    else
        print_warning "Skipping commit"
    fi
fi

# Create tag
print_info "Creating tag v$NEW_VERSION"
if git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION"; then
    print_success "Tag created: v$NEW_VERSION"
else
    print_error "Failed to create tag"
    exit 1
fi

# Push changes
echo ""
read -p "Push changes and tag to GitHub? [y/N]: " push_confirm
if [[ $push_confirm =~ ^[Yy]$ ]]; then
    print_info "Pushing to GitHub..."
    
    # Push commits
    if git push origin $(git branch --show-current); then
        print_success "Pushed commits"
    else
        print_error "Failed to push commits"
        exit 1
    fi
    
    # Push tag
    if git push origin "v$NEW_VERSION"; then
        print_success "Pushed tag v$NEW_VERSION"
    else
        print_error "Failed to push tag"
        exit 1
    fi
    
    print_success "Release triggered!"
    echo ""
    print_info "GitHub Actions will now build desktop apps for all platforms"
    print_info "Monitor progress at: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
else
    print_warning "Skipped push. To push manually:"
    echo "  git push origin $(git branch --show-current)"
    echo "  git push origin v$NEW_VERSION"
fi

print_header "Summary"
echo "Version: $CURRENT_VERSION -> $NEW_VERSION"
echo "Build: $CURRENT_BUILD -> $NEW_BUILD"
echo "Tag: v$NEW_VERSION"
echo ""
print_success "Release preparation complete!"
