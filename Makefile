# Makefile for converting audio files to M4B format
# This Makefile automatically generates targets for all files in the input/ directory
# and converts them to M4B format in the output/ directory

# Define directories
INPUT_DIR := input
OUTPUT_DIR := output

# Find all audio files in the input directory
# Common audio formats: mp3, wav, flac, aac, ogg, m4a, wma
INPUT_FILES := $(wildcard $(INPUT_DIR)/*.mp3 $(INPUT_DIR)/*.wav $(INPUT_DIR)/*.flac $(INPUT_DIR)/*.aac $(INPUT_DIR)/*.ogg $(INPUT_DIR)/*.m4a $(INPUT_DIR)/*.wma)

# Generate output file names with .m4b extension
OUTPUT_FILES := $(patsubst $(INPUT_DIR)/%,$(OUTPUT_DIR)/%.m4b,$(basename $(INPUT_FILES)))

# Default target
.PHONY: all clean help

all: $(OUTPUT_FILES)

# Pattern rules for converting specific audio formats to M4B
# Each rule converts to M4A first, then renames to M4B

$(OUTPUT_DIR)/%.m4b: $(INPUT_DIR)/%.mp3
	@echo "Converting MP3: $< to $@"
	@mkdir -p $(OUTPUT_DIR)
	ffmpeg -i "$<" -c:a aac -b:a 128k -movflags +faststart "$(basename $@).m4a"
	mv "$(basename $@).m4a" "$@"

$(OUTPUT_DIR)/%.m4b: $(INPUT_DIR)/%.wav
	@echo "Converting WAV: $< to $@"
	@mkdir -p $(OUTPUT_DIR)
	ffmpeg -i "$<" -c:a aac -b:a 128k -movflags +faststart "$(basename $@).m4a"
	mv "$(basename $@).m4a" "$@"

$(OUTPUT_DIR)/%.m4b: $(INPUT_DIR)/%.flac
	@echo "Converting FLAC: $< to $@"
	@mkdir -p $(OUTPUT_DIR)
	ffmpeg -i "$<" -c:a aac -b:a 128k -movflags +faststart "$(basename $@).m4a"
	mv "$(basename $@).m4a" "$@"

$(OUTPUT_DIR)/%.m4b: $(INPUT_DIR)/%.aac
	@echo "Converting AAC: $< to $@"
	@mkdir -p $(OUTPUT_DIR)
	ffmpeg -i "$<" -c:a aac -b:a 128k -movflags +faststart "$(basename $@).m4a"
	mv "$(basename $@).m4a" "$@"

$(OUTPUT_DIR)/%.m4b: $(INPUT_DIR)/%.ogg
	@echo "Converting OGG: $< to $@"
	@mkdir -p $(OUTPUT_DIR)
	ffmpeg -i "$<" -c:a aac -b:a 128k -movflags +faststart "$(basename $@).m4a"
	mv "$(basename $@).m4a" "$@"

$(OUTPUT_DIR)/%.m4b: $(INPUT_DIR)/%.m4a
	@echo "Converting M4A: $< to $@"
	@mkdir -p $(OUTPUT_DIR)
	ffmpeg -i "$<" -c:a copy -movflags +faststart "$(basename $@).m4a"
	mv "$(basename $@).m4a" "$@"

$(OUTPUT_DIR)/%.m4b: $(INPUT_DIR)/%.wma
	@echo "Converting WMA: $< to $@"
	@mkdir -p $(OUTPUT_DIR)
	ffmpeg -i "$<" -c:a aac -b:a 128k -movflags +faststart "$(basename $@).m4a"
	mv "$(basename $@).m4a" "$@"

# Clean generated files
clean:
	@echo "Cleaning output directory..."
	rm -f $(OUTPUT_DIR)/*.m4b

# Show help information
help:
	@echo "Audio Book M4B Conversion Makefile"
	@echo "=================================="
	@echo ""
	@echo "Usage:"
	@echo "  make          - Convert all audio files in input/ to M4B format in output/"
	@echo "  make all      - Same as 'make'"
	@echo "  make clean    - Remove all generated M4B files from output/"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Supported input formats:"
	@echo "  MP3, WAV, FLAC, AAC, OGG, M4A, WMA"
	@echo ""
	@echo "Instructions:"
	@echo "  1. Place your audio files in the input/ directory"
	@echo "  2. Run 'make' to convert all files to M4B format"
	@echo "  3. Find converted files in the output/ directory"
	@echo ""
	@echo "Requirements:"
	@echo "  - ffmpeg must be installed and available in PATH"

# Show current status
status:
	@echo "Input files found:"
	@if [ -n "$(INPUT_FILES)" ]; then \
		for file in $(INPUT_FILES); do echo "  $$file"; done; \
	else \
		echo "  No supported audio files found in $(INPUT_DIR)/"; \
	fi
	@echo ""
	@echo "Output files that will be generated:"
	@if [ -n "$(OUTPUT_FILES)" ]; then \
		for file in $(OUTPUT_FILES); do echo "  $$file"; done; \
	else \
		echo "  No output files (no input files found)"; \
	fi

.PHONY: status