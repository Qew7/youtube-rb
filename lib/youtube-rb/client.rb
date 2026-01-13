module YoutubeRb
  class Client
    attr_reader :options

    def initialize(**options)
      @options = Options.new(**options)
    end

    # Get video information without downloading
    # @param url [String] Video URL
    # @return [VideoInfo] Video information object
    def info(url)
      extractor = Extractor.new(url, @options.to_h)
      extractor.extract_info
    end

    # Download full video
    # @param url [String] Video URL
    # @param options [Hash] Additional options for this download
    # @return [String] Path to downloaded file
    def download(url, **options)
      merged_options = @options.dup.merge(options)
      downloader = Downloader.new(url, merged_options)
      downloader.download
    end

    # Download video segment
    # @param url [String] Video URL
    # @param start_time [Integer] Start time in seconds
    # @param end_time [Integer] End time in seconds
    # @param output_file [String, nil] Optional output file path
    # @param options [Hash] Additional options for this download
    # @return [String] Path to downloaded segment file
    def download_segment(url, start_time, end_time, output_file: nil, **options)
      merged_options = @options.dup.merge(options)
      downloader = Downloader.new(url, merged_options)
      downloader.download_segment(start_time, end_time, output_file)
    end

    # Download multiple video segments (batch processing)
    # @param url [String] Video URL
    # @param segments [Array<Hash>] Array of segment definitions: [{start: 0, end: 30, output_file: 'seg1.mp4'}, ...]
    #   Each segment hash should contain:
    #   - :start (required) - Start time in seconds
    #   - :end (required) - End time in seconds
    #   - :output_file (optional) - Custom output file path
    # @param options [Hash] Additional options for this download
    # @return [Array<String>] Paths to downloaded segment files
    # @example Download multiple segments from one video
    #   client.download_segments(url, [
    #     { start: 0, end: 30 },
    #     { start: 60, end: 90 },
    #     { start: 120, end: 150, output_file: './custom_name.mp4' }
    #   ])
    def download_segments(url, segments, **options)
      # Enable caching by default for batch downloads (can be overridden)
      merged_options = @options.dup.merge({ cache_full_video: true }.merge(options))
      downloader = Downloader.new(url, merged_options)
      downloader.download_segments(segments)
    end

    # Download only subtitles
    # @param url [String] Video URL
    # @param langs [Array<String>, nil] Subtitle languages to download
    # @param options [Hash] Additional options for this download
    # @return [void]
    def download_subtitles(url, langs: nil, **options)
      merged_options = @options.dup.merge(options)
      merged_options.write_subtitles = true
      downloader = Downloader.new(url, merged_options)
      downloader.download_subtitles_only(langs)
    end

    # Download video with subtitles and metadata
    # @param url [String] Video URL
    # @param options [Hash] Additional options for this download
    # @return [String] Path to downloaded file
    def download_with_metadata(url, **options)
      merged_options = @options.dup.merge(
        write_subtitles: true,
        write_info_json: true,
        write_thumbnail: true,
        **options
      )
      downloader = Downloader.new(url, merged_options)
      downloader.download
    end

    # Extract audio from video
    # @param url [String] Video URL
    # @param format [String] Audio format (mp3, aac, opus, etc.)
    # @param quality [String] Audio quality (e.g., '192')
    # @param options [Hash] Additional options for this download
    # @return [String] Path to downloaded audio file
    def extract_audio(url, format: 'mp3', quality: '192', **options)
      merged_options = @options.dup.merge(
        extract_audio: true,
        audio_format: format,
        audio_quality: quality,
        **options
      )
      downloader = Downloader.new(url, merged_options)
      downloader.download
    end

    # Check if video URL is valid and extractable
    # @param url [String] Video URL
    # @return [Boolean] True if URL is valid
    def valid_url?(url)
      return false if url.nil? || url.empty?
      
      begin
        info(url)
        true
      rescue => e
        false
      end
    end

    # Get available formats for video
    # @param url [String] Video URL
    # @return [Array<Hash>] Available formats
    def formats(url)
      video_info = info(url)
      video_info.formats
    end

    # Get available subtitles for video
    # @param url [String] Video URL
    # @return [Hash] Available subtitles by language
    def subtitles(url)
      video_info = info(url)
      video_info.subtitles
    end

    # Update default options
    # @param options [Hash] Options to update
    # @return [self]
    def configure(**options)
      @options.merge(options)
      self
    end

    # Check if optional tools are available
    # @return [Hash] Status of optional tools
    def check_dependencies
      {
        ffmpeg: system('which ffmpeg > /dev/null 2>&1'),
        ytdlp: YtdlpWrapper.available?,
        ytdlp_version: YtdlpWrapper.version
      }
    end

    # Get version information
    # @return [String] Version string
    def version
      YoutubeRb::VERSION
    end
  end
end
