#!/usr/bin/env bash
set -euo pipefail

# Release helper for Clearport
# Usage: ./scripts/release.sh [patch|minor|major]

MODE="${1:-patch}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CURRENT_VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1 | tr -d '[:space:]')
CURRENT_BUILD=$(grep '^version: ' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2 | tr -d '[:space:]')

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$MODE" in
  patch)
    PATCH=$((PATCH + 1))
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  *)
    echo "Unknown mode: $MODE (use patch, minor, or major)"
    exit 1
    ;;
esac

NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH"
NEW_TAG="v$NEW_VERSION"

echo "Bumping version from $CURRENT_VERSION+$CURRENT_BUILD to $NEW_VERSION+$NEW_BUILD (tag $NEW_TAG)..."

# Update pubspec.yaml
sed -i "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml

# Run tests and analyze
echo "Running tests..."
flutter test
flutter analyze

# Git commit, tag, and push
git add pubspec.yaml
git commit -m "chore(release): $NEW_TAG [release]"
git tag -a "$NEW_TAG" -m "Release $NEW_TAG"

echo "Pushing main and $NEW_TAG to origin..."
git push origin main
git push origin "$NEW_TAG"

echo ""
echo "🎉 Release $NEW_TAG triggered!"
echo "GitHub Actions is building clearport-android-universal.apk."
echo "Download URL (latest):"
echo "  https://github.com/Adams-404/clearport/releases/latest/download/clearport-android-universal.apk"
echo "Download URL ($NEW_TAG):"
echo "  https://github.com/Adams-404/clearport/releases/download/$NEW_TAG/clearport-android-universal.apk"
