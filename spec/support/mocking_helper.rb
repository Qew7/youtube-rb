require 'json'
require 'fileutils'

module MockingHelper
  # Mock the YtdlpWrapper to return video info without making actual yt-dlp calls
  def mock_ytdlp(video_data)
    video_info = YoutubeRb::VideoInfo.new(video_data)
    
    # Mock YtdlpWrapper availability
    allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
    
    # Mock extract_info to return video data
    allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:extract_info).and_return(video_data)
    
    # Mock download methods - create actual files
    allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download) do |instance, url, output_path|
      # If output_path is provided, use it; otherwise generate from options
      if output_path
        output_file = output_path
      else
        options = instance.instance_variable_get(:@options)
        output_dir = options.output_path || (@test_output_dir || './test_downloads')
        template = options.output_template || '%(title)s-%(id)s.%(ext)s'
        
        # Simple template replacement
        filename = template
          .gsub('%(title)s', (video_data['title'] || 'video').gsub(/[\/\\:*?"<>|]/, '_'))
          .gsub('%(id)s', video_data['id'] || 'unknown')
          .gsub('%(ext)s', video_data['ext'] || 'mp4')
        
        output_file = File.join(output_dir, filename)
      end
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(output_file))
      
      # Create a fake video file
      File.write(output_file, "fake video data" * 1000)
      
      # Create subtitle files if requested
      options = instance.instance_variable_get(:@options)
      if options && (options.write_subtitles || options.write_auto_sub)
        base_name = File.basename(output_file, File.extname(output_file))
        subtitle_langs = options.subtitle_langs || ['en']
        subtitle_format = options.subtitle_format || 'srt'
        available_subtitles = video_data['subtitles'] || {}
        
        subtitle_langs.each do |lang|
          # Only create subtitle file if language is available in video data
          next unless available_subtitles.key?(lang)
          
          subtitle_file = File.join(File.dirname(output_file), "#{base_name}.#{lang}.#{subtitle_format}")
          File.write(subtitle_file, "WEBVTT\n\n00:00:00.000 --> 00:00:10.000\nTest subtitle")
        end
      end
      
      # Create metadata files if requested
      if options
        base_name = File.basename(output_file, File.extname(output_file))
        dir = File.dirname(output_file)
        
        if options.write_info_json
          info_file = File.join(dir, "#{base_name}.info.json")
          File.write(info_file, JSON.generate(video_data))
        end
        
        if options.write_thumbnail && video_data['thumbnail']
          ext = File.extname(video_data['thumbnail']).split('?').first || '.jpg'
          thumbnail_file = File.join(dir, "#{base_name}#{ext}")
          File.write(thumbnail_file, "fake thumbnail data")
        end
        
        if options.write_description && video_data['description']
          desc_file = File.join(dir, "#{base_name}.description")
          File.write(desc_file, video_data['description'])
        end
      end
      
      output_file
    end
    
    # Mock download_segment
    allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download_segment) do |_, url, start_time, end_time, output_path|
      output_file = output_path || File.join(@test_output_dir || './test_downloads', "segment-#{start_time}-#{end_time}.mp4")
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(output_file))
      
      # Create a fake segment file
      File.write(output_file, "fake segment data" * 1000)
      
      output_file
    end
    
    video_info
  end

  # For backward compatibility with tests that use mock_extractor
  alias_method :mock_extractor, :mock_ytdlp

  # Mock YtdlpWrapper to raise error
  def mock_ytdlp_error(message = 'Test error')
    allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
    allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:extract_info)
      .and_raise(YoutubeRb::YtdlpWrapper::YtdlpError, message)
  end

  # For backward compatibility
  def mock_extractor_error(error_class = nil, message = 'Test error')
    mock_ytdlp_error(message)
  end
end

RSpec.configure do |config|
  config.include MockingHelper
end
