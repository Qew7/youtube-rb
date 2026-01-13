# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **yt-dlp backend support** - Added `YtdlpWrapper` for reliable video downloads
- **Automatic fallback** - Falls back from pure Ruby to yt-dlp on errors (403, etc)
- **Backend selection options** - `use_ytdlp`, `ytdlp_fallback` configuration
- **Verbose logging** - Added `verbose` option to see which backend is used
- **Improved authentication** - Better cookie handling with yt-dlp
- **Dependency checking** - `Client#check_dependencies` now reports yt-dlp status
- **Segment mode option** - New `segment_mode` parameter (`:fast` or `:precise`)
- **🎯 Batch segment downloads** - New `download_segments` method for downloading multiple segments from one video
- **⚙️ Configurable segment duration limits** - New `min_segment_duration` and `max_segment_duration` options (default: 10-60 seconds)
- **🚀 Smart video caching** - New `cache_full_video` option to cache full video for multiple segment extractions
- **Module-level batch method** - Added `YoutubeRb.download_segments` for quick access
- Example script for yt-dlp usage

### Changed
- **Default behavior** - Now automatically uses yt-dlp if available
- **Download reliability** - Significantly improved with yt-dlp backend
- **Error handling** - Better error messages and automatic fallback
- **Segment validation** - Now uses configurable min/max duration instead of hardcoded 10-60 seconds
- **Batch downloads** - Automatically enable caching for `download_segments` to avoid re-downloading
- **README** - Updated with yt-dlp installation, usage instructions, and batch download examples

### Fixed
- **403 errors** - Now resolved with yt-dlp backend
- **Signature decryption** - Handled by yt-dlp
- **Protected videos** - Can now download with proper cookies

### Performance
- **🚀 10x faster segment downloads** - Removed `--force-keyframes-at-cuts` flag by default
  - Fast mode (default): Uses stream copy instead of re-encoding (1.88 MB/s vs 187 KB/s)
  - 15-second segment: ~9 seconds vs ~79 seconds (8.8x faster)
  - Trade-off: Cuts at keyframes (±2-5s accuracy) instead of exact timestamps
  - Precise mode available via `segment_mode: :precise` for frame-accurate cuts
- **Keyframe-based cutting** - Default mode cuts at keyframe positions for speed
- **Optional precise mode** - Re-encoding available when exact timestamps needed
- **⚡ 10-100x faster batch segment extraction** - For Pure Ruby backend with caching
  - Full video downloaded once, all segments extracted from cached file
  - Eliminates redundant downloads for multiple segments from same video
  - Example: 10 segments from 1 video = 1 download instead of 10

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
