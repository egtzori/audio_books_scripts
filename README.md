# audio_books_scripts
Helpers to convert audio files to M4B format for audiobook management

## Features

- Automatic conversion of various audio formats to M4B (audiobook format)
- Support for MP3, WAV, FLAC, AAC, OGG, M4A, and WMA input formats
- Dynamic Makefile targets that automatically detect input files
- Clean directory structure with separate input and output directories

## Requirements

- `ffmpeg` must be installed and available in your PATH
- `make` utility

## Installation

1. Clone this repository
2. Ensure `ffmpeg` is installed:
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install ffmpeg
   
   # On macOS with Homebrew
   brew install ffmpeg
   
   # On Windows, download from https://ffmpeg.org/
   ```

## Usage

1. Place your audio files in the `input/` directory
2. Run the conversion:
   ```bash
   make
   ```
3. Find your converted M4B files in the `output/` directory

## Makefile Commands

- `make` or `make all` - Convert all audio files to M4B format
- `make status` - Show input files found and output files that will be generated
- `make clean` - Remove all generated M4B files from output directory
- `make help` - Display usage information

## Supported Input Formats

- MP3 (`.mp3`)
- WAV (`.wav`) 
- FLAC (`.flac`)
- AAC (`.aac`)
- OGG (`.ogg`)
- M4A (`.m4a`)
- WMA (`.wma`)

## How it Works

The Makefile uses `ffmpeg` to convert audio files:
1. Converts input files to M4A format with AAC encoding
2. Renames the M4A file to M4B extension (M4B is essentially M4A optimized for audiobooks)
3. Uses 128k bitrate for good quality/size balance
4. Applies `+faststart` flag for better streaming compatibility

## Example

```bash
# Place files in input directory
cp audiobook.mp3 input/
cp chapter1.wav input/
cp chapter2.flac input/

# Convert all files
make

# Output files will be created:
# output/audiobook.m4b
# output/chapter1.m4b  
# output/chapter2.m4b
```
