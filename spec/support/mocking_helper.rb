module MockingHelper
  # Mock the Extractor to return video info without making HTTP requests
  def mock_extractor(video_data)
    video_info = YoutubeRb::VideoInfo.new(video_data)
    
    allow_any_instance_of(YoutubeRb::Extractor).to receive(:extract_info).and_return(video_info)
    allow_any_instance_of(YoutubeRb::Extractor).to receive(:extract_formats).and_return(video_data['formats'] || [])
    allow_any_instance_of(YoutubeRb::Extractor).to receive(:extract_subtitles).and_return(video_data['subtitles'] || {})
    
    video_info
  end

  # Mock extractor to raise error
  def mock_extractor_error(error_class = YoutubeRb::Extractor::ExtractionError, message = 'Test error')
    allow_any_instance_of(YoutubeRb::Extractor).to receive(:extract_info).and_raise(error_class, message)
  end
end

RSpec.configure do |config|
  config.include MockingHelper
end
