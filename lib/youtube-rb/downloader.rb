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
      @ytdlp_wrapper = nil
      @video_info = nil
      @tried_ytdlp = false
      @tried_ruby = false
      @cached_video_path = nil  # For caching full video when downloading multiple segments
    end

    # Download full video
    def download
      ensure_output_directory
      
      # Choose backend: yt-dlp or pure Ruby
      if should_use_ytdlp?
        download_with_ytdlp
      else
        download_with_ruby
      end
    end

    # Download video segment (time range)
    def download_segment(start_time, end_time, output_file = nil)
      raise ArgumentError, "Start time must be less than end time" if start_time >= end_time
      
      duration = end_time - start_time
      unless valid_segment_duration?(duration)
        raise ArgumentError, "Segment duration must be between #{@options.min_segment_duration} and #{@options.max_segment_duration} seconds, got: #{duration}"
      end

      ensure_output_directory
      
      # Always use yt-dlp for segment downloads (most efficient and reliable)
      unless ytdlp_available?
        raise DownloadError, "yt-dlp is required for segment downloads. Please install yt-dlp."
      end
      
      download_segment_with_ytdlp(start_time, end_time, output_file)
    end

    # Download multiple video segments (batch processing)
    # @param segments [Array<Hash>] Array of segment definitions: [{start: 0, end: 30, output_file: 'seg1.mp4'}, ...]
    # @return [Array<String>] Paths to downloaded segment files
    def download_segments(segments)
      raise ArgumentError, "segments must be an Array" unless segments.is_a?(Array)
      raise ArgumentError, "segments array cannot be empty" if segments.empty?
      
      # Validate all segments first
      segments.each_with_index do |seg, idx|
        raise ArgumentError, "Segment #{idx} must be a Hash with :start and :end keys" unless seg.is_a?(Hash) && seg[:start] && seg[:end]
        
        start_time = seg[:start]
        end_time = seg[:end]
        raise ArgumentError, "Segment #{idx}: start time must be less than end time" if start_time >= end_time
        
        duration = end_time - start_time
        unless valid_segment_duration?(duration)
          raise ArgumentError, "Segment #{idx}: duration must be between #{@options.min_segment_duration} and #{@options.max_segment_duration} seconds, got: #{duration}"
        end
      end

      ensure_output_directory
      
      # Always use yt-dlp for batch segment downloads (most efficient and reliable)
      unless ytdlp_available?
        raise DownloadError, "yt-dlp is required for batch segment downloads. Please install yt-dlp."
      end
      
      download_segments_with_ytdlp(segments)
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

    def should_use_ytdlp?
      # Use yt-dlp if:
      # 1. Explicitly requested via options
      # 2. yt-dlp is available
      if @options.use_ytdlp && ytdlp_available?
        return true
      end
      
      # Don't use yt-dlp if explicitly disabled
      if @options.use_ytdlp == false
        return false
      end
      
      # Default: use yt-dlp if available for better reliability
      ytdlp_available?
    end

    def ytdlp_available?
      @ytdlp_available ||= YtdlpWrapper.available?
    end

    def ytdlp_wrapper
      @ytdlp_wrapper ||= YtdlpWrapper.new(@options)
    end

    def download_with_ytdlp
      log "Using yt-dlp backend for download"
      @tried_ytdlp = true
      
      begin
        output_file = ytdlp_wrapper.download(@url)
        log "Downloaded successfully with yt-dlp: #{output_file}"
        output_file
      rescue YtdlpWrapper::YtdlpError => e
        handle_ytdlp_error(e)
      end
    end

    def download_with_ruby
      log "Using pure Ruby backend for download"
      @tried_ruby = true
      
      begin
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
      rescue => e
        handle_ruby_error(e)
      end
    end

    def download_segment_with_ytdlp(start_time, end_time, output_file)
      log "Using yt-dlp backend for segment download"
      
      output_file = ytdlp_wrapper.download_segment(@url, start_time, end_time, output_file)
      log "Downloaded segment successfully with yt-dlp: #{output_file}"
      output_file
    end

    def download_segments_with_ytdlp(segments)
      log "Using yt-dlp backend for batch segment download (optimized: 1 download + local segmentation)"
      
      output_files = []
      
      begin
        # Download full video once using yt-dlp (handles all YouTube protection)
        full_video_path = get_full_video_for_segmentation_with_ytdlp
        
        # Extract all segments locally using FFmpeg (fast and efficient)
        segments.each_with_index do |seg, idx|
          start_time = seg[:start]
          end_time = seg[:end]
          output_file = seg[:output_file] || generate_segment_output_path(@video_info, start_time, end_time)
          
          log "Extracting segment #{idx + 1}/#{segments.size}: #{start_time}-#{end_time}s"
          
          # Extract segment using ffmpeg (same as Pure Ruby backend)
          extract_segment(full_video_path, output_file, start_time, end_time)
          
          # Download subtitles for segment if requested
          if @options.write_subtitles || @options.write_auto_sub
            download_subtitles_for_segment(start_time, end_time)
          end
          
          output_files << output_file
        end
      ensure
        # Clean up cache if not enabled
        cleanup_video_cache unless @options.cache_full_video
      end
      
      output_files
    end


    def handle_ytdlp_error(error, fallback: nil)
      log "yt-dlp error: #{error.message}"
      
      # Try fallback to pure Ruby if enabled and not already tried
      if @options.ytdlp_fallback && !@tried_ruby
        if fallback
          log "Falling back to pure Ruby implementation"
          return fallback.call
        else
          log "Falling back to pure Ruby implementation"
          return download_with_ruby
        end
      end
      
      raise DownloadError, "yt-dlp failed: #{error.message}"
    end

    def handle_ruby_error(error)
      log "Pure Ruby error: #{error.message}"
      
      # Try fallback to yt-dlp if:
      # 1. It's a 403 error (signature/auth issue)
      # 2. ytdlp_fallback is enabled
      # 3. yt-dlp is available
      # 4. Haven't tried yt-dlp yet
      if @options.ytdlp_fallback && ytdlp_available? && !@tried_ytdlp
        if error.message.include?('403') || error.is_a?(Extractor::ExtractionError)
          log "Falling back to yt-dlp"
          return download_with_ytdlp
        end
      end
      
      raise DownloadError, "Download failed: #{error.message}"
    end

    def log(message)
      puts "[YoutubeRb] #{message}" if @options.verbose
    end

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
        if match_data = line.match(/(\d{2}:\d{2}:\d{2}[.,]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[.,]\d{3})/)
          # This is a timestamp line
          cue_start = parse_subtitle_time(match_data[1])
          cue_end = parse_subtitle_time(match_data[2])
          
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

    def valid_segment_duration?(duration)
      duration >= @options.min_segment_duration && duration <= @options.max_segment_duration
    end

    def get_full_video_for_segmentation_with_ytdlp
      # Return cached video if available
      if @cached_video_path && File.exist?(@cached_video_path)
        log "Using cached video: #{@cached_video_path}"
        return @cached_video_path
      end
      
      # Extract video info first (needed for segment naming)
      @video_info ||= @extractor.extract_info
      
      # Download full video using yt-dlp
      @cached_video_path = generate_cache_path
      log "Downloading full video via yt-dlp for segmentation: #{@cached_video_path}"
      ytdlp_wrapper.download(@url, @cached_video_path)
      
      @cached_video_path
    end

    def cleanup_video_cache
      if @cached_video_path && File.exist?(@cached_video_path)
        log "Cleaning up cached video: #{@cached_video_path}"
        File.delete(@cached_video_path)
        @cached_video_path = nil
      end
    end

    def generate_cache_path
      File.join(@options.output_path, ".cache_#{Time.now.to_i}_#{rand(10000)}.mp4")
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
