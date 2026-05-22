# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Makefile-driven wrapper around `ffmpeg` that converts arbitrary audio files in `input/` to M4B (audiobook) files in `output/`. No source code — all logic lives in `Makefile`.

## Commands

- `make` / `make all` — convert each file in `input/` individually to its own `.m4b` in `output/`. Skips files where the output already exists (idempotent).
- `make concat` — concatenate all input files (sorted) into one `.m4b`. Output name derived from ffprobe `album`/`artist` tags of the first file, falling back to a cleaned-up basename.
- `make status` — list discovered input files and the m4b paths that would be produced.
- `make clean` — remove all `.m4b` from `output/`.
- `make help` — usage info.

Single-file conversion: drop just that file in `input/` and run `make` (no per-target rule — discovery is `find`-based).

## Architecture Notes

- Targets are not file-based rules; `all` and `concat` are phony recipes that shell-iterate over `find ... -maxdepth 1` matches in `input/`. Adding a new format means editing the `find` extension list in **every** recipe (`all`, `concat`, `status`) — they are duplicated.
- Conversion pipeline: ffmpeg encodes to a temporary `.m4a` (AAC 128k, `+faststart`), then `mv` renames to `.m4b`. M4B is just M4A with the audiobook extension. Chapter metadata in source mp3 is preserved (carried through as `bin_data` stream).
- Cover art embedding: if a `.jpg`/`.jpeg`/`.png` (case-insensitive) is present in `input/`, it is muxed in as an `attached_pic` video stream so iOS / Books / Music show the cover.
  - `all`: prefers an image whose basename matches the audio file (`Foo.mp3` → `Foo.jpg`); falls back to the first image found in `input/` (sorted).
  - `concat`: uses the first image found in `input/` (sorted).
  - When no cover is present, falls back to `-vn` (audio-only) path.
  - ffmpeg invocation when cover present: `-i <audio> -i <cover> -map 0:a -map 1:v -c:a aac -b:a 128k -c:v copy -disposition:v:0 attached_pic -movflags +faststart`.
- Filename handling uses `IFS= read -r` and quoted `"$$var"` throughout — preserve this when editing; spaces in filenames are a supported case (see commit `15ed064`).
- `concat` builds an ffmpeg concat-demuxer list file in a `mktemp` path with absolute paths (`cd $(INPUT_DIR) && pwd`) so the list works regardless of cwd.

## Requirements

`ffmpeg` and `ffprobe` on PATH. No language runtime, no tests, no linter.
