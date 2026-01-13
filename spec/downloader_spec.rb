RSpec.describe YoutubeRb::Downloader do
  let(:test_url) { 'https://www.youtube.com/watch?v=test123abc' }
  let(:video_data) { sample_video_data }
  let(:options) { YoutubeRb::Options.new(output_path: @test_output_dir) }
  let(:downloader) { described_class.new(test_url, options) }

  before do
    mock_extractor(video_data)
  end

  describe '#initialize' do
    it 'creates downloader with URL and options object' do
      dl = described_class.new(test_url, options)
      
      expect(dl.url).to eq(test_url)
      expect(dl.options).to be_a(YoutubeRb::Options)
      expect(dl.options.output_path).to eq(@test_output_dir)
    end

    it 'creates downloader with URL and options hash' do
      dl = described_class.new(test_url, output_path: '/tmp/test')
      
      expect(dl.url).to eq(test_url)
      expect(dl.options).to be_a(YoutubeRb::Options)
      expect(dl.options.output_path).to eq('/tmp/test')
    end

    it 'accepts empty options' do
      dl = described_class.new(test_url)
      
      expect(dl.url).to eq(test_url)
      expect(dl.options).to be_a(YoutubeRb::Options)
    end
  end

  describe '#info' do
    it 'returns video information' do
      info = downloader.info
      
      expect(info).to be_a(YoutubeRb::VideoInfo)
      expect(info.id).to eq('test123abc')
      expect(info.title).to eq('Test Video Title')
    end

    it 'caches video info' do
      info1 = downloader.info
      info2 = downloader.info
      
      expect(info1).to equal(info2)
    end

    it 'calls extractor only once' do
      video_info = YoutubeRb::VideoInfo.new(video_data)
      
      expect_any_instance_of(YoutubeRb::Extractor)
        .to receive(:extract_info).once.and_return(video_info)
      
      downloader.info
      downloader.info
    end
  end

  describe '#download' do
    let(:video_url) { video_data['formats'].last['url'] }  # Use 720p (highest quality)

    before do
      stub_video_download(video_url)
    end

    context 'basic video download' do
      it 'downloads video successfully' do
        output_file = downloader.download
        
        expect(output_file).to be_a(String)
        expect(File.exist?(output_file)).to be true
        expect(File.size(output_file)).to be > 0
      end

      it 'creates output directory' do
        expect(Dir.exist?(@test_output_dir)).to be true
        
        downloader.download
        
        expect(Dir.exist?(@test_output_dir)).to be true
      end

      it 'uses output template for filename' do
        custom_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          output_template: 'video-%(id)s.%(ext)s'
        )
        dl = described_class.new(test_url, custom_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        
        output_file = dl.download
        
        expect(File.basename(output_file)).to eq('video-test123abc.mp4')
      end

      it 'sanitizes filename' do
        bad_title_data = video_data.dup
        bad_title_data['title'] = 'Test/Video:With*Bad?Chars'
        
        mock_extractor(bad_title_data)
        stub_video_download(video_url)
        
        dl = described_class.new(
          'https://www.youtube.com/watch?v=badchars',
          options
        )
        
        output_file = dl.download
        filename = File.basename(output_file)
        
        expect(filename).not_to include('/', ':', '*', '?')
        expect(filename).to include('_')
      end
    end

    context 'with subtitles' do
      before do
        video_data['subtitles'].each do |lang, subs|
          subs.each { |sub| stub_subtitle_download(sub['url']) }
        end
      end

      it 'downloads subtitles when enabled' do
        subtitle_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          write_subtitles: true,
          subtitle_langs: ['en']
        )
        dl = described_class.new(test_url, subtitle_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        video_data['subtitles'].each do |lang, subs|
          subs.each { |sub| stub_subtitle_download(sub['url']) }
        end
        
        dl.download
        
        subtitle_files = Dir.glob(File.join(@test_output_dir, '*.srt'))
        expect(subtitle_files).not_to be_empty
      end

      it 'skips subtitles when disabled' do
        dl = described_class.new(test_url, options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        
        dl.download
        
        subtitle_files = Dir.glob(File.join(@test_output_dir, '*.{srt,vtt}'))
        expect(subtitle_files).to be_empty
      end
    end

    context 'with metadata' do
      before do
        stub_thumbnail_download(video_data['thumbnail'])
      end

      it 'writes info JSON when enabled' do
        metadata_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          write_info_json: true
        )
        dl = described_class.new(test_url, metadata_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        stub_thumbnail_download(video_data['thumbnail'])
        
        dl.download
        
        json_files = Dir.glob(File.join(@test_output_dir, '*.info.json'))
        expect(json_files).not_to be_empty
        
        json_content = JSON.parse(File.read(json_files.first))
        expect(json_content['id']).to eq('test123abc')
      end

      it 'downloads thumbnail when enabled' do
        thumbnail_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          write_thumbnail: true
        )
        dl = described_class.new(test_url, thumbnail_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        stub_thumbnail_download(video_data['thumbnail'])
        
        dl.download
        
        image_files = Dir.glob(File.join(@test_output_dir, '*.{jpg,jpeg,png,webp}'))
        expect(image_files).not_to be_empty
      end

      it 'writes description when enabled' do
        desc_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          write_description: true
        )
        dl = described_class.new(test_url, desc_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        
        dl.download
        
        desc_files = Dir.glob(File.join(@test_output_dir, '*.description'))
        expect(desc_files).not_to be_empty
        
        desc_content = File.read(desc_files.first)
        expect(desc_content).to eq('This is a test video description')
      end
    end

    context 'audio extraction' do
      before do
        allow_any_instance_of(described_class).to receive(:ffmpeg_available?).and_return(true)
        allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
      end

      it 'extracts audio when enabled' do
        audio_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          extract_audio: true,
          audio_format: 'mp3',
          audio_quality: '192'
        )
        dl = described_class.new(test_url, audio_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        
        output_file = dl.download
        
        expect(output_file).to be_a(String)
      end

      it 'raises error if ffmpeg not available' do
        audio_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          extract_audio: true
        )
        dl = described_class.new(test_url, audio_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        
        allow_any_instance_of(described_class).to receive(:ffmpeg_available?).and_return(false)
        
        expect {
          dl.download
        }.to raise_error(YoutubeRb::Downloader::DownloadError, /FFmpeg is required/)
      end
    end

    context 'error handling' do
      it 'raises error when no formats available' do
        no_format_data = video_data.dup
        no_format_data['formats'] = []
        
        mock_extractor(no_format_data)
        
        dl = described_class.new(
          'https://www.youtube.com/watch?v=noformat',
          options
        )
        
        expect {
          dl.download
        }.to raise_error(YoutubeRb::Downloader::DownloadError, /No suitable format/)
      end

      it 'raises error when format has no URL' do
        bad_format_data = video_data.dup
        bad_format_data['formats'] = [{ 'format_id' => '18', 'ext' => 'mp4' }]
        
        mock_extractor(bad_format_data)
        
        dl = described_class.new(
          'https://www.youtube.com/watch?v=badformat',
          options
        )
        
        expect {
          dl.download
        }.to raise_error(YoutubeRb::Downloader::DownloadError, /No URL found/)
      end

      it 'handles HTTP download errors' do
        # Disable yt-dlp fallback for this test
        dl = YoutubeRb::Downloader.new(
          test_url,
          output_path: @test_output_dir,
          use_ytdlp: false,
          ytdlp_fallback: false
        )
        
        mock_extractor(video_data)
        stub_request(:get, video_url).to_return(status: 403, body: 'Forbidden')
        
        expect {
          dl.download
        }.to raise_error(YoutubeRb::Downloader::DownloadError, /HTTP download failed/)
      end

      it 'handles network errors' do
        mock_extractor(video_data)
        stub_request(:get, video_url).to_raise(Faraday::ConnectionFailed)
        
        expect {
          downloader.download
        }.to raise_error(YoutubeRb::Downloader::DownloadError, /Network error/)
      end
    end
  end

  describe '#download_segment' do
    let(:video_url) { video_data['formats'].last['url'] }  # Use 720p (highest quality)

    before do
      stub_video_download(video_url)
      allow_any_instance_of(described_class).to receive(:ffmpeg_available?).and_return(true)
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
    end

    it 'downloads video segment' do
      output_file = downloader.download_segment(10, 30)
      
      expect(output_file).to be_a(String)
      expect(output_file).to include('segment-10-30')
    end

    it 'accepts custom output file' do
      custom_file = File.join(@test_output_dir, 'custom-segment.mp4')
      output_file = downloader.download_segment(10, 30, custom_file)
      
      expect(output_file).to eq(custom_file)
    end

    it 'calls ffmpeg with correct parameters' do
      expect(Open3).to receive(:capture3).with(
        /ffmpeg.*-ss 10.*-t 20/
      ).and_return(['', '', double(success?: true)])
      
      downloader.download_segment(10, 30)
    end

    it 'validates segment duration minimum' do
      expect {
        downloader.download_segment(0, 5)
      }.to raise_error(ArgumentError, /between 10 and 60 seconds/)
    end

    it 'validates segment duration maximum' do
      expect {
        downloader.download_segment(0, 70)
      }.to raise_error(ArgumentError, /between 10 and 60 seconds/)
    end

    it 'validates start time less than end time' do
      expect {
        downloader.download_segment(30, 10)
      }.to raise_error(ArgumentError, /Start time must be less than end time/)
    end

    it 'accepts valid segment durations' do
      expect {
        downloader.download_segment(0, 10)  # 10 seconds (minimum)
        downloader.download_segment(0, 60)  # 60 seconds (maximum)
        downloader.download_segment(10, 45) # 35 seconds (in range)
      }.not_to raise_error
    end

    it 'cleans up temp files' do
      downloader.download_segment(10, 30)
      
      temp_files = Dir.glob(File.join(@test_output_dir, '.temp_*'))
      expect(temp_files).to be_empty
    end

    it 'raises error if ffmpeg not available' do
      allow_any_instance_of(described_class).to receive(:ffmpeg_available?).and_return(false)
      
      expect {
        downloader.download_segment(10, 30)
      }.to raise_error(YoutubeRb::Downloader::DownloadError, /FFmpeg is required/)
    end

    it 'raises error if ffmpeg fails' do
      allow(Open3).to receive(:capture3).and_return(
        ['', 'Error message', double(success?: false)]
      )
      
      expect {
        downloader.download_segment(10, 30)
      }.to raise_error(YoutubeRb::Downloader::DownloadError, /Segment extraction failed/)
    end

    context 'with subtitles' do
      before do
        video_data['subtitles'].each do |lang, subs|
          subs.each { |sub| stub_subtitle_download(sub['url']) }
        end
      end

      it 'downloads and trims subtitles when enabled' do
        subtitle_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          write_subtitles: true,
          subtitle_langs: ['en']
        )
        dl = described_class.new(test_url, subtitle_options)
        
        mock_extractor(video_data)
        stub_video_download(video_url)
        video_data['subtitles'].each do |lang, subs|
          subs.each { |sub| stub_subtitle_download(sub['url']) }
        end
        
        allow_any_instance_of(described_class).to receive(:ffmpeg_available?).and_return(true)
        allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
        
        dl.download_segment(10, 30)
        
        subtitle_files = Dir.glob(File.join(@test_output_dir, '*segment*.srt'))
        expect(subtitle_files).not_to be_empty
      end
    end
  end

  describe '#download_subtitles_only' do
    before do
      video_data['subtitles'].each do |lang, subs|
        subs.each { |sub| stub_subtitle_download(sub['url']) }
      end
    end

    it 'downloads subtitles without video' do
      downloader.download_subtitles_only(['en'])
      
      subtitle_files = Dir.glob(File.join(@test_output_dir, '*.srt'))
      expect(subtitle_files).not_to be_empty
    end

    it 'downloads multiple language subtitles' do
      downloader.download_subtitles_only(['en', 'es'])
      
      files = Dir.glob(File.join(@test_output_dir, '*.*'))
      expect(files.size).to be >= 2
    end

    it 'uses default subtitle languages from options' do
      subtitle_options = YoutubeRb::Options.new(
        output_path: @test_output_dir,
        subtitle_langs: ['en', 'es']
      )
      dl = described_class.new(test_url, subtitle_options)
      
      mock_extractor(video_data)
      video_data['subtitles'].each do |lang, subs|
        subs.each { |sub| stub_subtitle_download(sub['url']) }
      end
      
      dl.download_subtitles_only
      
      files = Dir.glob(File.join(@test_output_dir, '*.*'))
      expect(files.size).to be >= 2
    end

    it 'creates output directory' do
      custom_dir = File.join(@test_output_dir, 'subs')
      subtitle_options = YoutubeRb::Options.new(output_path: custom_dir)
      dl = described_class.new(test_url, subtitle_options)
      
      mock_extractor(video_data)
      video_data['subtitles'].each do |lang, subs|
        subs.each { |sub| stub_subtitle_download(sub['url']) }
      end
      
      dl.download_subtitles_only(['en'])
      
      expect(Dir.exist?(custom_dir)).to be true
    end

    it 'handles missing subtitle language gracefully' do
      expect {
        downloader.download_subtitles_only(['nonexistent'])
      }.not_to raise_error
      
      subtitle_files = Dir.glob(File.join(@test_output_dir, '*.nonexistent.*'))
      expect(subtitle_files).to be_empty
    end
  end

  describe 'private methods' do
    describe '#sanitize_filename' do
      it 'removes invalid characters' do
        dl = downloader
        result = dl.send(:sanitize_filename, 'test/file:name*with?bad<chars>|')
        
        expect(result).not_to include('/', ':', '*', '?', '<', '>', '|')
        expect(result).to include('_')
      end

      it 'handles nil input' do
        dl = downloader
        result = dl.send(:sanitize_filename, nil)
        
        expect(result).to eq('video')
      end

      it 'handles empty input' do
        dl = downloader
        result = dl.send(:sanitize_filename, '')
        
        expect(result).to eq('video')
      end

      it 'trims whitespace' do
        dl = downloader
        result = dl.send(:sanitize_filename, '  test filename  ')
        
        expect(result).to eq('test filename')
      end
    end

    describe '#audio_codec_for_format' do
      it 'returns correct codec for mp3' do
        dl = downloader
        expect(dl.send(:audio_codec_for_format, 'mp3')).to eq('libmp3lame')
      end

      it 'returns correct codec for aac' do
        dl = downloader
        expect(dl.send(:audio_codec_for_format, 'aac')).to eq('aac')
      end

      it 'returns correct codec for opus' do
        dl = downloader
        expect(dl.send(:audio_codec_for_format, 'opus')).to eq('libopus')
      end

      it 'returns correct codec for flac' do
        dl = downloader
        expect(dl.send(:audio_codec_for_format, 'flac')).to eq('flac')
      end

      it 'returns copy for unknown format' do
        dl = downloader
        expect(dl.send(:audio_codec_for_format, 'unknown')).to eq('copy')
      end
    end

    describe '#valid_segment_duration?' do
      it 'returns true for 10 seconds' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 0, 10)).to be true
      end

      it 'returns true for 60 seconds' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 0, 60)).to be true
      end

      it 'returns true for duration in range' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 10, 45)).to be true
      end

      it 'returns false for less than 10 seconds' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 0, 9)).to be false
      end

      it 'returns false for more than 60 seconds' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 0, 61)).to be false
      end
    end
  end
end
