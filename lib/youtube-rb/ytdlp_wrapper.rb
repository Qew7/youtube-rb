require 'open3'
require 'json'
require 'shellwords'

module YoutubeRb
  class YtdlpWrapper
    class YtdlpNotFoundError < StandardError; end
    class YtdlpError < StandardError; end

    attr_reader :options

    def initialize(options = {})
      @options = options.is_a?(Options) ? options : Options.new(**options)
      check_ytdlp_installation!
    end

    # Extract video information using yt-dlp
    # @param url [String] Video URL
    # @return [Hash] Video information
    def extract_info(url)
      args = build_info_args(url)
      output, status = execute_ytdlp(args)

      raise YtdlpError, "Failed to extract info: #{output}" unless status.success?

      JSON.parse(output)
    rescue JSON::ParserError => e
      raise YtdlpError, "Failed to parse yt-dlp output: #{e.message}"
    end

    # Download video using yt-dlp
    # @param url [String] Video URL
    # @param output_path [String] Output file path
    # @return [String] Path to downloaded file
    def download(url, output_path = nil)
      args = build_download_args(url, output_path)
      output, status = execute_ytdlp(args, show_progress: true)

      unless status.success?
        raise YtdlpError, "Download failed: #{output}"
      end

      # Return the actual output path
      output_path || detect_output_file(output)
    end

    # Download video segment using yt-dlp
    # @param url [String] Video URL
    # @param start_time [Integer] Start time in seconds
    # @param end_time [Integer] End time in seconds
    # @param output_path [String, nil] Output file path
    # @return [String] Path to downloaded segment
    def download_segment(url, start_time, end_time, output_path = nil)
      args = build_segment_args(url, start_time, end_time, output_path)
      output, status = execute_ytdlp(args, show_progress: true)

      unless status.success?
        raise YtdlpError, "Segment download failed: #{output}"
      end

      output_path || detect_output_file(output)
    end

    # Check if yt-dlp is installed
    # @return [Boolean]
    def self.available?
      system('which yt-dlp > /dev/null 2>&1') || 
      system('which youtube-dl > /dev/null 2>&1')
    end

    # Get yt-dlp version
    # @return [String] Version string
    def self.version
      output, status = Open3.capture2('yt-dlp', '--version')
      status.success? ? output.strip : 'unknown'
    rescue
      'not installed'
    end

    private

    def check_ytdlp_installation!
      unless self.class.available?
        raise YtdlpNotFoundError, <<~MSG
          yt-dlp is not installed. Please install it:
          
          # Using pip:
          pip install -U yt-dlp
          
          # Or using pipx:
          pipx install yt-dlp
          
          # Or using homebrew (macOS):
          brew install yt-dlp
          
          # Or download binary from:
          https://github.com/yt-dlp/yt-dlp/releases
        MSG
      end
    end

    def build_info_args(url)
      args = ['yt-dlp', '--dump-json', '--no-playlist']
      
      # Add cookies file if specified
      if @options.cookies_file && File.exist?(@options.cookies_file)
        args += ['--cookies', @options.cookies_file]
      end
      
      # Add user agent
      if @options.user_agent
        args += ['--user-agent', @options.user_agent]
      end
      
      # Add referer
      if @options.referer
        args += ['--referer', @options.referer]
      end
      
      # Add authentication
      if @options.username && @options.password
        args += ['--username', @options.username, '--password', @options.password]
      end
      
      # Add retries
      args += ['--retries', @options.retries.to_s]
      
      args << url
      args
    end

    def build_download_args(url, output_path)
      args = ['yt-dlp']
      
      # Output template
      if output_path
        args += ['-o', output_path]
      else
        template = @options.output_template
        output_dir = @options.output_path
        full_template = File.join(output_dir, template)
        args += ['-o', full_template]
      end
      
      # Format selection
      if @options.extract_audio
        args += ['-x', '--audio-format', @options.audio_format]
        args += ['--audio-quality', @options.audio_quality] if @options.audio_quality
      else
        format = build_format_string
        args += ['-f', format] if format
      end
      
      # Subtitles
      if @options.write_subtitles
        args << '--write-subs'
        args += ['--sub-langs', @options.subtitle_langs.join(',')]
        args += ['--sub-format', @options.subtitle_format]
      end
      
      if @options.write_auto_sub
        args << '--write-auto-subs'
      end
      
      # Metadata
      args << '--write-info-json' if @options.write_info_json
      args << '--write-thumbnail' if @options.write_thumbnail
      args << '--write-description' if @options.write_description
      
      # Cookies and authentication
      if @options.cookies_file && File.exist?(@options.cookies_file)
        args += ['--cookies', @options.cookies_file]
      end
      
      if @options.username && @options.password
        args += ['--username', @options.username, '--password', @options.password]
      end
      
      # Network options
      args += ['--user-agent', @options.user_agent] if @options.user_agent
      args += ['--referer', @options.referer] if @options.referer
      args += ['--retries', @options.retries.to_s]
      args += ['--rate-limit', @options.rate_limit] if @options.rate_limit
      
      # Filesystem options
      args << '--no-overwrites' if @options.no_overwrites
      args << '--continue' if @options.continue_download
      args << '--no-part' if @options.no_part
      
      # Playlist handling
      args << '--no-playlist' if @options.no_playlist
      args << '--yes-playlist' if @options.yes_playlist
      
      args << url
      args
    end

    def build_segment_args(url, start_time, end_time, output_path)
      args = build_download_args(url, output_path)
      
      # Add download sections for segment
      # yt-dlp format: *start_time-end_time
      section = "*#{start_time}-#{end_time}"
      args.insert(-2, '--download-sections', section)
      
      # Use ffmpeg for precise cutting
      args.insert(-2, '--force-keyframes-at-cuts')
      
      args
    end

    def build_format_string
      case @options.quality
      when 'best'
        'bestvideo+bestaudio/best'
      when 'worst'
        'worstvideo+worstaudio/worst'
      when /^\d+p$/
        # e.g., "720p", "1080p"
        height = @options.quality.to_i
        "bestvideo[height<=#{height}]+bestaudio/best[height<=#{height}]"
      else
        @options.format || 'best'
      end
    end

    def execute_ytdlp(args, show_progress: false)
      # Escape arguments for shell
      escaped_args = args.map { |arg| Shellwords.escape(arg) }
      
      if show_progress && @options.respond_to?(:verbose) && @options.verbose
        # Show yt-dlp output in real-time
        puts "Executing: #{args.join(' ')}" if ENV['DEBUG']
        system(*args)
        status = $?
        ['', status]
      else
        # Capture output
        stdout, stderr, status = Open3.capture3(*args)
        output = stdout.empty? ? stderr : stdout
        [output, status]
      end
    end

    def detect_output_file(output)
      # Try to detect the output file from yt-dlp output
      # yt-dlp outputs: [download] Destination: filename.ext
      if match = output.match(/\[download\] Destination: (.+)/)
        return match[1].strip
      end
      
      # Fallback: try to find the file in output directory
      # This is less reliable but better than nothing
      output_dir = @options.output_path
      files = Dir.glob(File.join(output_dir, '*')).sort_by { |f| File.mtime(f) }
      files.last
    end
  end
end
