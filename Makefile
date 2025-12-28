# Makefile for converting audio files to M4B format
# This Makefile automatically generates targets for all files in the input/ directory
# and converts them to M4B format in the output/ directory
# Supports filenames with spaces

# Define directories
INPUT_DIR := input
OUTPUT_DIR := output

# Default target - uses shell to handle filenames with spaces
.PHONY: all clean help

all:
	@mkdir -p $(OUTPUT_DIR)
	@find $(INPUT_DIR) -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.wma" \) | while IFS= read -r input_file; do \
		basename="$$(basename "$$input_file")"; \
		name_no_ext="$${basename%.*}"; \
		output_file="$(OUTPUT_DIR)/$$name_no_ext.m4b"; \
		if [ ! -f "$$output_file" ]; then \
			echo "Converting: $$input_file -> $$output_file"; \
			ffmpeg -i "$$input_file" -c:a aac -b:a 128k -movflags +faststart "$${output_file%.m4b}.m4a" && \
			mv "$${output_file%.m4b}.m4a" "$$output_file"; \
		else \
			echo "Skipping (already exists): $$output_file"; \
		fi; \
	done

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
	@find $(INPUT_DIR) -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.wma" \) | while IFS= read -r f; do echo "  $$f"; done || echo "  No supported audio files found in $(INPUT_DIR)/"
	@echo ""
	@echo "Output files that will be generated:"
	@find $(INPUT_DIR) -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.wma" \) | while IFS= read -r f; do \
		name="$$(basename "$$f")"; \
		echo "  $(OUTPUT_DIR)/$${name%.*}.m4b"; \
	done || echo "  No output files (no input files found)"

.PHONY: status