# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Wrapper around `ffmpeg` that converts audio files in `input/` to M4B (audiobook) files in `output/`. Logic lives in `m4b.sh` (bash), which sources `naming.sh` (output names), `cover.sh` (cover art) and calls `cover_lookup.py` (online cover search, Python stdlib only). `Makefile` targets are thin wrappers.

## Commands

- `make` / `make all` — convert each top-level file in `input/` to its own `.m4b`. Skips existing outputs.
- `make concat [DIR=path]` — join all audio files in `DIR` (default `input/`, version-sorted) into one `.m4b` with one chapter per file. Skips existing output.
- `make books` — run `concat` for each subfolder of `input/` (one book per folder; nested folders inside a book are ignored).
- `make status` — show each top-level file and book folder as `done` / `has-m4b` / `pending`, plus a count to convert, and the cover each item has or will get (existing outputs: `yes (WxH)` / `MISSING`). Pending items are looked up online but nothing is downloaded. Run before `make books`.
- `make clean` — remove `.m4b`/`.m4a` from `output/`.
- `make help` — usage info.

## Architecture Notes

- Skip logic (`book_state` in `m4b.sh`): a book is skipped when its output already exists in `output/` (`done`), A book folder that already contains an `.m4b` at any depth, e.g. a shipped single-file release (`has-m4b`), is not re-encoded: that file is copied to `output/` under the standard `Author - Title.m4b` name (plain `cp` through a `.part` temp file, tags/chapters/cover untouched). `FORCE=1` re-encodes it from the mp3s instead; an existing output is never overwritten. `all` skips per file by output name.
- Output names from tags pass through `safe_filename` (`/` becomes `-`, `:` becomes ` - `). `probe_tag` uses `-of default=nw=1:nk=1`, not csv, because csv wraps values that contain commas in quotes.
- `m4b.sh` subcommands: `all`, `concat [DIR]`, `books`, `status`. Supported extensions live once in `AUDIO_EXTS` / `IMAGE_EXTS`.
- File discovery is `find -maxdepth 1 -print0 | sort -z -V` read with `read -r -d ''`; keep NUL-delimited, quoted handling — spaces, apostrophes and brackets in filenames are supported.
- ffmpeg always runs with `-nostdin` (otherwise it eats the filename stream of the surrounding `while read` loop and skips files) and `-y` on the temp file.
- Encoding: AAC (`BITRATE`, default 128k), `+faststart`, written to a temp `.m4a` and renamed to `.m4b` on success. The temp file is removed by an EXIT trap on failure or Ctrl-C.
- Cover art (`resolve_cover` in `cover.sh`), muxed as an `attached_pic` stream; first hit wins:
  1. Image file: book = first `.jpg`/`.jpeg`/`.png` in its folder; single file = `Foo.jpg` for `Foo.mp3`, else the first image not named after another audio file.
  2. Art embedded in the (first) source audio, extracted to a temp file.
  3. Online, always tried when 1 and 2 find nothing: `cover_lookup.py` queries the iTunes Search API (audiobooks, artwork URL size rewritten to `COVER_SIZE`, default 1400x1400; this rewrite is not documented by Apple), then Open Library. Results must match title and author last name; "Summary of ..." style companion books are rejected. The image is saved next to the audio (`cover.jpg` in a book folder, `Foo.jpg` for a single file) so later runs reuse it and a wrong one can be replaced by hand. Network failure only logs a warning; conversion continues without a cover (`-vn`).
- `resolve_cover` sets globals (`COVER_SRC`, `COVER_PATH`, `COVER_INFO`) and appends to `CLEANUP`, so call it in the current shell, never inside `$(...)`.
- `concat` chapters: an ffmetadata file is built from each file's ffprobe duration; chapter title is the file's `title` tag, else the basename without leading track numbers (`01 - `, `[01 - 21] `). Passed as a second input with `-map_metadata 1 -map_chapters 1`; also sets title/album/artist and `genre=Audiobook`.
- Output names are always `Author - Title.m4b` (`book_identity` / `output_name` in `naming.sh`), for `all`, `concat` and `books`:
  - Title: `album` tag (single files also `title`), else the title side of an `A - B` folder/file name, else the cleaned name. Full title kept (`:` becomes ` - ` via `safe_filename`); edition notes like `(Unabridged)` / `[Abridged Edition]` are stripped.
  - Author: `artist` tag, else `album_artist`, else the author side of an `A - B` name (the side sharing fewer words with the title tag; without a title tag, the shorter side), else the author of the online lookup match, else `Unknown Author`.
  - The same author/title are written as `title`/`album`/`artist` tags plus `genre=Audiobook`.
  - `clean_title` takes names WITHOUT extension; callers strip it, because folder names contain dots (`R.H. Lustig`).
- The concat-demuxer list uses absolute paths with `'` escaped as `'\''`.

## Requirements

`ffmpeg`, `ffprobe`, bash, `python3`, `curl` and a `sort` with `-V`/`-z` (macOS and GNU both have them) on PATH. No tests, no linter.
