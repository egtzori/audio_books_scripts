# Output naming for m4b.sh (sourced, not run directly).
# Every output is named "Author - Title.m4b" (full title, edition notes such as
# "(Unabridged)" removed). Needs from m4b.sh / cover.sh: INPUT_DIR, find_audio,
# probe_tag, probe_author, clean_title, safe_filename, COVER_LOOKUP.

UNKNOWN_AUTHOR="Unknown Author"

# strip_edition TITLE -> TITLE without "(Unabridged)", "[Abridged Edition]" and the like
strip_edition() {
	printf '%s' "$1" | sed -E \
		-e 's/[[:space:]]*[([]([Uu][Nn])?[Aa][Bb][Rr][Ii][Dd][Gg][Ee][Dd]([[:space:]]+[Ee][Dd][Ii][Tt][Ii][Oo][Nn])?[])]//g' \
		-e 's/[[:space:]]+$//'
}

# word_overlap A B -> how many words of A (case-insensitive) also appear in B
word_overlap() {
	awk -v a="$1" -v b="$2" 'BEGIN {
		a = tolower(a); b = tolower(b)
		gsub(/[^a-z0-9]+/, " ", a); gsub(/[^a-z0-9]+/, " ", b)
		n = split(b, bw, " "); for (i = 1; i <= n; i++) seen[bw[i]] = 1
		m = split(a, aw, " "); c = 0; for (i = 1; i <= m; i++) if (aw[i] in seen) c++
		print c
	}'
}

word_count() { printf '%s' "$1" | wc -w | tr -d ' '; }

# split_author_title NAME [TITLE] -> "author<TAB>title" for names like "A - B", or empty.
# The side that shares more words with TITLE (a known title tag) is the title;
# without that hint the shorter side is taken as the author.
split_author_title() {
	local name="$1" hint="${2:-}" left right
	case "$name" in *" - "*) ;; *) return 0 ;; esac
	left="${name%% - *}"; right="${name#* - }"
	if [ -n "$hint" ]; then
		local lo ro
		lo="$(word_overlap "$left" "$hint")"; ro="$(word_overlap "$right" "$hint")"
		if [ "$lo" -gt "$ro" ]; then printf '%s\t%s' "$right" "$left"; return; fi
		if [ "$ro" -gt "$lo" ]; then printf '%s\t%s' "$left" "$right"; return; fi
	fi
	if [ "$(word_count "$right")" -lt "$(word_count "$left")" ]; then
		printf '%s\t%s' "$right" "$left"
	else
		printf '%s\t%s' "$left" "$right"
	fi
}

# online_author TITLE -> author of the first matching online result, or empty
online_author() {
	local found url label otitle oauthor
	found="$(python3 -I "$COVER_LOOKUP" "$1" "" 2>/dev/null)" || true
	[ -n "$found" ] || return 0
	IFS=$'\t' read -r url label otitle oauthor <<< "$found"
	printf '%s' "$oauthor"
}

# book_identity KIND TARGET -> "author<TAB>title" (author empty when not found anywhere)
#   KIND book: TARGET is a folder; file: TARGET is a single audio file
# Author: artist / album_artist tag, else "A - B" in the folder or file name, else online.
# Title: album tag (file: also title tag), else the name part, else the cleaned name.
book_identity() {
	local kind="$1" target="$2" audio name title author split
	if [ "$kind" = book ]; then
		IFS= read -r -d '' audio < <(find_audio "$target") || true
		if [ "$(cd "$target" && pwd)" = "$(cd "$INPUT_DIR" && pwd)" ]; then
			name="$(basename "$audio")"; name="${name%.*}"
		else
			name="$(basename "$target")"
		fi
	else
		audio="$target"
		name="$(basename "$target")"; name="${name%.*}"
	fi
	name="$(clean_title "$name")"

	title="$(probe_tag album "$audio")"
	if [ "$kind" = file ] && [ -z "$title" ]; then title="$(probe_tag title "$audio")"; fi
	author="$(probe_author "$audio")"

	if [ -z "$author" ] || [ -z "$title" ]; then
		split="$(split_author_title "$name" "$title")"
		if [ -n "$split" ]; then
			[ -n "$author" ] || author="${split%%$'\t'*}"
			[ -n "$title" ] || title="${split#*$'\t'}"
		fi
	fi
	[ -n "$title" ] || title="$name"
	title="$(strip_edition "$title")"
	[ -n "$author" ] || author="$(online_author "$title")"

	printf '%s\t%s' "$author" "$title"
}

# output_name KIND TARGET -> "Author - Title", filename-safe
output_name() {
	local id author title
	id="$(book_identity "$1" "$2")"
	author="${id%%$'\t'*}"; title="${id#*$'\t'}"
	[ -n "$author" ] || author="$UNKNOWN_AUTHOR"
	safe_filename "$author - $title"
}
