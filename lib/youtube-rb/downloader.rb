require 'open3'
require 'fileutils'
require 'faraday'

module YoutubeRb
  class Downloader
    class DownloadError < StandardError; end

    attr_reader :url, :options, :video_info

    def initialize(url, options = Options.new)
      @url = url
      @options = options.is_a?(Options) ? options : Options.new(**options)
      @extractor = Extractor.new(url, @options.to_h)
      @video_info = nil
    end

    # Download full video
    def download
      ensure_output_directory
      @video_info = @extractor.extract_info
      
      output_file = generate_output_path(@video_info)
      
      if @options.extract_audio
        download_audio(output_file)
      else
        download_video(output_file)
      end

      download_subtitles if @options.write_subtitles || @options.write_auto_sub
      download_metadata if @options.write_info_json
      download_thumbnail if @options.write_thumbnail
      download_description if @options.write_description

      output_file
    end

    # Download video segment (time range)
    def download_segment(start_time, end_time, output_file = nil)
      raise ArgumentError, "Start time must be less than end time" if start_time >= end_time
      raise ArgumentError, "Segment must be between 10 and 60 seconds" unless valid_segment_duration?(start_time, end_time)

      ensure_output_directory
      @video_info = @extractor.extract_info
      
      output_file ||= generate_segment_output_path(@video_info, start_time, end_time)
      temp_file = generate_temp_path

      begin
        # Download full video to temp file
        download_video(temp_file)
        
        # Extract segment using ffmpeg
        extract_segment(temp_file, output_file, start_time, end_time)
        
        # Download subtitles for segment if requested
        if @options.write_subtitles || @options.write_auto_sub
          download_subtitles_for_segment(start_time, end_time)
        end
      ensure
        File.delete(temp_file) if File.exist?(temp_file)
      end

      output_file
    end

    # Download only subtitles
    def download_subtitles_only(langs = nil)
      ensure_output_directory
      @video_info = @extractor.extract_info
      
      langs ||= @options.subtitle_langs
      download_subtitles(langs)
    end

    # Get video information without downloading
    def info
      @video_info ||= @extractor.extract_info
    end

    private

    def download_video(output_file)
      # Always use HTTP download (pure Ruby)
      download_with_http(output_file)
    end

    def download_audio(output_file)
      base_output = output_file.sub(/\.[^.]+$/, '')
      
      # Download video first, then extract audio with FFmpeg
      temp_video = generate_temp_path
      download_with_http(temp_video)
      extract_audio(temp_video, "#{base_output}.#{@options.audio_format}")
      File.delete(temp_video) if File.exist?(temp_video)
    end

    def download_with_http(output_file)
      format = @video_info.best_format
      raise DownloadError, "No suitable format found" unless format

      url = format[:url]
      raise DownloadError, "No URL found in format" unless url

      puts "Downloading from: #{url[0..80]}..." if @options.respond_to?(:verbose) && @options.verbose

      # Use streaming download with progress
      downloaded = 0
      File.open(output_file, 'wb') do |file|
        response = http_client.get(url) do |req|
          req.options.on_data = Proc.new do |chunk, overall_received_bytes|
            file.write(chunk)
            downloaded = overall_received_bytes
          end
        end

        unless response.success?
          raise DownloadError, "HTTP download failed with status #{response.status}"
        end
      end

      puts "Downloaded #{(downloaded / 1024.0 / 1024.0).round(2)} MB" if @options.respond_to?(:verbose) && @options.verbose
    rescue Faraday::Error => e
      raise DownloadError, "Network error during download: #{e.message}"
    end

    def download_subtitles(langs = nil)
      langs ||= @options.subtitle_langs
      return if @video_info.subtitles.empty?

      langs.each do |lang|
        subtitle_data = @video_info.get_subtitle(lang)
        next unless subtitle_data

        subtitle_data.each do |sub|
          download_subtitle_file(sub, lang)
        end
      end
    end

    def download_subtitles_for_segment(start_time, end_time)
      langs = @options.subtitle_langs
      return if @video_info.subtitles.empty?

      langs.each do |lang|
        subtitle_data = @video_info.get_subtitle(lang)
        next unless subtitle_data

        subtitle_data.each do |sub|
          output_file = generate_subtitle_segment_path(lang, start_time, end_time)
          download_and_trim_subtitle(sub, output_file, start_time, end_time)
        end
      end
    end

    def download_subtitle_file(subtitle, lang)
      output_file = generate_subtitle_path(lang, subtitle[:ext])
      
      begin
        response = http_client.get(subtitle[:url])
        
        unless response.success?
          warn "Failed to download subtitle: HTTP #{response.status}"
          return
        end
        
        File.write(output_file, response.body)
        
        # Convert to requested format if different
        if @options.subtitle_format != subtitle[:ext]
          convert_subtitle_format(output_file, @options.subtitle_format)
        end
      rescue => e
        warn "Failed to download subtitle for #{lang}: #{e.message}"
      end
    end

    def download_and_trim_subtitle(subtitle, output_file, start_time, end_time)
      response = http_client.get(subtitle[:url])
      content = response.body
      
      # Parse and trim subtitle based on time range
      trimmed_content = trim_subtitle_content(content, start_time, end_time, subtitle[:ext])
      
      File.write(output_file, trimmed_content)
    end

    def extract_segment(input_file, output_file, start_time, end_time)
      unless ffmpeg_available?
        raise DownloadError, "FFmpeg is required for segment extraction. Please install ffmpeg."
      end

      duration = end_time - start_time
      
      cmd = [
        'ffmpeg',
        '-i', input_file,
        '-ss', start_time.to_s,
        '-t', duration.to_s,
        '-c', 'copy',
        '-avoid_negative_ts', '1',
        output_file,
        '-y'
      ].join(' ')

      stdout, stderr, status = Open3.capture3(cmd)
      
      unless status.success?
        raise DownloadError, "Segment extraction failed: #{stderr}"
      end
    end

    def extract_audio(input_file, output_file)
      unless ffmpeg_available?
        raise DownloadError, "FFmpeg is required for audio extraction. Please install ffmpeg."
      end

      cmd = [
        'ffmpeg',
        '-i', input_file,
        '-vn',
        '-acodec', audio_codec_for_format(@options.audio_format),
        '-ab', "#{@options.audio_quality}k",
        output_file,
        '-y'
      ].join(' ')

      stdout, stderr, status = Open3.capture3(cmd)
      
      unless status.success?
        raise DownloadError, "Audio extraction failed: #{stderr}"
      end
    end

    def trim_subtitle_content(content, start_time, end_time, format)
      case format
      when 'vtt', 'srt'
        trim_vtt_or_srt(content, start_time, end_time)
      else
        content # Return as-is for unsupported formats
      end
    end

    def trim_vtt_or_srt(content, start_time, end_time)
      lines = content.split("\n")
      result = []
      current_block = []
      in_cue = false
      
      lines.each do |line|
        if line.match?(/(\d{2}:\d{2}:\d{2}[.,]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[.,]\d{3})/)
          # This is a timestamp line
          cue_start = parse_subtitle_time($1)
          cue_end = parse_subtitle_time($2)
          
          if cue_end >= start_time && cue_start <= end_time
            # Adjust timestamps relative to segment start
            adjusted_start = [cue_start - start_time, 0].max
            adjusted_end = [cue_end - start_time, end_time - start_time].min
            
            current_block << format_subtitle_time(adjusted_start) + ' --> ' + format_subtitle_time(adjusted_end)
            in_cue = true
          else
            in_cue = false
            current_block = []
          end
        elsif in_cue
          current_block << line
          if line.strip.empty? && current_block.size > 1
            result.concat(current_block)
            current_block = []
          end
        elsif line.start_with?('WEBVTT') || line.start_with?('Kind:') || line.start_with?('Language:')
          result << line
        end
      end
      
      result.join("\n")
    end

    def parse_subtitle_time(time_str)
      # Parse format: 00:00:10.500 or 00:00:10,500
      parts = time_str.tr(',', '.').split(':')
      hours = parts[0].to_i
      minutes = parts[1].to_i
      seconds_parts = parts[2].split('.')
      seconds = seconds_parts[0].to_i
      milliseconds = seconds_parts[1].to_i
      
      hours * 3600 + minutes * 60 + seconds + milliseconds / 1000.0
    end

    def format_subtitle_time(seconds)
      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i
      secs = (seconds % 60).to_i
      millis = ((seconds % 1) * 1000).to_i
      
      format("%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    end

    def download_metadata
      output_file = generate_metadata_path
      File.write(output_file, JSON.pretty_generate(@video_info.to_h))
    end

    def download_thumbnail
      return unless @video_info.thumbnail

      output_file = generate_thumbnail_path
      response = http_client.get(@video_info.thumbnail)
      File.write(output_file, response.body)
    end

    def download_description
      return unless @video_info.description

      output_file = generate_description_path
      File.write(output_file, @video_info.description)
    end

    def convert_subtitle_format(input_file, target_format)
      # Basic conversion support (can be extended)
      return if File.extname(input_file) == ".#{target_format}"
      
      output_file = input_file.sub(/\.[^.]+$/, ".#{target_format}")
      
      # For now, just rename for compatible formats
      # TODO: Add proper conversion logic for different formats
      FileUtils.mv(input_file, output_file)
    end

    def audio_codec_for_format(format)
      case format
      when 'mp3'
        'libmp3lame'
      when 'aac', 'm4a'
        'aac'
      when 'opus'
        'libopus'
      when 'vorbis', 'ogg'
        'libvorbis'
      when 'flac'
        'flac'
      when 'wav'
        'pcm_s16le'
      else
        'copy'
      end
    end

    def generate_output_path(video_info)
      template = @options.output_template
      
      # Replace template variables
      filename = template
        .gsub('%(title)s', sanitize_filename(video_info.title))
        .gsub('%(id)s', video_info.id)
        .gsub('%(ext)s', @options.extract_audio ? @options.audio_format : (video_info.ext || 'mp4'))
        .gsub('%(uploader)s', sanitize_filename(video_info.uploader || 'unknown'))
      
      File.join(@options.output_path, filename)
    end

    def generate_segment_output_path(video_info, start_time, end_time)
      filename = "#{sanitize_filename(video_info.title)}-#{video_info.id}-segment-#{start_time}-#{end_time}.#{video_info.ext || 'mp4'}"
      File.join(@options.output_path, filename)
    end

    def generate_subtitle_path(lang, ext)
      filename = "#{sanitize_filename(@video_info.title)}-#{@video_info.id}.#{lang}.#{ext}"
      File.join(@options.output_path, filename)
    end

    def generate_subtitle_segment_path(lang, start_time, end_time)
      filename = "#{sanitize_filename(@video_info.title)}-#{@video_info.id}-segment-#{start_time}-#{end_time}.#{lang}.#{@options.subtitle_format}"
      File.join(@options.output_path, filename)
    end

    def generate_metadata_path
      filename = "#{sanitize_filename(@video_info.title)}-#{@video_info.id}.info.json"
      File.join(@options.output_path, filename)
    end

    def generate_thumbnail_path
      ext = File.extname(@video_info.thumbnail).split('?').first || '.jpg'
      filename = "#{sanitize_filename(@video_info.title)}-#{@video_info.id}#{ext}"
      File.join(@options.output_path, filename)
    end

    def generate_description_path
      filename = "#{sanitize_filename(@video_info.title)}-#{@video_info.id}.description"
      File.join(@options.output_path, filename)
    end

    def generate_temp_path
      File.join(@options.output_path, ".temp_#{Time.now.to_i}_#{rand(1000)}.mp4")
    end

    def sanitize_filename(filename)
      return 'video' if filename.nil? || filename.empty?
      
      filename.to_s
        .gsub(/[\/\\:*?"<>|]/, '_')
        .gsub(/\s+/, ' ')
        .strip
    end

    def ensure_output_directory
      FileUtils.mkdir_p(@options.output_path) unless Dir.exist?(@options.output_path)
    end

    def valid_segment_duration?(start_time, end_time)
      duration = end_time - start_time
      duration >= 10 && duration <= 60
    end

    def ffmpeg_available?
      system('which ffmpeg > /dev/null 2>&1')
    end

    def http_client
      @http_client ||= Faraday.new do |f|
        f.request :retry, max: @options.retries, interval: 0.5, backoff_factor: 2
        f.adapter Faraday.default_adapter
        f.options.timeout = 600  # 10 minutes for large downloads
        f.options.open_timeout = 30
        
        f.headers['User-Agent'] = @options.user_agent || 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        f.headers['Accept'] = '*/*'
        f.headers['Accept-Language'] = 'en-US,en;q=0.9'
        f.headers['Referer'] = @options.referer if @options.referer
        
        # Add range support for resuming downloads
        f.headers['Range'] = 'bytes=0-' if @options.continue_download
      end
    end
  end
end
