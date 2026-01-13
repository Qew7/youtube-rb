require_relative "youtube-rb/version"
require_relative "youtube-rb/options"
require_relative "youtube-rb/video_info"
require_relative "youtube-rb/ytdlp_wrapper"
require_relative "youtube-rb/downloader"
require_relative "youtube-rb/client"

module YoutubeRb
  class Error < StandardError; end
  class DownloadError < Error; end
  class ValidationError < Error; end

  # Convenience method to create a new client
  # @param options [Hash] Client options
  # @return [Client] New client instance
  def self.new(**options)
    Client.new(**options)
  end

  # Quick download method
  # @param url [String] Video URL
  # @param options [Hash] Download options
  # @return [String] Path to downloaded file
  def self.download(url, **options)
    client = Client.new(**options)
    client.download(url)
  end

  # Quick info extraction method
  # @param url [String] Video URL
  # @return [VideoInfo] Video information
  def self.info(url)
    client = Client.new
    client.info(url)
  end

  # Quick segment download method
  # @param url [String] Video URL
  # @param start_time [Integer] Start time in seconds
  # @param end_time [Integer] End time in seconds
  # @param options [Hash] Download options
  # @return [String] Path to downloaded segment
  def self.download_segment(url, start_time, end_time, **options)
    client = Client.new(**options)
    client.download_segment(url, start_time, end_time, **options)
  end

  # Quick batch segment download method
  # @param url [String] Video URL
  # @param segments [Array<Hash>] Array of segment definitions
  # @param options [Hash] Download options
  # @return [Array<String>] Paths to downloaded segments
  def self.download_segments(url, segments, **options)
    client = Client.new(**options)
    client.download_segments(url, segments, **options)
  end

  # Quick subtitles download method
  # @param url [String] Video URL
  # @param langs [Array<String>, nil] Languages to download
  # @param options [Hash] Download options
  # @return [void]
  def self.download_subtitles(url, langs: nil, **options)
    client = Client.new(**options)
    client.download_subtitles(url, langs: langs, **options)
  end
end
