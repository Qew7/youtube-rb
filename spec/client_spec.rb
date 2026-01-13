RSpec.describe YoutubeRb::Client do
  let(:test_url) { 'https://www.youtube.com/watch?v=test123abc' }
  let(:video_data) { sample_video_data }
  let(:client) { described_class.new(output_path: @test_output_dir) }

  before do
    mock_extractor(video_data)
  end

  describe '#initialize' do
    it 'creates client with default options' do
      client = described_class.new
      expect(client).to be_a(described_class)
      expect(client.options).to be_a(YoutubeRb::Options)
    end

    it 'creates client with custom options' do
      client = described_class.new(output_path: '/tmp/test', format: '720p')
      expect(client.options.output_path).to eq('/tmp/test')
      expect(client.options.format).to eq('720p')
    end

    it 'accepts multiple options' do
      client = described_class.new(
        output_path: './custom',
        write_subtitles: true,
        subtitle_langs: ['en', 'es'],
        audio_format: 'aac'
      )
      expect(client.options.output_path).to eq('./custom')
      expect(client.options.write_subtitles).to eq(true)
      expect(client.options.subtitle_langs).to eq(['en', 'es'])
      expect(client.options.audio_format).to eq('aac')
    end
  end

  describe '#info' do
    it 'returns video information' do
      info = client.info(test_url)
      
      expect(info).to be_a(YoutubeRb::VideoInfo)
      expect(info.id).to eq('test123abc')
      expect(info.title).to eq('Test Video Title')
      expect(info.uploader).to eq('Test Channel')
      expect(info.duration).to eq(180)
      expect(info.view_count).to eq(1000)
    end

    it 'returns formats' do
      info = client.info(test_url)
      
      expect(info.formats).to be_an(Array)
      expect(info.formats.size).to eq(2)
      expect(info.formats.first[:format_id]).to eq('18')
    end

    it 'returns subtitles' do
      info = client.info(test_url)
      
      expect(info.subtitles).to be_a(Hash)
      expect(info.subtitles.keys).to include('en', 'es')
    end

    it 'raises error for invalid URL' do
      mock_extractor_error
      
      expect {
        client.info('https://www.youtube.com/watch?v=invalid')
      }.to raise_error(YoutubeRb::Extractor::ExtractionError)
    end
  end

  describe '#download' do
    let(:video_url) { video_data['formats'].last['url'] }  # Use 720p (highest quality)

    before do
      stub_video_download(video_url)
    end

    it 'downloads video file' do
      output_file = client.download(test_url)
      
      expect(output_file).to be_a(String)
      expect(File.exist?(output_file)).to be true
      expect(File.size(output_file)).to be > 0
    end

    it 'accepts additional options' do
      output_file = client.download(test_url, output_template: 'custom-%(id)s.%(ext)s')
      
      expect(output_file).to include('custom-test123abc')
      expect(File.exist?(output_file)).to be true
    end

    it 'creates output directory if needed' do
      custom_dir = File.join(@test_output_dir, 'nested', 'path')
      custom_client = described_class.new(output_path: custom_dir)
      
      mock_extractor(video_data)
      stub_video_download(video_url)
      
      output_file = custom_client.download(test_url)
      
      expect(Dir.exist?(custom_dir)).to be true
      expect(File.exist?(output_file)).to be true
    end
  end

  describe '#download_segment' do
    let(:video_url) { video_data['formats'].first['url'] }

    before do
      stub_video_download(video_url)
      
      # Mock ffmpeg availability and execution
      allow_any_instance_of(YoutubeRb::Downloader).to receive(:ffmpeg_available?).and_return(true)
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
    end

    it 'downloads video segment' do
      output_file = client.download_segment(test_url, 10, 30)
      
      expect(output_file).to be_a(String)
      expect(output_file).to include('segment-10-30')
    end

    it 'accepts custom output file' do
      custom_file = File.join(@test_output_dir, 'my-segment.mp4')
      output_file = client.download_segment(test_url, 10, 30, output_file: custom_file)
      
      expect(output_file).to eq(custom_file)
    end

    it 'validates segment duration (minimum 10 seconds)' do
      expect {
        client.download_segment(test_url, 0, 5)
      }.to raise_error(ArgumentError, /between 10 and 60 seconds/)
    end

    it 'validates segment duration (maximum 60 seconds)' do
      expect {
        client.download_segment(test_url, 0, 70)
      }.to raise_error(ArgumentError, /between 10 and 60 seconds/)
    end

    it 'validates start time less than end time' do
      expect {
        client.download_segment(test_url, 30, 10)
      }.to raise_error(ArgumentError, /Start time must be less than end time/)
    end

    it 'raises error if ffmpeg not available' do
      allow_any_instance_of(YoutubeRb::Downloader).to receive(:ffmpeg_available?).and_return(false)
      
      expect {
        client.download_segment(test_url, 10, 30)
      }.to raise_error(YoutubeRb::Downloader::DownloadError, /FFmpeg is required/)
    end
  end

  describe '#download_subtitles' do
    before do
      video_data['subtitles'].each do |lang, subs|
        subs.each { |sub| stub_subtitle_download(sub['url']) }
      end
    end

    it 'downloads subtitles for default languages' do
      client.download_subtitles(test_url)
      
      # Should download at least one subtitle file
      subtitle_files = Dir.glob(File.join(@test_output_dir, '*.srt'))
      expect(subtitle_files).not_to be_empty
    end

    it 'downloads subtitles for specific languages' do
      client.download_subtitles(test_url, langs: ['en'])
      
      subtitle_files = Dir.glob(File.join(@test_output_dir, '*.en.*'))
      expect(subtitle_files).not_to be_empty
    end

    it 'accepts additional options' do
      custom_client = described_class.new(
        output_path: @test_output_dir,
        subtitle_format: 'vtt'
      )
      
      mock_extractor(video_data)
      video_data['subtitles'].each do |lang, subs|
        subs.each { |sub| stub_subtitle_download(sub['url']) }
      end
      
      custom_client.download_subtitles(test_url, langs: ['en', 'es'])
      
      # Files should exist
      files = Dir.glob(File.join(@test_output_dir, '*.*'))
      expect(files).not_to be_empty
    end
  end

  describe '#download_with_metadata' do
    let(:video_url) { video_data['formats'].first['url'] }

    before do
      stub_video_download(video_url)
      stub_thumbnail_download(video_data['thumbnail'])
      video_data['subtitles'].each do |lang, subs|
        subs.each { |sub| stub_subtitle_download(sub['url']) }
      end
    end

    it 'downloads video with metadata files' do
      output_file = client.download_with_metadata(test_url)
      
      expect(File.exist?(output_file)).to be true
      
      # Check for metadata files
      base_name = File.basename(output_file, '.*')
      dir = File.dirname(output_file)
      
      # Should create info.json
      json_file = Dir.glob(File.join(dir, '*.info.json')).first
      expect(json_file).not_to be_nil
      
      # Should create thumbnail
      thumbnail_files = Dir.glob(File.join(dir, '*{.jpg,.png,.webp}'))
      expect(thumbnail_files).not_to be_empty
    end

    it 'downloads subtitles along with video' do
      output_file = client.download_with_metadata(test_url)
      
      # Should create subtitle files
      subtitle_files = Dir.glob(File.join(@test_output_dir, '*.{srt,vtt}'))
      expect(subtitle_files).not_to be_empty
    end
  end

  describe '#extract_audio' do
    let(:video_url) { video_data['formats'].first['url'] }

    before do
      stub_video_download(video_url)
      
      # Mock ffmpeg for audio extraction
      allow_any_instance_of(YoutubeRb::Downloader).to receive(:ffmpeg_available?).and_return(true)
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
    end

    it 'extracts audio in default format (mp3)' do
      output_file = client.extract_audio(test_url)
      
      expect(output_file).to be_a(String)
    end

    it 'extracts audio in specified format' do
      output_file = client.extract_audio(test_url, format: 'aac')
      
      expect(output_file).to be_a(String)
    end

    it 'extracts audio with specified quality' do
      output_file = client.extract_audio(test_url, format: 'mp3', quality: '320')
      
      expect(output_file).to be_a(String)
    end

    it 'accepts additional options' do
      output_file = client.extract_audio(
        test_url,
        format: 'opus',
        quality: '128',
        output_template: 'audio-%(id)s.%(ext)s'
      )
      
      expect(output_file).to be_a(String)
    end

    it 'raises error if ffmpeg not available' do
      allow_any_instance_of(YoutubeRb::Downloader).to receive(:ffmpeg_available?).and_return(false)
      
      expect {
        client.extract_audio(test_url)
      }.to raise_error(YoutubeRb::Downloader::DownloadError, /FFmpeg is required/)
    end
  end

  describe '#valid_url?' do
    it 'returns true for valid YouTube URL' do
      expect(client.valid_url?(test_url)).to be true
    end

    it 'returns false for invalid URL' do
      mock_extractor_error
      
      expect(client.valid_url?('https://www.youtube.com/watch?v=invalid')).to be false
    end

    it 'returns false for nil URL' do
      expect(client.valid_url?(nil)).to be false
    end

    it 'returns false for empty URL' do
      expect(client.valid_url?('')).to be false
    end

    it 'returns false for non-YouTube URL' do
      mock_extractor_error(YoutubeRb::Extractor::ExtractionError, 'Not a YouTube URL')
      
      expect(client.valid_url?('https://example.com')).to be false
    end
  end

  describe '#formats' do
    it 'returns available formats' do
      formats = client.formats(test_url)
      
      expect(formats).to be_an(Array)
      expect(formats.size).to eq(2)
      expect(formats.first).to be_a(Hash)
      expect(formats.first[:format_id]).to eq('18')
      expect(formats.first[:height]).to eq(360)
    end

    it 'returns empty array if no formats available' do
      no_formats_data = video_data.dup
      no_formats_data['formats'] = []
      
      mock_extractor(no_formats_data)
      
      formats = client.formats('https://www.youtube.com/watch?v=noformats')
      expect(formats).to eq([])
    end
  end

  describe '#subtitles' do
    it 'returns available subtitles' do
      subtitles = client.subtitles(test_url)
      
      expect(subtitles).to be_a(Hash)
      expect(subtitles.keys).to include('en', 'es')
      expect(subtitles['en']).to be_an(Array)
      expect(subtitles['en'].first).to have_key(:url)
    end

    it 'returns empty hash if no subtitles available' do
      no_subs_data = video_data.dup
      no_subs_data['subtitles'] = {}
      
      mock_extractor(no_subs_data)
      
      subtitles = client.subtitles('https://www.youtube.com/watch?v=nosubs')
      expect(subtitles).to eq({})
    end
  end

  describe '#configure' do
    it 'updates client options' do
      client.configure(format: '1080p', quality: 'high')
      
      expect(client.options.format).to eq('1080p')
      expect(client.options.quality).to eq('high')
    end

    it 'returns self for chaining' do
      result = client.configure(format: '720p')
      
      expect(result).to eq(client)
    end

    it 'preserves existing options' do
      original_path = client.options.output_path
      client.configure(format: '720p')
      
      expect(client.options.output_path).to eq(original_path)
    end

    it 'can be chained' do
      client
        .configure(format: '1080p')
        .configure(write_subtitles: true)
        .configure(audio_quality: '320')
      
      expect(client.options.format).to eq('1080p')
      expect(client.options.write_subtitles).to eq(true)
      expect(client.options.audio_quality).to eq('320')
    end
  end

  describe '#check_dependencies' do
    it 'returns hash with dependency status' do
      deps = client.check_dependencies
      
      expect(deps).to be_a(Hash)
      expect(deps).to have_key(:ffmpeg)
      expect([true, false]).to include(deps[:ffmpeg])
    end

    it 'checks ffmpeg availability' do
      allow(client).to receive(:system).with('which ffmpeg > /dev/null 2>&1').and_return(true)
      
      deps = client.check_dependencies
      expect(deps[:ffmpeg]).to be true
    end

    it 'returns false when ffmpeg not available' do
      allow(client).to receive(:system).with('which ffmpeg > /dev/null 2>&1').and_return(false)
      
      deps = client.check_dependencies
      expect(deps[:ffmpeg]).to be false
    end
  end

  describe '#version' do
    it 'returns version string' do
      expect(client.version).to eq(YoutubeRb::VERSION)
    end

    it 'returns non-empty version' do
      expect(client.version).not_to be_nil
      expect(client.version).not_to be_empty
    end
  end
end
