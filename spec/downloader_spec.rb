RSpec.describe YoutubeRb::Downloader do
  let(:test_url) { 'https://www.youtube.com/watch?v=test123abc' }
  let(:video_data) { sample_video_data }
  let(:options) { YoutubeRb::Options.new(output_path: @test_output_dir) }
  let(:downloader) { described_class.new(test_url, options) }

  before do
    mock_ytdlp(video_data)
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

    it 'calls ytdlp only once' do
      expect_any_instance_of(YoutubeRb::YtdlpWrapper)
        .to receive(:extract_info).once.and_return(video_data)
      
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
        
        mock_ytdlp(video_data)
        stub_video_download(video_url)
        
        output_file = dl.download
        
        expect(File.basename(output_file)).to eq('video-test123abc.mp4')
      end

      it 'sanitizes filename' do
        bad_title_data = video_data.dup
        bad_title_data['title'] = 'Test/Video:With*Bad?Chars'
        
        mock_ytdlp(bad_title_data)
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
        
        mock_ytdlp(video_data)
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
        
        mock_ytdlp(video_data)
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
        
        mock_ytdlp(video_data)
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
        
        mock_ytdlp(video_data)
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
        
        mock_ytdlp(video_data)
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
        
        mock_ytdlp(video_data)
        stub_video_download(video_url)
        
        output_file = dl.download
        
        expect(output_file).to be_a(String)
      end

    end

    context 'error handling' do
      it 'handles download errors' do
        allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download)
          .and_raise(YoutubeRb::YtdlpWrapper::YtdlpError, 'Download failed')
        
        expect {
          downloader.download
        }.to raise_error(YoutubeRb::Downloader::DownloadError, /Download failed/)
      end
    end
  end

  describe '#download_segment' do
    before do
      allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
    end

    it 'requires yt-dlp to be installed' do
      allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(false)
      
      expect {
        downloader.download_segment(10, 30)
      }.to raise_error(YoutubeRb::Downloader::DownloadError, /yt-dlp is required/)
    end

    context 'with yt-dlp available' do
      before do
        # Mock ytdlp_wrapper.download_segment
        allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download_segment) do |_, url, start_time, end_time, output_file|
          output_file || File.join(@test_output_dir, "segment-#{start_time}-#{end_time}.mp4")
        end
      end

      it 'downloads video segment using yt-dlp' do
        output_file = downloader.download_segment(10, 30)
        
        expect(output_file).to be_a(String)
        expect(output_file).to include('segment')
      end

      it 'accepts custom output file' do
        custom_file = File.join(@test_output_dir, 'custom-segment.mp4')
        output_file = downloader.download_segment(10, 30, custom_file)
        
        expect(output_file).to eq(custom_file)
      end

      it 'calls ytdlp wrapper download_segment' do
        expect_any_instance_of(YoutubeRb::YtdlpWrapper)
          .to receive(:download_segment)
          .with(test_url, 10, 30, nil)
          .and_return(File.join(@test_output_dir, 'segment-10-30.mp4'))
        
        downloader.download_segment(10, 30)
      end
    end

    it 'validates segment duration minimum (default 10s)' do
      expect {
        downloader.download_segment(0, 5)
      }.to raise_error(ArgumentError, /between 10 and 60 seconds/)
    end

    it 'validates segment duration maximum (default 60s)' do
      expect {
        downloader.download_segment(0, 70)
      }.to raise_error(ArgumentError, /between 10 and 60 seconds/)
    end

    it 'accepts custom min/max segment duration' do
      custom_options = YoutubeRb::Options.new(
        output_path: @test_output_dir,
        min_segment_duration: 5,
        max_segment_duration: 120
      )
      dl = described_class.new(test_url, custom_options)
      
      allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
      allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download_segment) do |_, url, start_time, end_time, output_file|
        output_file || File.join(@test_output_dir, "segment-#{start_time}-#{end_time}.mp4")
      end
      
      # Should accept 5 second segment (custom minimum)
      expect { dl.download_segment(0, 5) }.not_to raise_error
      
      # Should accept 120 second segment (custom maximum)
      expect { dl.download_segment(0, 120) }.not_to raise_error
      
      # Should reject 4 second segment (below custom minimum)
      expect { dl.download_segment(0, 4) }.to raise_error(ArgumentError, /between 5 and 120 seconds/)
      
      # Should reject 121 second segment (above custom maximum)
      expect { dl.download_segment(0, 121) }.to raise_error(ArgumentError, /between 5 and 120 seconds/)
    end

    it 'validates start time less than end time' do
      expect {
        downloader.download_segment(30, 10)
      }.to raise_error(ArgumentError, /Start time must be less than end time/)
    end

    it 'accepts valid segment durations' do
      allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
      allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download_segment) do |_, url, start_time, end_time, output_file|
        output_file || File.join(@test_output_dir, "segment-#{start_time}-#{end_time}.mp4")
      end
      
      expect {
        downloader.download_segment(0, 10)  # 10 seconds (minimum)
        downloader.download_segment(0, 60)  # 60 seconds (maximum)
        downloader.download_segment(10, 45) # 35 seconds (in range)
      }.not_to raise_error
    end
  end

  describe '#download_segments' do
    let(:video_url) { video_data['formats'].last['url'] }

    before do
      # Mock yt-dlp availability and wrapper
      allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
      allow_any_instance_of(described_class).to receive(:ffmpeg_available?).and_return(true)
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
    end

    it 'requires yt-dlp to be installed' do
      allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(false)
      
      segments = [{ start: 10, end: 30 }]
      
      expect {
        downloader.download_segments(segments)
      }.to raise_error(YoutubeRb::Downloader::DownloadError, /yt-dlp is required/)
    end

    context 'with yt-dlp available' do
      before do
        # Mock ytdlp_wrapper.download to simulate video download
        allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download) do |_, url, output_path|
          # Create a fake video file
          FileUtils.touch(output_path)
          output_path
        end
      end

      it 'downloads multiple segments using yt-dlp once + FFmpeg segmentation' do
        segments = [
          { start: 10, end: 30 },
          { start: 60, end: 90 },
          { start: 120, end: 150 }
        ]
        
        output_files = downloader.download_segments(segments)
        
        expect(output_files).to be_an(Array)
        expect(output_files.size).to eq(3)
        output_files.each do |file|
          expect(file).to be_a(String)
        end
      end

      it 'downloads full video only once via yt-dlp' do
        segments = [
          { start: 10, end: 30 },
          { start: 60, end: 90 },
          { start: 120, end: 150 }
        ]
        
        # Should call yt-dlp download exactly once (not N times)
        expect_any_instance_of(YoutubeRb::YtdlpWrapper)
          .to receive(:download).once.and_call_original
        
        downloader.download_segments(segments)
      end

      it 'accepts custom output files for segments' do
        segments = [
          { start: 10, end: 30, output_file: File.join(@test_output_dir, 'seg1.mp4') },
          { start: 60, end: 90, output_file: File.join(@test_output_dir, 'seg2.mp4') }
        ]
        
        output_files = downloader.download_segments(segments)
        
        expect(output_files[0]).to end_with('seg1.mp4')
        expect(output_files[1]).to end_with('seg2.mp4')
      end
    end

    it 'validates segments array' do
      expect {
        downloader.download_segments("not an array")
      }.to raise_error(ArgumentError, /segments must be an Array/)
    end

    it 'validates segments array is not empty' do
      expect {
        downloader.download_segments([])
      }.to raise_error(ArgumentError, /segments array cannot be empty/)
    end

    it 'validates each segment has start and end' do
      segments = [
        { start: 10 }  # missing end
      ]
      
      expect {
        downloader.download_segments(segments)
      }.to raise_error(ArgumentError, /must be a Hash with :start and :end keys/)
    end

    it 'validates segment durations' do
      segments = [
        { start: 10, end: 30 },  # valid
        { start: 60, end: 65 }   # invalid (5 seconds, below default minimum)
      ]
      
      expect {
        downloader.download_segments(segments)
      }.to raise_error(ArgumentError, /Segment 1.*between 10 and 60 seconds/)
    end

    it 'validates start time less than end time' do
      segments = [
        { start: 30, end: 10 }  # invalid
      ]
      
      expect {
        downloader.download_segments(segments)
      }.to raise_error(ArgumentError, /Segment 0.*start time must be less than end time/)
    end

    context 'with caching enabled' do
      before do
        allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
        allow_any_instance_of(described_class).to receive(:ffmpeg_available?).and_return(true)
        allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
      end

      it 'downloads full video once via yt-dlp and caches it' do
        cache_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          cache_full_video: true
        )
        dl = described_class.new(test_url, cache_options)
        
        mock_ytdlp(video_data)
        
        # Mock yt-dlp download
        allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download) do |_, url, output_path|
          FileUtils.touch(output_path)
          output_path
        end
        
        segments = [
          { start: 10, end: 30 },
          { start: 60, end: 90 }
        ]
        
        dl.download_segments(segments)
        
        # Verify cache file exists after download
        cache_files = Dir.glob(File.join(@test_output_dir, '.cache_*'))
        expect(cache_files).not_to be_empty
      end

      it 'cleans up cache when disabled' do
        no_cache_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          cache_full_video: false
        )
        dl = described_class.new(test_url, no_cache_options)
        
        mock_ytdlp(video_data)
        
        # Mock yt-dlp download
        allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download) do |_, url, output_path|
          FileUtils.touch(output_path)
          output_path
        end
        
        segments = [
          { start: 10, end: 30 },
          { start: 60, end: 90 }
        ]
        
        dl.download_segments(segments)
        
        # Verify cache file is deleted
        cache_files = Dir.glob(File.join(@test_output_dir, '.cache_*'))
        expect(cache_files).to be_empty
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
      
      mock_ytdlp(video_data)
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
      
      mock_ytdlp(video_data)
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


    describe '#valid_segment_duration?' do
      it 'returns true for 10 seconds (default minimum)' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 10)).to be true
      end

      it 'returns true for 60 seconds (default maximum)' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 60)).to be true
      end

      it 'returns true for duration in range' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 35)).to be true
      end

      it 'returns false for less than 10 seconds (default minimum)' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 9)).to be false
      end

      it 'returns false for more than 60 seconds (default maximum)' do
        dl = downloader
        expect(dl.send(:valid_segment_duration?, 61)).to be false
      end

      it 'uses custom min/max duration when configured' do
        custom_options = YoutubeRb::Options.new(
          output_path: @test_output_dir,
          min_segment_duration: 5,
          max_segment_duration: 120
        )
        dl = described_class.new(test_url, custom_options)
        
        mock_ytdlp(video_data)
        
        expect(dl.send(:valid_segment_duration?, 5)).to be true   # custom minimum
        expect(dl.send(:valid_segment_duration?, 120)).to be true # custom maximum
        expect(dl.send(:valid_segment_duration?, 4)).to be false  # below custom minimum
        expect(dl.send(:valid_segment_duration?, 121)).to be false # above custom maximum
      end
    end
  end
end
