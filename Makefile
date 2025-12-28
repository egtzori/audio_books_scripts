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
			ffmpeg -i "$$input_file" -vn -threads 0 -c:a aac -b:a 128k -movflags +faststart "$${output_file%.m4b}.m4a" && \
			mv "$${output_file%.m4b}.m4a" "$$output_file"; \
		else \
			echo "Skipping (already exists): $$output_file"; \
		fi; \
	done

# Concatenate all input files into a single M4B audiobook
# Derives name from album metadata or common filename pattern
concat:
	@mkdir -p $(OUTPUT_DIR)
	@first_file=$$(find $(INPUT_DIR) -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.wma" \) | sort | head -1); \
	if [ -z "$$first_file" ]; then \
		echo "No audio files found in $(INPUT_DIR)/"; \
		exit 1; \
	fi; \
	album=$$(ffprobe -v quiet -show_entries format_tags=album -of csv=p=0 "$$first_file" 2>/dev/null | tr -d '\r'); \
	artist=$$(ffprobe -v quiet -show_entries format_tags=artist -of csv=p=0 "$$first_file" 2>/dev/null | tr -d '\r'); \
	if [ -n "$$album" ] && [ -n "$$artist" ]; then \
		output_name="$$album - $$artist"; \
	elif [ -n "$$album" ]; then \
		output_name="$$album"; \
	else \
		output_name=$$(basename "$$first_file" | sed 's/^[0-9]*[[:space:]]*-*[[:space:]]*//; s/\.[^.]*$$//'); \
	fi; \
	output_file="$(OUTPUT_DIR)/$$output_name.m4b"; \
	echo "Creating: $$output_file"; \
	concat_list=$$(mktemp); \
	find $(INPUT_DIR) -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.wma" \) | sort | while IFS= read -r f; do \
		echo "file '$$(cd $(INPUT_DIR) && pwd)/$$(basename "$$f")'"; \
	done > "$$concat_list"; \
	echo "Concatenating $$(wc -l < "$$concat_list" | tr -d ' ') files..."; \
	ffmpeg -f concat -safe 0 -i "$$concat_list" -vn -threads 0 -c:a aac -b:a 128k -movflags +faststart "$${output_file%.m4b}.m4a" && \
	mv "$${output_file%.m4b}.m4a" "$$output_file" && \
	echo "Done: $$output_file"; \
	rm -f "$$concat_list"

.PHONY: concat

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
	@echo "  make concat   - Concatenate all inputs into a single M4B audiobook"
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