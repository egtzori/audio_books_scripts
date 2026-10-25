# Makefile for converting audio files to M4B audiobooks.
# All logic lives in m4b.sh; these targets are thin wrappers.
# Supports filenames with spaces and quotes.

INPUT_DIR := input
OUTPUT_DIR := output
DIR ?= $(INPUT_DIR)
FORCE ?= 0

M4B := INPUT_DIR="$(INPUT_DIR)" OUTPUT_DIR="$(OUTPUT_DIR)" FORCE="$(FORCE)" bash ./m4b.sh

.PHONY: all concat books status clean help

# Convert each top-level file in input/ to its own M4B
all:
	@$(M4B) all

# Concatenate all audio files in DIR (default input/) into one M4B with chapters
concat:
	@$(M4B) concat "$(DIR)"

# Concatenate each subfolder of input/ into its own M4B with chapters
books:
	@$(M4B) books

status:
	@$(M4B) status

clean:
	@echo "Cleaning output directory..."
	rm -f $(OUTPUT_DIR)/*.m4b $(OUTPUT_DIR)/*.m4a

help:
	@echo "Audio Book M4B Conversion Makefile"
	@echo "=================================="
	@echo ""
	@echo "Usage:"
	@echo "  make                  - Convert each audio file in input/ to its own M4B"
	@echo "  make concat           - Join all files in input/ into one M4B with chapters"
	@echo "  make concat DIR=path  - Join all files in DIR into one M4B with chapters"
	@echo "  make books            - One M4B (with chapters) per subfolder of input/"
	@echo "  make status           - Show which files/books are done and which are pending"
	@echo "  make clean            - Remove generated M4B files from output/"
	@echo "  make help             - Show this help message"
	@echo ""
	@echo "Supported input formats: MP3, WAV, FLAC, AAC, OGG, M4A, WMA"
	@echo "Output names: 'Author - Title.m4b' (from tags, folder name, or online lookup)"
	@echo "Cover art: JPG/PNG in the same folder (or Foo.jpg for Foo.mp3), else art"
	@echo "embedded in the audio, else looked up online and saved as cover.jpg."
	@echo "Items whose output already exists in output/ are skipped. A book folder"
	@echo "holding a ready-made .m4b is copied to output/ (FORCE=1 re-encodes instead)."
	@echo "Requires ffmpeg, ffprobe, python3 and curl in PATH."
