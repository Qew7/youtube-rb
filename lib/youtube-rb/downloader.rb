require 'open3'
require 'fileutils'

module YoutubeRb
  class Downloader
    class DownloadError < StandardError; end

    attr_reader :url, :options, :video_info

    def initialize(url, options = Options.new)
      @url = url
      @options = options.is_a?(Options) ? options : Options.new(**options)
      begin
        @ytdlp_wrapper = YtdlpWrapper.new(@options)
      rescue YtdlpWrapper::YtdlpNotFoundError => e
        raise DownloadError, "yt-dlp is required. #{e.message}"
      end
      @video_info = nil
      @cached_video_path = nil  # For caching full video when downloading multiple segments
    end

    # Download full video
    def download
      ensure_output_directory
      
      log "Downloading video with yt-dlp"
      output_file = ytdlp_wrapper.download(@url)
      log "Downloaded successfully: #{output_file}"
      output_file
    rescue YtdlpWrapper::YtdlpError => e
      raise DownloadError, "Download failed: #{e.message}"
    end

    # Download video segment (time range)
    def download_segment(start_time, end_time, output_file = nil)
      raise ArgumentError, "Start time must be less than end time" if start_time >= end_time
      
      duration = end_time - start_time
      unless valid_segment_duration?(duration)
        raise ArgumentError, "Segment duration must be between #{@options.min_segment_duration} and #{@options.max_segment_duration} seconds, got: #{duration}"
      end

      ensure_output_directory
      
      log "Downloading segment with yt-dlp: #{start_time}-#{end_time}s"
      output_file = ytdlp_wrapper.download_segment(@url, start_time, end_time, output_file)
      log "Downloaded segment successfully: #{output_file}"
      output_file
    rescue YtdlpWrapper::YtdlpError => e
      raise DownloadError, "Segment download failed: #{e.message}"
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
      
      log "Batch downloading #{segments.size} segments (optimized: 1 download + local segmentation)"
      
      output_files = []
      
      begin
        # Download full video once using yt-dlp (handles all YouTube protection)
        full_video_path = get_full_video_for_segmentation
        
        # Extract all segments locally using FFmpeg (fast and efficient)
        segments.each_with_index do |seg, idx|
          start_time = seg[:start]
          end_time = seg[:end]
          output_file = seg[:output_file] || generate_segment_output_path(start_time, end_time)
          
          log "Extracting segment #{idx + 1}/#{segments.size}: #{start_time}-#{end_time}s"
          
          # Extract segment using ffmpeg
          extract_segment(full_video_path, output_file, start_time, end_time)
          
          output_files << output_file
        end
      ensure
        # Clean up cache if not enabled
        cleanup_video_cache unless @options.cache_full_video
      end
      
      output_files
    rescue YtdlpWrapper::YtdlpError => e
      raise DownloadError, "Batch segment download failed: #{e.message}"
    end

    # Download only subtitles
    def download_subtitles_only(langs = nil)
      ensure_output_directory
      
      # Extract info to get video details
      @video_info ||= info
      
      # Temporarily enable subtitle options
      original_write_subtitles = @options.write_subtitles
      original_subtitle_langs = @options.subtitle_langs
      
      @options.write_subtitles = true
      @options.subtitle_langs = langs || @options.subtitle_langs
      
      begin
        log "Downloading subtitles only"
        ytdlp_wrapper.download(@url)
      ensure
        # Restore original options
        @options.write_subtitles = original_write_subtitles
        @options.subtitle_langs = original_subtitle_langs
      end
    rescue YtdlpWrapper::YtdlpError => e
      raise DownloadError, "Subtitle download failed: #{e.message}"
    end

    # Get video information without downloading
    def info
      @video_info ||= begin
        log "Extracting video info with yt-dlp"
        info_data = ytdlp_wrapper.extract_info(@url)
        VideoInfo.new(info_data)
      end
    rescue YtdlpWrapper::YtdlpError => e
      raise DownloadError, "Failed to extract video info: #{e.message}"
    end

    private

    def ytdlp_wrapper
      @ytdlp_wrapper
    end

    def log(message)
      puts "[YoutubeRb] #{message}" if @options.verbose
    end

    def extract_segment(input_file, output_file, start_time, end_time)
      unless ffmpeg_available?
        raise DownloadError, "FFmpeg is required for segment extraction. Please install ffmpeg."
      end

      duration = end_time - start_time
      
      # Use stream copy mode for fast extraction (cuts at keyframes)
      # For precise mode, would need to re-encode (much slower)
      cmd = [
        'ffmpeg',
        '-i', input_file,
        '-ss', start_time.to_s,
        '-t', duration.to_s,
        '-c', 'copy',
        '-avoid_negative_ts', '1',
        output_file,
        '-y'
      ]

      stdout, stderr, status = Open3.capture3(*cmd)
      
      unless status.success?
        raise DownloadError, "Segment extraction failed: #{stderr}"
      end
    end

    def generate_segment_output_path(start_time, end_time)
      # Get video info for filename generation
      video_info = info
      
      filename = "#{sanitize_filename(video_info.title)}-#{video_info.id}-segment-#{start_time}-#{end_time}.#{video_info.ext || 'mp4'}"
      File.join(@options.output_path, filename)
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

    def get_full_video_for_segmentation
      # Return cached video if available
      if @cached_video_path && File.exist?(@cached_video_path)
        log "Using cached video: #{@cached_video_path}"
        return @cached_video_path
      end
      
      # Extract video info first (needed for segment naming)
      @video_info ||= info
      
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
  end
end
