#!/bin/bash
set -euo pipefail

command -v rsvg-convert >/dev/null 2>&1 || {
	echo >&2 "rsvg-convert is required but not installed. Aborting."
	exit 1
}

has_command() {
	command -v "$1" >/dev/null 2>&1
}

# Temp folder
ICON_DIR="icons"
rm -rf "$ICON_DIR"
mkdir -p "$ICON_DIR"

# Generate PNG icons from SVG
SIZES=(16 32 64 128 256 512)
for size in "${SIZES[@]}"; do
	outfile="assets/logo_${size}.png"
	rsvg-convert -w "$size" -h "$size" assets/logo.svg -o "$outfile"

	if has_command pngquant; then
		pngquant --force --quality=60-80 "$outfile" --output "$outfile"
	else
		echo "Skipping pngquant optimization for $outfile; pngquant is not installed."
	fi

	if has_command optipng; then
		optipng -quiet -o5 "$outfile"
	else
		echo "Skipping optipng optimization for $outfile; optipng is not installed."
	fi

	if [ "$size" -le 32 ] && has_command magick; then
		magick "$outfile" -colors 256 PNG8:"$outfile"
	fi

	cp "$outfile" "$ICON_DIR/logo_${size}.png"
done

if has_command iconutil; then
	ICONSET_DIR="$ICON_DIR/qtspot.iconset"
	mkdir -p "$ICONSET_DIR"
	for size in "${SIZES[@]}"; do
		cp "$ICON_DIR/logo_${size}.png" "$ICONSET_DIR/icon_${size}x${size}.png"
		if [ "$size" -ne 16 ] && [ "$size" -ne 32 ]; then
			cp "$ICON_DIR/logo_${size}.png" "$ICONSET_DIR/icon_$((size / 2))x$((size / 2))@2x.png"
		fi
	done

	iconutil -c icns "$ICONSET_DIR" -o assets/logo.icns
	echo "ICNS file size: $(du -h assets/logo.icns | cut -f1)"
else
	echo "Skipping macOS ICNS generation; iconutil is not installed."
fi

# Cleanup
rm -r "$ICON_DIR"

echo "Icon generation complete."
