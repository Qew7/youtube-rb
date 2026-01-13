# YoutubeRb

A **Ruby library** inspired by [youtube-dl](https://github.com/ytdl-org/youtube-dl) for downloading videos, extracting video segments, and fetching subtitles from YouTube and other video platforms.

## Features

- 🔧 **yt-dlp Backend** - Reliable video downloads with full YouTube support
- 📹 Download full videos or audio-only
- ✂️ Extract video segments (10-60 seconds) 
- ⚡ **Optimized batch segment downloads** - Download video once, extract multiple segments locally (10-100x faster)
- 📝 Download subtitles (manual and auto-generated)
- 🎵 Extract audio in various formats (mp3, aac, opus, etc.)
- 📊 Get detailed video information
- 🔧 Flexible configuration options
- 🌐 Support for cookies and authentication

## Backend

YoutubeRb uses **yt-dlp** as its backend for reliable video downloads:

### yt-dlp (Required for segment downloads)
- Most reliable method for YouTube downloads
- Handles signature decryption automatically
- Works with all YouTube videos
- Bypasses 403 errors
- Supports authentication via cookies
- **Optimized for batch processing**: Downloads video once, extracts multiple segments locally

**Note**: yt-dlp is **required** for segment downloads (`download_segment` and `download_segments` methods). Full video downloads still support Pure Ruby fallback with automatic retry using yt-dlp.

## Important Notes

⚠️ **YouTube Protection**: YouTube actively protects videos with:
- Signature encryption (handled by yt-dlp)
- Bot detection (requires proper headers and cookies)
- Rate limiting (handled automatically)

💡 **Batch Optimization**: When downloading multiple segments from the same video, the library automatically:
1. Downloads the full video **once** via yt-dlp
2. Extracts all segments locally using FFmpeg
3. Result: **10-100x faster** than downloading each segment separately

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

- Ruby >= 2.7.0

### External Tools

#### yt-dlp (Strongly Recommended)

For reliable downloads and to avoid 403 errors, install yt-dlp:

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

#### FFmpeg (Optional)

Required only for:
- Audio extraction from video
- Segment extraction (10-60 second clips)
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

## Usage

### Quick Start

```ruby
require 'youtube-rb'

# 1. Simple download (automatically uses yt-dlp if available)
YoutubeRb.download('https://www.youtube.com/watch?v=VIDEO_ID', 
  output_path: './downloads'
)

# 2. Get video information
info = YoutubeRb.info('https://www.youtube.com/watch?v=jNQXAC9IVRw')
puts "Title: #{info.title}"
puts "Duration: #{info.duration_formatted}"
puts "Views: #{info.view_count}"

# 3. Download single segment (10-60 seconds by default)
# Requires yt-dlp to be installed
YoutubeRb.download_segment(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  60,  # start time in seconds
  90,  # end time in seconds
  output_path: './segments'
)

# 4. Download multiple segments (batch processing - OPTIMIZED!)
# Downloads video ONCE via yt-dlp, then extracts all segments locally
# This is 10-100x faster than downloading each segment separately
YoutubeRb.download_segments(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  [
    { start: 0, end: 30 },
    { start: 60, end: 90 },
    { start: 120, end: 150 }
  ],
  output_path: './segments'
)

# 5. Download only subtitles
YoutubeRb.download_subtitles(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  langs: ['en', 'ru'],
  output_path: './subs'
)
```

### Backend Configuration

```ruby
# Recommended: Enable verbose mode to see what's happening
client = YoutubeRb::Client.new(verbose: true)
client.download(url)
# [YoutubeRb] Using yt-dlp backend for download
# [YoutubeRb] Downloaded successfully with yt-dlp: ./downloads/video.mp4

# Full video downloads: Pure Ruby with yt-dlp fallback (default)
client = YoutubeRb::Client.new(ytdlp_fallback: true)
client.download(url)  # Tries Pure Ruby first, falls back to yt-dlp on 403

# Segment downloads: Always use yt-dlp (required)
client.download_segment(url, 10, 30)  # Requires yt-dlp
client.download_segments(url, segments)  # Requires yt-dlp, optimized for batch
```

### Fixing 403 Errors

If you encounter 403 errors:

**Option 1: Use yt-dlp backend (easiest)**
```ruby
client = YoutubeRb::Client.new(use_ytdlp: true)
client.download(url)
```

**Option 2: Export cookies from browser**
1. Install extension: [Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc) (Chrome) or [cookies.txt](https://addons.mozilla.org/firefox/addon/cookies-txt/) (Firefox)
2. Log into YouTube in your browser
3. Export cookies from youtube.com
4. Use cookies:

```ruby
client = YoutubeRb::Client.new(
  cookies_file: './youtube_cookies.txt',
  use_ytdlp: true
)
client.download(url)
```

### Common Configuration Options

```ruby
client = YoutubeRb::Client.new(
  # Backend
  use_ytdlp: true,              # Force yt-dlp (recommended)
  ytdlp_fallback: true,         # Auto fallback on error (default)
  verbose: true,                # Show progress logs
  
  # Segment options
  segment_mode: :fast,          # :fast (default, 10x faster) or :precise (frame-accurate)
  min_segment_duration: 10,     # Minimum segment duration in seconds (default: 10)
  max_segment_duration: 60,     # Maximum segment duration in seconds (default: 60)
  cache_full_video: false,      # Cache full video for multiple segments (default: false, auto-enabled for batch)
  
  # Output
  output_path: './downloads',
  output_template: '%(title)s-%(id)s.%(ext)s',
  
  # Quality
  quality: 'best',              # or '1080p', '720p', etc.
  
  # Audio extraction
  extract_audio: true,
  audio_format: 'mp3',          # mp3, aac, opus, flac, wav
  audio_quality: '192',
  
  # Subtitles
  write_subtitles: true,
  subtitle_langs: ['en', 'ru'],
  subtitle_format: 'srt',       # srt or vtt
  
  # Metadata
  write_info_json: true,
  write_thumbnail: true,
  write_description: true,
  
  # Authentication
  cookies_file: './cookies.txt',
  
  # Network
  retries: 10,
  user_agent: 'Mozilla/5.0...'
)
```

### Основные примеры

#### Создание клиента с настройками

```ruby
require 'youtube-rb'

client = YoutubeRb::Client.new(
  output_path: './downloads',
  write_subtitles: true,
  subtitle_langs: ['en', 'ru']
)

# Скачать видео
client.download('https://www.youtube.com/watch?v=VIDEO_ID')
```

#### Скачивание сегментов видео (главная функция)

Скачивание определенных интервалов видео (10-60 секунд по умолчанию):

```ruby
client = YoutubeRb::Client.new(output_path: './segments')

# Скачать 30-секундный сегмент начиная с 1:00
output_file = client.download_segment(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  60,   # начало в секундах
  90    # конец в секундах
)

# С указанием имени файла
client.download_segment(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  120, 150,
  output_file: './my_segment.mp4'
)

# Ограничения по умолчанию: сегмент должен быть от 10 до 60 секунд
client.download_segment(url, 0, 10)    # ✓ Валидно (10 секунд)
client.download_segment(url, 0, 60)    # ✓ Валидно (60 секунд)
client.download_segment(url, 0, 5)     # ✗ Ошибка (слишком короткий)
client.download_segment(url, 0, 120)   # ✗ Ошибка (слишком длинный)

# Настройка пользовательских ограничений длительности
client = YoutubeRb::Client.new(
  output_path: './segments',
  min_segment_duration: 5,    # минимум 5 секунд
  max_segment_duration: 300   # максимум 5 минут
)

client.download_segment(url, 0, 5)     # ✓ Валидно с новыми настройками
client.download_segment(url, 0, 300)   # ✓ Валидно (5 минут)
```

**⚡ Performance Note**: By default, segments use **fast mode** (10x faster). 
Cuts may be off by a few seconds due to keyframe positions. For frame-accurate cuts:

```ruby
# Fast mode (default) - 10x faster, cuts at keyframes
client = YoutubeRb::Client.new(segment_mode: :fast)

# Precise mode - frame-accurate but slow (re-encodes video)
client = YoutubeRb::Client.new(segment_mode: :precise)
```

See [PERFORMANCE.md](PERFORMANCE.md) for detailed performance comparison and recommendations.

#### Пакетная загрузка сегментов (новое!)

Для загрузки нескольких сегментов из одного видео используйте `download_segments`:

```ruby
client = YoutubeRb::Client.new(output_path: './segments')

url = 'https://www.youtube.com/watch?v=VIDEO_ID'

segments = [
  { start: 0, end: 30 },      # Первые 30 секунд
  { start: 60, end: 90 },     # 1:00 - 1:30
  { start: 120, end: 150 }    # 2:00 - 2:30
]

# Загрузит все сегменты эффективно
output_files = client.download_segments(url, segments)
# => ["./segments/video-segment-0-30.mp4", "./segments/video-segment-60-90.mp4", ...]

puts "Downloaded #{output_files.size} segments"
```

**Преимущества пакетной загрузки:**

- **Оптимизация yt-dlp**: Видео скачивается через yt-dlp **один раз**, все сегменты вырезаются локально через FFmpeg
- **Быстрее в 10-100x**: Не нужно перекачивать видео для каждого сегмента
- **Экономия трафика**: Полное видео загружается один раз вместо N раз
- **Надежность**: Использует yt-dlp для обхода защиты YouTube, FFmpeg для быстрой нарезки

```ruby
# С пользовательскими именами файлов
segments = [
  { start: 0, end: 30, output_file: './intro.mp4' },
  { start: 60, end: 90, output_file: './main.mp4' },
  { start: 300, end: 330, output_file: './outro.mp4' }
]

client.download_segments(url, segments)

# Явное управление кэшированием (по умолчанию включено для batch)
client = YoutubeRb::Client.new(
  output_path: './segments',
  cache_full_video: false  # отключить кэш (медленнее)
)

# Или переопределить при вызове
client.download_segments(url, segments, cache_full_video: true)
```

#### Скачивание субтитров

```ruby
client = YoutubeRb::Client.new(
  output_path: './downloads',
  write_subtitles: true,
  subtitle_langs: ['en', 'ru']
)

# При скачивании сегмента субтитры автоматически обрезаются
client.download_segment(url, 60, 90)
# Создаст: video-segment-60-90.mp4 и video-segment-60-90.en.srt

# Скачать только субтитры (без видео)
client.download_subtitles(url, langs: ['en', 'ru'])

# Проверить доступные языки субтитров
info = client.info(url)
puts info.available_subtitle_languages.join(', ')
```

#### Извлечение аудио

```ruby
# Извлечь аудио в MP3
client.extract_audio(url, format: 'mp3', quality: '192')

# Другие форматы
client.extract_audio(url, format: 'aac', quality: '128')
client.extract_audio(url, format: 'opus')
client.extract_audio(url, format: 'flac')  # без потерь

# Или через настройки клиента
client = YoutubeRb::Client.new(
  extract_audio: true,
  audio_format: 'mp3',
  audio_quality: '320'
)
client.download(url)  # скачает только аудио
```

#### Получение информации о видео

```ruby
info = client.info('https://www.youtube.com/watch?v=VIDEO_ID')

puts info.title
puts info.description
puts info.duration_formatted  # "01:23:45"
puts info.view_count
puts info.uploader

# Доступные форматы
info.available_formats.each do |format_id|
  format = info.get_format(format_id)
  puts "#{format[:format_id]}: #{format[:height]}p"
end

# Лучшее качество
best = info.best_format
video_only = info.best_video_format
audio_only = info.best_audio_format
```

### Настройки (Options)

```ruby
client = YoutubeRb::Client.new(
  # Основные
  output_path: './downloads',
  output_template: '%(title)s-%(id)s.%(ext)s',
  format: 'best',
  quality: 'best',
  
  # Сегменты
  segment_mode: :fast,          # :fast (быстро) или :precise (точно)
  min_segment_duration: 10,     # минимальная длительность сегмента (секунды)
  max_segment_duration: 60,     # максимальная длительность сегмента (секунды)
  cache_full_video: false,      # кэшировать полное видео для нескольких сегментов
  
  # Субтитры
  write_subtitles: true,
  subtitle_format: 'srt',       # srt, vtt, ass
  subtitle_langs: ['en', 'ru'],
  
  # Аудио
  extract_audio: false,
  audio_format: 'mp3',          # mp3, aac, opus, flac, wav
  audio_quality: '192',
  
  # Файловая система
  no_overwrites: true,          # не перезаписывать файлы
  continue_download: true,      # продолжать прерванные загрузки
  write_description: true,
  write_info_json: true,
  write_thumbnail: true,
  
  # Сеть
  rate_limit: '1M',            # ограничение скорости
  retries: 10,
  user_agent: 'Mozilla/5.0...',
  
  # Аутентификация (если нужна)
  cookies_file: './cookies.txt',
  username: 'user',
  password: 'pass'
)
```

### Authentication and Cookies (Bypassing 403 Errors)

For age-restricted, private, member-only videos or to bypass 403 errors:

#### Method 1: Export cookies from browser (Most Reliable)

1. **Install browser extension to export cookies:**
   - Chrome/Edge: [Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
   - Firefox: [cookies.txt](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/)

2. **Log into YouTube** in your browser

3. **Export cookies** from youtube.com (Netscape format)

4. **Use cookies in YoutubeRb:**

```ruby
# With yt-dlp backend (recommended - automatic cookie handling)
client = YoutubeRb::Client.new(
  cookies_file: './youtube_cookies.txt',
  use_ytdlp: true,
  verbose: true
)
client.download('https://www.youtube.com/watch?v=VIDEO_ID')

# Pure Ruby backend also supports cookies
client = YoutubeRb::Client.new(
  cookies_file: './youtube_cookies.txt',
  use_ytdlp: false,
  ytdlp_fallback: true  # Falls back to yt-dlp on 403
)
```

#### Method 2: Let yt-dlp extract cookies from browser (Easiest)

yt-dlp can directly read cookies from your browser:

```bash
# First, ensure browser is closed or use the right browser
yt-dlp --cookies-from-browser chrome <URL>
```

**Note:** This feature requires specific system dependencies and may not work on all platforms. Cookie file export (Method 1) is more reliable.

#### Cookie file format example (Netscape)

```
# Netscape HTTP Cookie File
.youtube.com	TRUE	/	TRUE	0	CONSENT	YES+
.youtube.com	TRUE	/	FALSE	1735689600	VISITOR_INFO1_LIVE	xxxxx
```

#### Important Notes

- ⚠️ **Username/password authentication** is NOT supported (YouTube uses OAuth)
- 🔒 **Keep your cookies file secure** - it contains your session data
- 🔄 **Cookies expire** - re-export if you get 403 errors again
- 💡 **Use yt-dlp backend** for best cookie handling

### Полный пример: скачивание нескольких сегментов

```ruby
require 'youtube-rb'

client = YoutubeRb::Client.new(
  output_path: './highlights',
  write_subtitles: true,
  subtitle_langs: ['en'],
  use_ytdlp: true,         # рекомендуется для надежности
  cache_full_video: true   # кэширование для быстрой обработки
)

url = 'https://www.youtube.com/watch?v=VIDEO_ID'

# Вариант 1: Пакетная загрузка (рекомендуется, быстрее)
segments = [
  { start: 0, end: 30, output_file: './highlights/intro.mp4' },
  { start: 120, end: 150, output_file: './highlights/main.mp4' },
  { start: 300, end: 330, output_file: './highlights/conclusion.mp4' }
]

begin
  output_files = client.download_segments(url, segments)
  output_files.each_with_index do |file, i|
    puts "✓ Segment #{i+1}: #{file}"
  end
rescue => e
  puts "✗ Error: #{e.message}"
end

# Вариант 2: По одному (если нужен контроль над каждым сегментом)
segments_old_way = [
  { start: 0, end: 30, name: 'intro' },
  { start: 120, end: 150, name: 'main' },
  { start: 300, end: 330, name: 'conclusion' }
]

segments_old_way.each do |seg|
  begin
    output = client.download_segment(
      url, seg[:start], seg[:end],
      output_file: "./highlights/#{seg[:name]}.mp4"
    )
    puts "✓ #{seg[:name]}: #{output}"
  rescue => e
    puts "✗ #{seg[:name]}: #{e.message}"
  end
end
```

### Обработка ошибок

```ruby
begin
  client = YoutubeRb::Client.new
  output = client.download_segment(url, 60, 90)
  puts "Success: #{output}"
rescue YoutubeRb::ExtractionError => e
  puts "Не удалось извлечь данные: #{e.message}"
rescue YoutubeRb::DownloadError => e
  puts "Ошибка загрузки: #{e.message}"
rescue => e
  puts "Ошибка: #{e.message}"
end
```

## Архитектура

- **Client** - Основной интерфейс для всех операций
- **Options** - Управление конфигурацией
- **Extractor** - Извлекает информацию о видео из HTML/JSON YouTube
- **VideoInfo** - Представляет метаданные видео
- **Downloader** - Обрабатывает загрузку видео и субтитров через HTTP

## Comparison with youtube-dl

This gem provides a Ruby-native API inspired by youtube-dl but designed as a library rather than a command-line tool:

| Feature | youtube-dl | youtube-rb |
|---------|-----------|------------|
| Language | Python CLI | Ruby Library |
| Implementation | Python executable | Pure Ruby gem |
| Usage | Command line | Programmatic API |
| Dependencies | Python + ffmpeg | Ruby + ffmpeg (optional) |
| Segment Download | Manual with ffmpeg | Built-in method |
| Subtitle Trimming | Manual | Automatic for segments |
| Configuration | CLI arguments | Ruby objects |
| Bot Detection | Less common | May require cookies |

## Решение проблем

### Ошибка "LOGIN_REQUIRED" или блокировка бота

If you're getting 403 errors or bot detection:

1. **Use yt-dlp backend (most reliable)**:
   ```ruby
   client = YoutubeRb::Client.new(use_ytdlp: true, verbose: true)
   client.download(url)
   ```

2. **Export and use cookies from authenticated browser session**:
   ```ruby
   client = YoutubeRb::Client.new(
     cookies_file: './youtube_cookies.txt',
     use_ytdlp: true
   )
   ```

3. **Enable fallback mode** (default):
   ```ruby
   client = YoutubeRb::Client.new(ytdlp_fallback: true)
   # Tries pure Ruby first, falls back to yt-dlp on 403
   ```

4. **Add delays between requests**:
   ```ruby
   videos.each do |url|
     client.download(url)
     sleep 2
   end
   ```

### No formats found / Video unavailable

Try:
- Use yt-dlp backend: `YoutubeRb::Client.new(use_ytdlp: true)`
- Export cookies from authenticated browser session
- Check if video is available in your region
- Verify the video is public and not deleted
- Check yt-dlp directly: `yt-dlp --cookies ./cookies.txt <URL>`

### FFmpeg не найден

Для работы с сегментами нужен FFmpeg:
```bash
which ffmpeg          # проверить
brew install ffmpeg   # установить (macOS)
```

## Performance

Segment downloads are optimized for speed by default, using stream copy instead of re-encoding.

**Fast Mode (Default):**
- ⚡ 10x faster downloads
- 📦 15-second segment: ~9 seconds (1.88 MB/s)
- ⚠️ Cuts at keyframes (may be ±2-5 seconds off)

**Precise Mode (Optional):**
- 🎯 Frame-accurate cuts
- 🐌 15-second segment: ~79 seconds (187 KB/s)
- ⚙️ Requires re-encoding (CPU intensive)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Qew7/youtube-rb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Inspired by [youtube-dl](https://github.com/ytdl-org/youtube-dl) and [yt-dlp](https://github.com/yt-dlp/yt-dlp).
