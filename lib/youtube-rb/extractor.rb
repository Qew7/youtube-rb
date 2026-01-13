require 'json'
require 'faraday'
require 'faraday/retry'
require 'nokogiri'
require 'cgi'
require 'base64'
require 'date'

module YoutubeRb
  class Extractor
    class ExtractionError < StandardError; end

    attr_reader :url, :options

    def initialize(url, options = {})
      @url = url
      @options = options
      @http_client = build_http_client
    end

    def extract_info
      # Use pure Ruby extraction
      info = extract_youtube_info
      
      raise ExtractionError, "Failed to extract video information from #{@url}" unless info
      
      VideoInfo.new(info)
    end

    def extract_formats
      info = extract_info
      info.formats
    end

    def extract_subtitles
      info = extract_info
      info.subtitles
    end

    private

    def extract_youtube_info
      return nil unless youtube_url?

      begin
        response = @http_client.get(@url)
        raise ExtractionError, "Failed to fetch page: HTTP #{response.status}" unless response.success?

        # Handle encoding properly
        body = response.body
        body = body.force_encoding('UTF-8') unless body.encoding == Encoding::UTF_8
        body = body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

        parse_youtube_page(body)
      rescue Faraday::Error => e
        raise ExtractionError, "Network error: #{e.message}"
      rescue => e
        raise ExtractionError, "Extraction failed: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      end
    end

    def parse_youtube_page(html)
      # Extract video ID from URL
      video_id = extract_video_id(@url)
      raise ExtractionError, "Could not extract video ID from URL" unless video_id

      # Try to find ytInitialPlayerResponse in page
      player_response = extract_player_response(html)
      raise ExtractionError, "Could not extract player response from page" unless player_response

      # Parse video details
      video_details = player_response['videoDetails'] || {}
      streaming_data = player_response['streamingData'] || {}
      microformat = player_response.dig('microformat', 'playerMicroformatRenderer') || {}

      # Decrypt streaming URLs if needed
      if streaming_data['formats'] || streaming_data['adaptiveFormats']
        streaming_data = decrypt_streaming_data(streaming_data, html)
      end

      {
        'id' => video_id,
        'title' => video_details['title'] || microformat['title'],
        'fulltitle' => video_details['title'] || microformat['title'],
        'description' => video_details['shortDescription'] || microformat['description'],
        'duration' => video_details['lengthSeconds']&.to_i,
        'view_count' => video_details['viewCount']&.to_i,
        'uploader' => video_details['author'] || microformat['ownerChannelName'],
        'uploader_id' => video_details['channelId'] || microformat['externalChannelId'],
        'upload_date' => parse_upload_date(microformat['uploadDate']),
        'thumbnail' => extract_thumbnail(video_details, microformat),
        'formats' => parse_formats(streaming_data),
        'subtitles' => parse_captions(player_response['captions']),
        'webpage_url' => @url,
        'ext' => 'mp4'
      }
    end

    def extract_player_response(html)
      # Look for ytInitialPlayerResponse assignment
      if match = html.match(/ytInitialPlayerResponse\s*=\s*(\{)/)
        start_pos = match.begin(1)
        json_str = extract_balanced_json_from_position(html, start_pos)
        begin
          return JSON.parse(json_str)
        rescue JSON::ParserError => e
          # Continue to fallback
        end
      end

      # Fallback: Look for var ytInitialPlayerResponse
      if match = html.match(/var\s+ytInitialPlayerResponse\s*=\s*(\{)/)
        start_pos = match.begin(1)
        json_str = extract_balanced_json_from_position(html, start_pos)
        begin
          return JSON.parse(json_str)
        rescue JSON::ParserError => e
          # Continue to fallback
        end
      end

      # Last resort: Look in script tags
      doc = Nokogiri::HTML(html)
      doc.css('script').each do |script|
        content = script.content
        next unless content.include?('ytInitialPlayerResponse')
        
        if match = content.match(/ytInitialPlayerResponse\s*=\s*(\{)/)
          start_pos = match.begin(1)
          json_str = extract_balanced_json_from_position(content, start_pos)
          begin
            return JSON.parse(json_str)
          rescue JSON::ParserError
            next
          end
        end
      end

      nil
    end

    def extract_balanced_json_from_position(str, start_pos)
      # Extract balanced JSON starting from a position
      depth = 0
      result = ''
      in_string = false
      escape_next = false
      
      i = start_pos
      while i < str.length
        char = str[i]
        
        if escape_next
          result += char
          escape_next = false
          i += 1
          next
        end
        
        case char
        when '\\'
          escape_next = true
          result += char
        when '"'
          in_string = !in_string
          result += char
        when '{'
          depth += 1 unless in_string
          result += char
        when '}'
          result += char
          depth -= 1 unless in_string
          return result if depth == 0
        else
          result += char
        end
        
        i += 1
      end
      
      result
    end

    def decrypt_streaming_data(streaming_data, html)
      # For now, return as-is. In the future, we can implement signature decryption
      # YouTube signature decryption is complex and may require executing JavaScript
      # For most videos, formats with direct URLs should be available
      streaming_data
    end

    def extract_thumbnail(video_details, microformat)
      # Try multiple sources for thumbnail
      thumbnail = nil
      
      if video_details['thumbnail'] && video_details['thumbnail']['thumbnails']
        thumbnails = video_details['thumbnail']['thumbnails']
        thumbnail = thumbnails.last['url'] if thumbnails.any?
      end
      
      thumbnail ||= microformat.dig('thumbnail', 'thumbnails', -1, 'url')
      
      # Fallback to default YouTube thumbnail
      thumbnail ||= "https://i.ytimg.com/vi/#{extract_video_id(@url)}/maxresdefault.jpg"
      
      thumbnail
    end

    def parse_upload_date(date_str)
      return nil unless date_str
      
      # Parse ISO date format (e.g., "2005-04-23")
      begin
        Date.parse(date_str).strftime('%Y%m%d')
      rescue
        nil
      end
    end

    def parse_formats(streaming_data)
      formats = []
      
      # Parse regular formats (contain both video and audio)
      if streaming_data['formats']
        streaming_data['formats'].each do |format|
          parsed = parse_format(format)
          formats << parsed if parsed && parsed['url']
        end
      end
      
      # Parse adaptive formats (separate audio/video)
      if streaming_data['adaptiveFormats']
        streaming_data['adaptiveFormats'].each do |format|
          parsed = parse_format(format)
          formats << parsed if parsed && parsed['url']
        end
      end
      
      formats
    end

    def parse_format(format_data)
      # Get URL - it might be directly available or need to be constructed
      url = format_data['url']
      
      # If no direct URL, try to construct from signatureCipher or cipher
      unless url
        cipher = format_data['signatureCipher'] || format_data['cipher']
        if cipher
          url = decode_cipher(cipher)
        end
      end
      
      return nil unless url
      
      {
        'format_id' => format_data['itag']&.to_s,
        'url' => url,
        'ext' => extract_extension(format_data['mimeType']),
        'width' => format_data['width'],
        'height' => format_data['height'],
        'fps' => format_data['fps'],
        'quality' => format_data['quality'],
        'qualityLabel' => format_data['qualityLabel'],
        'tbr' => format_data['bitrate'] ? (format_data['bitrate'] / 1000.0).round : nil,
        'filesize' => format_data['contentLength']&.to_i,
        'vcodec' => extract_video_codec(format_data['mimeType']),
        'acodec' => extract_audio_codec(format_data['mimeType']),
        'format_note' => format_data['qualityLabel'] || format_data['quality']
      }
    end

    def decode_cipher(cipher_string)
      # Parse the cipher string (format: "s=signature&url=URL")
      params = CGI.parse(cipher_string)
      url = params['url']&.first
      
      # For now, return the URL as-is
      # Full signature decryption would require JavaScript execution
      # which is complex to implement in pure Ruby
      url
    end

    def parse_captions(captions_data)
      return {} unless captions_data

      subtitles = {}
      
      # Get caption tracks
      renderer = captions_data['playerCaptionsTracklistRenderer']
      return {} unless renderer
      
      tracks = renderer['captionTracks'] || []
      
      tracks.each do |track|
        lang = track['languageCode']
        next unless lang
        
        url = track['baseUrl']
        next unless url
        
        # Get caption name
        name = if track['name'].is_a?(Hash)
                 track['name']['simpleText'] || track['name'].dig('runs', 0, 'text')
               else
                 track['name']
               end
        
        subtitles[lang] = [{
          'ext' => 'vtt',
          'url' => url,
          'name' => name || lang
        }]
      end
      
      # Also check for auto-generated captions
      auto_tracks = renderer['automaticCaptionTracks'] || renderer['translationLanguages'] || []
      
      subtitles
    end

    def extract_video_id(url)
      # Extract video ID from various YouTube URL formats
      patterns = [
        /(?:youtube\.com\/watch\?.*v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/v\/([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/
      ]
      
      patterns.each do |pattern|
        match = url.match(pattern)
        return match[1] if match
      end
      
      nil
    end

    def extract_extension(mime_type)
      return nil unless mime_type
      
      case mime_type
      when /video\/mp4/
        'mp4'
      when /video\/webm/
        'webm'
      when /audio\/mp4/
        'm4a'
      when /audio\/webm/
        'webm'
      else
        'mp4'
      end
    end

    def extract_video_codec(mime_type)
      return 'none' unless mime_type
      return 'none' unless mime_type.include?('video')
      
      case mime_type
      when /codecs="([^"]+)"/
        codecs = $1.split(',').first
        codecs.strip
      else
        'unknown'
      end
    end

    def extract_audio_codec(mime_type)
      return 'none' unless mime_type
      return 'none' unless mime_type.include?('audio')
      
      case mime_type
      when /codecs="([^"]+)"/
        codecs = $1.split(',').last || $1
        codecs.strip
      else
        'unknown'
      end
    end

    def youtube_url?
      @url.match?(/(?:youtube\.com|youtu\.be)/)
    end

    def build_http_client
      Faraday.new do |f|
        f.request :retry, max: 3, interval: 1, backoff_factor: 2
        f.adapter Faraday.default_adapter
        f.options.timeout = 60
        f.options.open_timeout = 30
        
        # Use simple browser-like headers
        user_agent = if @options.is_a?(Hash) && @options[:user_agent]
                      @options[:user_agent]
                    elsif @options.respond_to?(:user_agent) && @options.user_agent
                      @options.user_agent
                    else
                      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                    end
        
        f.headers['User-Agent'] = user_agent
        
        # Add referer if provided
        referer = if @options.is_a?(Hash) && @options[:referer]
                   @options[:referer]
                 elsif @options.respond_to?(:referer)
                   @options.referer
                 end
        f.headers['Referer'] = referer if referer
        
        # Add cookies if provided
        cookies_file = if @options.is_a?(Hash) && @options[:cookies_file]
                        @options[:cookies_file]
                      elsif @options.respond_to?(:cookies_file)
                        @options.cookies_file
                      end
        
        if cookies_file && File.exist?(cookies_file)
          cookies = File.read(cookies_file).strip
          f.headers['Cookie'] = cookies
        end
      end
    end
  end
end
