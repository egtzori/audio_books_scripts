# Cover art resolution for m4b.sh (sourced, not run directly).
# Order: image file next to the audio, art embedded in the audio, online lookup.
# Needs from m4b.sh: CLEANUP, IMAGE_EXTS, AUDIO_EXTS, find_by_ext, find_audio,
# probe_tag, clean_title.

COVER_SIZE="${COVER_SIZE:-1400x1400}"
DOWNLOAD_TIMEOUT_SECONDS=30
COVER_LOOKUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cover_lookup.py"

# image_size FILE -> "WxH" of the first video/image stream, or empty
image_size() {
	ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null | head -1
}

# embedded_art_codec FILE -> codec of embedded cover art (mjpeg, png, ...), or empty
embedded_art_codec() {
	ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$1" 2>/dev/null | head -1
}

# first_image DIR -> path of first image in DIR, or empty
first_image() {
	local img
	IFS= read -r -d '' img < <(find_by_ext "$1" $IMAGE_EXTS) || true
	printf '%s' "$img"
}

# has_audio_named DIR BASE -> success when DIR/BASE.<audio ext> exists
has_audio_named() {
	local ext
	for ext in $AUDIO_EXTS; do [ -f "$1/$2.$ext" ] && return 0; done
	return 1
}

# image_for_file AUDIO_FILE -> Foo.jpg for Foo.mp3, else the first image in the dir
# that is not named after a different audio file (that one belongs to that file)
image_for_file() {
	local file="$1" dir base ext img ibase
	dir="$(dirname "$file")"
	base="$(basename "$file")"; base="${base%.*}"
	for ext in $IMAGE_EXTS JPG JPEG PNG; do
		if [ -f "$dir/$base.$ext" ]; then printf '%s' "$dir/$base.$ext"; return; fi
	done
	while IFS= read -r -d '' img; do
		ibase="$(basename "$img")"; ibase="${ibase%.*}"
		has_audio_named "$dir" "$ibase" && continue
		printf '%s' "$img"
		return
	done < <(find_by_ext "$dir" $IMAGE_EXTS)
}

# extract_embedded_art AUDIO CODEC -> sets COVER_PATH to a temp image file
extract_embedded_art() {
	local audio="$1" codec="$2" tmp
	local copy_args=(-c:v copy)
	tmp="$(mktemp)"; CLEANUP+=("$tmp")
	case "$codec" in
		mjpeg) tmp="$tmp.jpg" ;;
		png) tmp="$tmp.png" ;;
		*) tmp="$tmp.jpg"; copy_args=(-c:v mjpeg) ;;
	esac
	CLEANUP+=("$tmp")
	if ffmpeg -nostdin -loglevel error -y -i "$audio" -map 0:v:0 "${copy_args[@]}" -frames:v 1 -f image2 "$tmp"; then
		COVER_PATH="$tmp"
	else
		COVER_SRC=none
		COVER_INFO="could not extract embedded art from $(basename "$audio")"
	fi
}

# download_image URL DEST -> downloads to DEST only if the result is a readable image
download_image() {
	local url="$1" dest="$2" tmp="$2.part"
	CLEANUP+=("$tmp")
	curl -fsSL --max-time "$DOWNLOAD_TIMEOUT_SECONDS" -o "$tmp" "$url" || return 1
	[ -n "$(image_size "$tmp")" ] || return 1
	mv "$tmp" "$dest"
}

probe_author() {
	local author
	author="$(probe_tag artist "$1")"
	[ -n "$author" ] || author="$(probe_tag album_artist "$1")"
	printf '%s' "$author"
}

# resolve_cover MODE KIND TARGET
#   MODE  probe: report only, no files written | fetch: make COVER_PATH usable
#   KIND  book: TARGET is a book folder | file: TARGET is a single audio file
# Sets COVER_SRC (file|embedded|online|none), COVER_PATH (fetch mode) and COVER_INFO.
# Online covers are saved next to the audio (book: cover.jpg, file: <name>.jpg)
# so later runs reuse them and you can replace a wrong one by hand.
# Must run in the current shell (not in $(...)): it sets globals and CLEANUP.
resolve_cover() {
	local mode="$1" kind="$2" target="$3" audio img save title author
	COVER_SRC=none; COVER_PATH=""; COVER_INFO=""

	if [ "$kind" = book ]; then
		IFS= read -r -d '' audio < <(find_audio "$target") || true
		img="$(first_image "$target")"
		save="$target/cover.jpg"
		title="$(probe_tag album "$audio")"
		[ -n "$title" ] || title="$(basename "$target")"
	else
		audio="$target"
		img="$(image_for_file "$target")"
		save="${target%.*}.jpg"
		title="$(probe_tag album "$audio")"
		[ -n "$title" ] || title="$(probe_tag title "$audio")"
		[ -n "$title" ] || title="$(basename "$audio")"; title="$(clean_title "${title%.*}")"
	fi

	if [ -n "$img" ]; then
		COVER_SRC=file; COVER_PATH="$img"; COVER_INFO="$img ($(image_size "$img"))"
		return
	fi

	local codec
	codec="$(embedded_art_codec "$audio")"
	if [ -n "$codec" ]; then
		COVER_SRC=embedded; COVER_INFO="in $(basename "$audio") ($(image_size "$audio"))"
		if [ "$mode" = fetch ]; then extract_embedded_art "$audio" "$codec"; fi
		return 0
	fi

	author="$(probe_author "$audio")"
	local found url label
	found="$(python3 -I "$COVER_LOOKUP" "$title" "$author" "$COVER_SIZE")" || true
	if [ -z "$found" ]; then
		COVER_INFO="none local, nothing found online for \"$title\""
		return
	fi
	IFS=$'\t' read -r url label _ <<< "$found"
	COVER_INFO="$label <$url>"
	if [ "$mode" = probe ]; then
		COVER_SRC=online; COVER_INFO="will download: $COVER_INFO"
		return
	fi
	if download_image "$url" "$save"; then
		COVER_SRC=online; COVER_PATH="$save"; COVER_INFO="saved $save from $COVER_INFO"
	else
		COVER_INFO="online download failed: $url"
	fi
}

# output_cover_info M4B -> "yes (WxH)" or "MISSING"
output_cover_info() {
	if [ -n "$(embedded_art_codec "$1")" ]; then
		echo "yes ($(image_size "$1"))"
	else
		echo "MISSING"
	fi
}
