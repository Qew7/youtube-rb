# YoutubeRb

A Ruby library for downloading videos, extracting video segments, and fetching subtitles from YouTube and other video platforms. Inspired by [youtube-dl](https://github.com/ytdl-org/youtube-dl) and powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp).

## Features

- 🔧 **yt-dlp Backend** - Reliable video downloads with full YouTube support
- 📹 Download full videos or audio-only
- ✂️ Extract video segments (customizable duration limits)
- ⚡ **Optimized batch segment downloads** - Download video once, extract multiple segments locally (10-100x faster)
- 📝 Download subtitles (manual and auto-generated) with automatic trimming for segments
- 🎵 Extract audio in various formats (mp3, aac, opus, flac, etc.)
- 📊 Get detailed video information
- 🔧 Flexible configuration options
- 🌐 Support for cookies and authentication

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'youtube-rb'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install youtube-rb

## Requirements

### Ruby Version

- Ruby >= 3.4.0

### External Tools

#### yt-dlp (Required)

YoutubeRb uses yt-dlp as its backend for downloading videos. Install yt-dlp:

```bash
# Using pip (recommended)
pip install -U yt-dlp

# Using pipx (isolated installation)
pipx install yt-dlp

# macOS with Homebrew
brew install yt-dlp

# Or download binary from:
# https://github.com/yt-dlp/yt-dlp/releases
```

**Note**: yt-dlp is **required** for all download operations.

#### FFmpeg (Optional)

Required only for:
- Audio extraction from video
- Segment extraction (time-based clips)
- Format conversion

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install ffmpeg

# Windows (with Chocolatey)
choco install ffmpeg
```

**Check Installation:**

```ruby
client = YoutubeRb::Client.new
client.check_dependencies
# => { ffmpeg: true, ytdlp: true, ytdlp_version: "2024.01.13" }
```

## Quick Start

```ruby
require 'youtube-rb'

# Simple download
YoutubeRb.download('https://www.youtube.com/watch?v=VIDEO_ID', 
  output_path: './downloads'
)

# Get video information
info = YoutubeRb.info('https://www.youtube.com/watch?v=VIDEO_ID')
puts "Title: #{info.title}"
puts "Duration: #{info.duration_formatted}"

# Download single segment (requires yt-dlp)
YoutubeRb.download_segment(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  60,  # start time in seconds
  90,  # end time in seconds
  output_path: './segments'
)

# Download multiple segments (batch processing - 10-100x faster!)
YoutubeRb.download_segments(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  [
    { start: 0, end: 30 },
    { start: 60, end: 90 },
    { start: 120, end: 150 }
  ],
  output_path: './segments'
)
```

## Usage

### Creating a Client

```ruby
require 'youtube-rb'

# Basic client
client = YoutubeRb::Client.new

# Client with options
client = YoutubeRb::Client.new(
  output_path: './downloads',
  verbose: true,
  write_subtitles: true,
  subtitle_langs: ['en']
)
```

### Download Methods

#### Full Video Download

```ruby
# Simple download
client.download('https://www.youtube.com/watch?v=VIDEO_ID')
```

#### Single Segment Download

```ruby
# Download 30-second segment
output_file = client.download_segment(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  60,   # start time in seconds
  90    # end time in seconds
)

# With custom output filename
client.download_segment(
  url, 120, 150,
  output_file: './my_segment.mp4'
)

# Configure segment duration limits (default: 10-60 seconds)
client = YoutubeRb::Client.new(
  min_segment_duration: 5,    # minimum 5 seconds
  max_segment_duration: 300   # maximum 5 minutes
)
```

**Performance Note**: By default, segments use **fast mode** (10x faster). Cuts may be off by a few seconds due to keyframe positions. For frame-accurate cuts:

```ruby
# Fast mode (default) - 10x faster, cuts at keyframes
client = YoutubeRb::Client.new(segment_mode: :fast)

# Precise mode - frame-accurate but slow (re-encodes video)
client = YoutubeRb::Client.new(segment_mode: :precise)
```

#### Batch Segment Download

For downloading multiple segments from one video, use `download_segments` for optimal performance:

```ruby
url = 'https://www.youtube.com/watch?v=VIDEO_ID'

segments = [
  { start: 0, end: 30 },
  { start: 60, end: 90 },
  { start: 120, end: 150 }
]

output_files = client.download_segments(url, segments)
# => ["./segments/video-segment-0-30.mp4", ...]

# With custom filenames
segments = [
  { start: 0, end: 30, output_file: './intro.mp4' },
  { start: 60, end: 90, output_file: './main.mp4' },
  { start: 300, end: 330, output_file: './outro.mp4' }
]

client.download_segments(url, segments)
```

**Benefits of Batch Processing:**
- **10-100x faster**: Video downloaded via yt-dlp once, all segments extracted locally with FFmpeg
- **Bandwidth savings**: Full video loaded once instead of N times
- **Reliability**: Uses yt-dlp to bypass YouTube protection

#### Subtitles Download

```ruby
# Download subtitles with video
client = YoutubeRb::Client.new(
  write_subtitles: true,
  subtitle_langs: ['en', 'ru']
)
client.download(url)

# Download subtitles only
client.download_subtitles(url, langs: ['en', 'ru'])

# Check available subtitle languages
info = client.info(url)
puts info.available_subtitle_languages.join(', ')

# Subtitles are automatically trimmed for segments
client.download_segment(url, 60, 90)
# Creates: video-segment-60-90.mp4 and video-segment-60-90.en.srt
```

#### Audio Extraction

```ruby
# Extract audio in MP3
client.extract_audio(url, format: 'mp3', quality: '192')

# Other formats
client.extract_audio(url, format: 'aac', quality: '128')
client.extract_audio(url, format: 'opus')
client.extract_audio(url, format: 'flac')  # lossless

# Or configure client to extract audio by default
client = YoutubeRb::Client.new(
  extract_audio: true,
  audio_format: 'mp3',
  audio_quality: '320'
)
client.download(url)  # Downloads audio only
```

### Video Information

```ruby
info = client.info('https://www.youtube.com/watch?v=VIDEO_ID')

puts info.title
puts info.description
puts info.duration_formatted  # "01:23:45"
puts info.view_count
puts info.uploader

# Available formats
info.available_formats.each do |format_id|
  format = info.get_format(format_id)
  puts "#{format[:format_id]}: #{format[:height]}p"
end

# Best quality formats
best = info.best_format
video_only = info.best_video_format
audio_only = info.best_audio_format
```

### Authentication and Cookies

For age-restricted, private, or member-only videos, or to bypass 403 errors:

#### Export Cookies from Browser (Most Reliable)

1. **Install browser extension:**
   - Chrome/Edge: [Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
   - Firefox: [cookies.txt](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/)

2. **Log into YouTube** in your browser

3. **Export cookies** from youtube.com (Netscape format)

4. **Use cookies in YoutubeRb:**

```ruby
client = YoutubeRb::Client.new(
  cookies_file: './youtube_cookies.txt',
  verbose: true
)
client.download('https://www.youtube.com/watch?v=VIDEO_ID')
```

**Important Notes:**
- 🔒 **Keep your cookies file secure** - it contains your session data
- 🔄 **Cookies expire** - re-export if you get 403 errors again

## Configuration Options

```ruby
client = YoutubeRb::Client.new(
  # Logging
  verbose: true,                # Show progress logs
  
  # Output
  output_path: './downloads',
  output_template: '%(title)s-%(id)s.%(ext)s',
  no_overwrites: true,          # Don't overwrite existing files
  continue_download: true,      # Resume interrupted downloads
  
  # Quality
  quality: 'best',              # or '1080p', '720p', etc.
  format: 'best',
  
  # Segment Options
  segment_mode: :fast,          # :fast (10x faster) or :precise (frame-accurate)
  min_segment_duration: 10,     # Minimum segment duration in seconds
  max_segment_duration: 60,     # Maximum segment duration in seconds
  cache_full_video: false,      # Cache full video for multiple segments (auto-enabled for batch)
  
  # Audio Extraction
  extract_audio: true,
  audio_format: 'mp3',          # mp3, aac, opus, flac, wav
  audio_quality: '192',
  
  # Subtitles
  write_subtitles: true,
  subtitle_langs: ['en', 'ru'],
  subtitle_format: 'srt',       # srt, vtt, or ass
  
  # Metadata
  write_info_json: true,
  write_thumbnail: true,
  write_description: true,
  
  # Authentication
  cookies_file: './cookies.txt',
  
  # Network
  retries: 10,
  rate_limit: '1M',
  user_agent: 'Mozilla/5.0...'
)
```

## Troubleshooting

### 403 Errors or Bot Detection

**Export cookies from browser:**
```ruby
client = YoutubeRb::Client.new(
  cookies_file: './youtube_cookies.txt'
)
client.download(url)
```

### No Formats Found / Video Unavailable

- Export cookies from authenticated browser session
- Check if video is available in your region
- Verify the video is public and not deleted

### FFmpeg Not Found

For segment downloads, FFmpeg is required:
```bash
which ffmpeg          # check
brew install ffmpeg   # install (macOS)
```

## Error Handling

```ruby
begin
  client = YoutubeRb::Client.new
  output = client.download_segment(url, 60, 90)
  puts "Success: #{output}"
rescue YoutubeRb::ExtractionError => e
  puts "Failed to extract data: #{e.message}"
rescue YoutubeRb::DownloadError => e
  puts "Download error: #{e.message}"
rescue YoutubeRb::ValidationError => e
  puts "Validation error: #{e.message}"
rescue => e
  puts "Error: #{e.message}"
end
```

## Architecture

- **Client** - Main interface for all operations
- **Options** - Configuration management
- **VideoInfo** - Represents video metadata
- **Downloader** - Handles video downloads
- **YtdlpWrapper** - Wrapper for yt-dlp backend (primary download engine)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Qew7/youtube-rb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Inspired by [youtube-dl](https://github.com/ytdl-org/youtube-dl) and powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp).
