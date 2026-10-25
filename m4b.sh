#!/usr/bin/env bash
# Convert audio files to M4B audiobooks with ffmpeg.
# Called from the Makefile; see `make help`. Filenames with spaces, quotes and
# brackets are supported throughout (NUL-delimited find, quoted expansions).

set -euo pipefail

INPUT_DIR="${INPUT_DIR:-input}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"
BITRATE="${BITRATE:-128k}"
# FORCE=1 re-encodes book folders that already contain an .m4b instead of copying it
FORCE="${FORCE:-0}"

AUDIO_EXTS="mp3 wav flac aac ogg m4a wma"
IMAGE_EXTS="jpg jpeg png"

# Temp files to remove on exit (partial .m4a, concat list, chapter metadata).
CLEANUP=()
cleanup() {
	local f
	for f in ${CLEANUP[@]+"${CLEANUP[@]}"}; do rm -f "$f"; done
}
trap cleanup EXIT
trap 'exit 130' INT TERM

die() { echo "Error: $*" >&2; exit 1; }

# find_by_ext DIR EXTS... -> NUL-delimited, version-sorted file list (top level only)
find_by_ext() {
	local dir="$1"; shift
	local args=() ext
	for ext in "$@"; do
		[ ${#args[@]} -gt 0 ] && args+=(-o)
		args+=(-iname "*.$ext")
	done
	find "$dir" -maxdepth 1 -type f \( "${args[@]}" \) -print0 | sort -z -V
}

find_audio() { find_by_ext "$1" $AUDIO_EXTS; }

probe_tag() { ffprobe -v quiet -show_entries "format_tags=$1" -of default=nw=1:nk=1 "$2" 2>/dev/null | tr -d '\r' | head -1; }
probe_duration() { ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null | tr -d '\r'; }

# Escape a value for ffmetadata: '=', ';', '#', '\' and newline need a backslash.
meta_escape() { printf '%s' "$1" | sed -e 's/[\\=;#]/\\&/g'; }

# Escape a path for the concat demuxer's single-quoted 'file' directive.
concat_escape() { printf '%s' "$1" | sed -e "s/'/'\\\\''/g"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cover.sh
source "$SCRIPT_DIR/cover.sh"
# shellcheck source=naming.sh
source "$SCRIPT_DIR/naming.sh"

# Strip leading track numbers like "01 - ", "[01 - 21] " from a name.
# Pass names without extension: folder names may contain dots ("R.H. Lustig").
clean_title() {
	printf '%s' "$1" | sed -E 's/^\[[0-9]+[^]]*\][[:space:]]*//; s/^[0-9]+[[:space:]]*-?[[:space:]]*//'
}

# Make a tag value safe as a filename: '/' and ':' are not allowed on macOS.
safe_filename() { printf '%s' "$1" | sed -e 's#/#-#g; s/[[:space:]]*:[[:space:]]*/ - /g'; }

# first_m4b DIR -> first .m4b anywhere inside DIR (e.g. a ready-made single-file
# release shipped next to the mp3s), or empty
first_m4b() {
	local m4b
	IFS= read -r -d '' m4b < <(find "$1" -type f -iname "*.m4b" -print0 | sort -z -V) || true
	printf '%s' "$m4b"
}

# book_output DIR -> output .m4b path for concatenating DIR, or empty if DIR has no audio
book_output() {
	local dir="$1" first
	IFS= read -r -d '' first < <(find_audio "$dir") || true
	[ -n "$first" ] || return 0
	printf '%s/%s.m4b' "$OUTPUT_DIR" "$(output_name book "$dir")"
}

# book_state DIR -> "<state>|<path>" where state is one of:
#   done     output already exists in OUTPUT_DIR (path = output)
#   has-m4b  folder already contains an .m4b (path = that file); it is copied to
#            OUTPUT_DIR under the standard name instead of re-encoding. FORCE=1 overrides
#   pending  needs converting (path = output that will be written)
#   empty    no audio files
book_state() {
	local dir="$1" output m4b
	output="$(book_output "$dir")"
	if [ -z "$output" ]; then echo "empty|"; return; fi
	if [ -f "$output" ]; then echo "done|$output"; return; fi
	if [ "$FORCE" != "1" ] && [ "$(cd "$dir" && pwd)" != "$(cd "$INPUT_DIR" && pwd)" ]; then
		m4b="$(first_m4b "$dir")"
		if [ -n "$m4b" ]; then echo "has-m4b|$m4b"; return; fi
	fi
	echo "pending|$output"
}

# encode OUTPUT_M4B COVER INPUT_ARGS... -- EXTRA_ARGS...
# Encodes to a temp .m4a next to the output, then renames to .m4b on success.
encode() {
	local output="$1" cover="$2"; shift 2
	local inputs=() extra=()
	while [ $# -gt 0 ] && [ "$1" != "--" ]; do inputs+=("$1"); shift; done
	[ $# -gt 0 ] && shift
	extra=("$@")

	local tmp="${output%.m4b}.m4a"
	CLEANUP+=("$tmp")

	local n_inputs=0 a
	for a in "${inputs[@]}"; do [ "$a" = "-i" ] && n_inputs=$((n_inputs + 1)); done

	local cover_args=(-vn)
	if [ -n "$cover" ]; then
		inputs+=(-i "$cover")
		cover_args=(-map "$n_inputs:v" -c:v copy -disposition:v:0 attached_pic)
	fi

	ffmpeg -nostdin -hide_banner -loglevel warning -stats -y \
		"${inputs[@]}" \
		-map 0:a "${cover_args[@]}" \
		${extra[@]+"${extra[@]}"} \
		-threads 0 -c:a aac -b:a "$BITRATE" -movflags +faststart \
		"$tmp" || return 1
	mv "$tmp" "$output"
}

cmd_all() {
	mkdir -p "$OUTPUT_DIR"
	local file found=0
	while IFS= read -r -d '' file; do
		found=1
		local id author title output
		id="$(book_identity file "$file")"
		author="${id%%$'\t'*}"; title="${id#*$'\t'}"
		output="$OUTPUT_DIR/$(output_name file "$file").m4b"
		if [ -f "$output" ]; then
			echo "Skipping (already exists): $output"
			continue
		fi
		echo "Converting: $file -> $output"
		resolve_cover fetch file "$file"
		echo "  cover [$COVER_SRC]: $COVER_INFO"
		encode "$output" "$COVER_PATH" -i "$file" -- \
			-metadata title="$title" -metadata album="$title" \
			-metadata artist="${author:-$UNKNOWN_AUTHOR}" -metadata genre=Audiobook
	done < <(find_audio "$INPUT_DIR")
	[ "$found" -eq 1 ] || echo "No audio files in $INPUT_DIR/ (books in subfolders: use 'make books')"
}

# write_concat_files DIR LIST_FILE META_FILE TITLE ARTIST -> fills concat list and chapter metadata
write_concat_files() {
	local dir="$1" list="$2" meta="$3" title="$4" artist="$5"
	local abs_dir file start_ms=0 count=0
	abs_dir="$(cd "$dir" && pwd)"

	{
		echo ";FFMETADATA1"
		echo "title=$(meta_escape "$title")"
		echo "album=$(meta_escape "$title")"
		[ -n "$artist" ] && echo "artist=$(meta_escape "$artist")"
		echo "genre=Audiobook"
	} > "$meta"
	: > "$list"

	while IFS= read -r -d '' file; do
		local base duration dur_ms chapter
		base="$(basename "$file")"
		duration="$(probe_duration "$file")"
		[ -n "$duration" ] || die "cannot read duration of $file"
		dur_ms="$(awk -v d="$duration" 'BEGIN { printf "%d", d * 1000 }')"
		chapter="$(probe_tag title "$file")"
		[ -n "$chapter" ] || chapter="$(clean_title "${base%.*}")"

		echo "file '$(concat_escape "$abs_dir/$base")'" >> "$list"
		{
			echo "[CHAPTER]"
			echo "TIMEBASE=1/1000"
			echo "START=$start_ms"
			echo "END=$((start_ms + dur_ms))"
			echo "title=$(meta_escape "$chapter")"
		} >> "$meta"
		start_ms=$((start_ms + dur_ms))
		count=$((count + 1))
	done < <(find_audio "$dir")

	echo "$count"
}

# copy_existing_m4b SRC DEST -> copy a ready-made .m4b to DEST (via a temp file,
# so an interrupted copy never looks like a finished output)
copy_existing_m4b() {
	local src="$1" dest="$2" tmp="$2.part"
	echo "Copying existing m4b (FORCE=1 to re-encode instead):"
	echo "  from: $src"
	echo "  to:   $dest"
	CLEANUP+=("$tmp")
	cp "$src" "$tmp"
	mv "$tmp" "$dest"
	echo "Done: $dest"
}

cmd_concat() {
	local dir="${1:-$INPUT_DIR}"
	[ -d "$dir" ] || die "not a directory: $dir"
	mkdir -p "$OUTPUT_DIR"

	local state path
	state="$(book_state "$dir")"; path="${state#*|}"; state="${state%%|*}"
	case "$state" in
		empty) echo "No audio files found in $dir/"; return 1 ;;
		done) echo "Skipping (already converted): $path"; return 0 ;;
		has-m4b) copy_existing_m4b "$path" "$(book_output "$dir")"; return 0 ;;
	esac

	local id author title output="$path"
	id="$(book_identity book "$dir")"
	author="${id%%$'\t'*}"; title="${id#*$'\t'}"

	local list meta count
	list="$(mktemp)"; meta="$(mktemp)"
	CLEANUP+=("$list" "$meta")
	count="$(write_concat_files "$dir" "$list" "$meta" "$title" "${author:-$UNKNOWN_AUTHOR}")"

	echo "Creating: $output ($count files, $count chapters)"
	resolve_cover fetch book "$dir"
	echo "  cover [$COVER_SRC]: $COVER_INFO"
	encode "$output" "$COVER_PATH" \
		-f concat -safe 0 -i "$list" -i "$meta" \
		-- -map_metadata 1 -map_chapters 1
	echo "Done: $output"
}

cmd_books() {
	local dir found=0
	while IFS= read -r -d '' dir; do
		found=1
		echo "== $(basename "$dir")"
		if [ "$(book_state "$dir")" = "empty|" ]; then
			echo "  (no audio files, skipped)"
			continue
		fi
		cmd_concat "$dir"
	done < <(find "$INPUT_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z -V)
	[ "$found" -eq 1 ] || echo "No subfolders in $INPUT_DIR/"
}

cmd_status() {
	local file dir pending=0
	echo "Top-level input files (make all):"
	while IFS= read -r -d '' file; do
		echo ""
		local output
		output="$OUTPUT_DIR/$(output_name file "$file").m4b"
		if [ -f "$output" ]; then
			echo "  [done]    $file -> $output"
			echo "            cover: $(output_cover_info "$output")"
		else
			echo "  [pending] $file -> $output"
			resolve_cover probe file "$file"
			echo "            cover [$COVER_SRC]: $COVER_INFO"
			pending=$((pending + 1))
		fi
	done < <(find_audio "$INPUT_DIR")
	echo ""
	echo "Book folders (make books):"
	while IFS= read -r -d '' dir; do
		echo ""
		local state path n
		state="$(book_state "$dir")"; path="${state#*|}"; state="${state%%|*}"
		n="$(find_audio "$dir" | tr -cd '\0' | wc -c | tr -d ' ')"
		echo "  [$state] $(basename "$dir") ($n audio files)"
		case "$state" in
			done)
				echo "            output: $path"
				echo "            cover: $(output_cover_info "$path")"
				;;
			has-m4b)
				echo "            found:  $path"
				echo "            will copy to: $(book_output "$dir") (FORCE=1 to re-encode instead)"
				echo "            cover: $(output_cover_info "$path")"
				pending=$((pending + 1))
				;;
			pending)
				echo "            will write: $path"
				resolve_cover probe book "$dir"
				echo "            cover [$COVER_SRC]: $COVER_INFO"
				pending=$((pending + 1))
				;;
		esac
	done < <(find "$INPUT_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z -V)
	echo ""
	echo "$pending to convert."
}

case "${1:-}" in
	all) cmd_all ;;
	concat) cmd_concat "${2:-}" ;;
	books) cmd_books ;;
	status) cmd_status ;;
	*) die "usage: $0 {all|concat [DIR]|books|status}" ;;
esac
