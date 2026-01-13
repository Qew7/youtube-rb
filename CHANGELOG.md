# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-13

### Added
- Initial release inspired by youtube-dl
- **Pure Ruby implementation** - no external dependencies on yt-dlp or youtube-dl
- `Client` class for managing downloads and extraction
- `Options` class for flexible configuration
- `VideoInfo` class for video metadata representation
- `Extractor` class for extracting video information directly from HTML/JSON
- `Downloader` class for downloading videos, audio, and subtitles via HTTP
- Video download functionality with format selection
- **Video segment download** (10-60 seconds intervals) using FFmpeg
- **Subtitle download and trimming** for video segments
- Audio extraction in multiple formats (mp3, aac, opus, flac, wav, etc.)
- Support for cookies and custom headers for authentication
- Playlist support with filtering options (planned)
- Video selection options (title matching, date filtering, view count filtering)
- Filesystem options (output templates, file handling)
- Network options (rate limiting, retries, user agent, referer)
- Comprehensive error handling
- Full test suite with RSpec
- Detailed documentation and examples

### Features
- **100% Ruby** - no Python dependencies required
- Direct HTTP downloads from YouTube streaming URLs
- Extract video information by parsing YouTube's page HTML
- Parse `ytInitialPlayerResponse` JSON from YouTube pages
- FFmpeg integration for segment extraction (optional, only for segments)
- Automatic subtitle time adjustment for segments
- Smart encoding handling for international characters
- Balanced JSON extraction from YouTube's embedded data
- Retry logic with exponential backoff

### Technical Implementation
- Faraday-based HTTP client with streaming support
- Nokogiri for HTML parsing
- Custom JSON extraction from JavaScript variables
- Balanced brace counting for reliable JSON parsing
- UTF-8 encoding normalization
- Browser-like headers to minimize detection

### Dependencies
- faraday ~> 2.7 (HTTP client with streaming)
- faraday-retry ~> 2.2 (retry middleware with backoff)
- nokogiri ~> 1.16 (HTML/XML parsing)
- streamio-ffmpeg ~> 3.0 (FFmpeg wrapper, optional)
- addressable ~> 2.8 (URL parsing and manipulation)

### Limitations
- YouTube may require login/cookies for some videos due to bot detection
- Some videos may have restricted access based on region or age
- Signature decryption for certain formats is not yet implemented
- For best results, use with cookies from an authenticated browser session

### Known Issues
- YouTube's bot detection may block unauthenticated requests
- Some formats may require signature decryption (not yet implemented)
- Videos with "LOGIN_REQUIRED" status need authentication cookies
