#!/usr/bin/env bash
# Build a WordPress.org-ready zip. Staging under reactpress-blog/ so the
# archive root matches the theme slug; pack.sh / docs stay out of the package.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
THEME_NAME="reactpress-blog"
DIST="$REPO_ROOT/dist"
ZIP="$DIST/${THEME_NAME}.zip"
STAGE="$(mktemp -d)"
STAGE_THEME="$STAGE/$THEME_NAME"

cleanup() {
	rm -rf "$STAGE"
}
trap cleanup EXIT

if [[ ! -f "$REPO_ROOT/style.css" || ! -f "$REPO_ROOT/theme.json" ]]; then
	echo "Theme files not found at repo root (style.css / theme.json)." >&2
	exit 1
fi

mkdir -p "$DIST" "$STAGE_THEME"
rm -f "$ZIP"

# Copy theme files into a slug-named folder for the zip root.
rsync -a \
	--exclude '.git/' \
	--exclude '.DS_Store' \
	--exclude 'dist/' \
	--exclude 'pack.sh' \
	--exclude 'README.md' \
	--exclude 'SUBMIT.md' \
	--exclude '.gitignore' \
	--exclude 'bin/' \
	--exclude 'assets/js/blocks-editor.js' \
	"$REPO_ROOT/" "$STAGE_THEME/"

(
	cd "$STAGE"
	zip -r "$ZIP" "$THEME_NAME"
)

echo "Created: $ZIP"
LISTING="$(unzip -l "$ZIP")"
echo "$LISTING" | head -n 40
echo
echo "Sanity checks:"
if echo "$LISTING" | grep -E '\.sh$|blocks-editor\.js|/bin/|SUBMIT\.md|/\.gitignore$' >/dev/null; then
	echo "ERROR: package still contains shell scripts, docs, or excluded paths" >&2
	echo "$LISTING" | grep -E '\.sh$|blocks-editor\.js|/bin/|SUBMIT\.md|/\.gitignore$' || true
	exit 1
fi
if ! echo "$LISTING" | grep -F "${THEME_NAME}/inc/setup.php" >/dev/null; then
	echo "ERROR: package missing inc/ modules" >&2
	exit 1
fi
if ! echo "$LISTING" | grep -F "${THEME_NAME}/style.css" >/dev/null; then
	echo "ERROR: package missing style.css at theme root" >&2
	exit 1
fi
echo "OK: zip root is ${THEME_NAME}/; no pack/docs leakage"
