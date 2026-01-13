# YoutubeRb

A **pure Ruby library** inspired by [youtube-dl](https://github.com/ytdl-org/youtube-dl) for downloading videos, extracting video segments, and fetching subtitles from YouTube and other video platforms.

## Features

- 💎 **100% Pure Ruby** - no external dependencies on Python tools (yt-dlp/youtube-dl)
- 📹 Download full videos or audio-only via direct HTTP
- ✂️ Extract video segments (10-60 seconds) using FFmpeg
- 📝 Download subtitles (manual and auto-generated)
- 🎵 Extract audio in various formats (mp3, aac, opus, etc.)
- 📊 Get detailed video information by parsing YouTube pages
- 🔧 Flexible configuration options
- 🌐 Support for cookies and custom headers

## Important Notes

⚠️ **YouTube Bot Detection**: YouTube has bot detection that may block automated requests. For reliable access, you may need to:
- Use cookies from an authenticated browser session
- Set appropriate User-Agent headers
- Respect rate limits

This library works by:
1. Fetching the YouTube video page HTML
2. Parsing the embedded `ytInitialPlayerResponse` JSON data
3. Extracting video URLs and metadata
4. Downloading via direct HTTP streaming

Some videos may require authentication or may be restricted based on region/age.

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

### Optional External Tools

- **FFmpeg** (optional, only for segment extraction and audio conversion)
  ```bash
  # macOS
  brew install ffmpeg
  
  # Ubuntu/Debian
  sudo apt install ffmpeg
  
  # Windows (with Chocolatey)
  choco install ffmpeg
  ```

**Note**: Unlike youtube-dl, this library does **NOT** require yt-dlp or youtube-dl. It's a pure Ruby implementation that directly parses YouTube pages and downloads via HTTP.

## Usage

### Quick Start

```ruby
require 'youtube-rb'

# 1. Получить информацию о видео
info = YoutubeRb.info('https://www.youtube.com/watch?v=jNQXAC9IVRw')
puts "Title: #{info.title}"
puts "Duration: #{info.duration_formatted}"
puts "Formats: #{info.formats.size}"

# 2. Скачать видео
YoutubeRb.download('https://www.youtube.com/watch?v=VIDEO_ID', 
  output_path: './downloads'
)

# 3. Скачать сегмент видео (10-60 секунд)
YoutubeRb.download_segment(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  60,  # начало в секундах
  90,  # конец в секундах
  output_path: './segments'
)

# 4. Скачать только субтитры
YoutubeRb.download_subtitles(
  'https://www.youtube.com/watch?v=VIDEO_ID',
  langs: ['en', 'ru'],
  output_path: './subs'
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

Скачивание определенных интервалов видео (10-60 секунд):

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

# Ограничения: сегмент должен быть от 10 до 60 секунд
client.download_segment(url, 0, 10)    # ✓ Валидно (10 секунд)
client.download_segment(url, 0, 60)    # ✓ Валидно (60 секунд)
client.download_segment(url, 0, 5)     # ✗ Ошибка (слишком короткий)
client.download_segment(url, 0, 120)   # ✗ Ошибка (слишком длинный)
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

### Использование cookies для обхода блокировки

Если YouTube требует авторизацию:

```ruby
# 1. Экспортируйте cookies из браузера в файл cookies.txt (формат Netscape)
#    Используйте расширение "Get cookies.txt" для Chrome/Firefox

# 2. Используйте cookies в клиенте
client = YoutubeRb::Client.new(
  cookies_file: './cookies.txt',
  output_path: './downloads'
)

# 3. Теперь можно скачивать видео
client.download(url)
```

### Полный пример: скачивание нескольких сегментов

```ruby
require 'youtube-rb'

client = YoutubeRb::Client.new(
  output_path: './highlights',
  write_subtitles: true,
  subtitle_langs: ['en']
)

url = 'https://www.youtube.com/watch?v=VIDEO_ID'

segments = [
  { start: 0, end: 30, name: 'intro' },
  { start: 120, end: 150, name: 'main' },
  { start: 300, end: 330, name: 'conclusion' }
]

segments.each do |seg|
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

Если YouTube блокирует запросы:

1. **Используйте cookies из браузера**:
   ```ruby
   client = YoutubeRb::Client.new(cookies_file: './cookies.txt')
   ```

2. **Добавьте задержки между запросами**:
   ```ruby
   videos.each do |url|
     client.download(url)
     sleep 2
   end
   ```

### Форматы не найдены

Попробуйте:
- Использовать cookies из аутентифицированной сессии браузера
- Проверить, доступно ли видео в вашем регионе
- Убедиться, что видео публичное

### FFmpeg не найден

Для работы с сегментами нужен FFmpeg:
```bash
which ffmpeg          # проверить
brew install ffmpeg   # установить (macOS)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Qew7/youtube-rb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Inspired by [youtube-dl](https://github.com/ytdl-org/youtube-dl) and [yt-dlp](https://github.com/yt-dlp/yt-dlp).
