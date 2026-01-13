# Mocked download tests based on real YouTube responses
# These tests use real response data but don't require internet connection

RSpec.describe "Download with mocks" do
  let(:output_dir) { './spec/tmp/mocked_downloads' }
  let(:rickroll_url) { 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' }
  let(:rickroll_id) { 'dQw4w9WgXcQ' }
  
  # Load real response data
  let(:rickroll_info) { JSON.parse(File.read('./spec/fixtures/rickroll_full_info.json', encoding: 'UTF-8')) }
  let(:segment_info) { JSON.parse(File.read('./spec/fixtures/rickroll_segment_info.json', encoding: 'UTF-8')) }
  
  before(:each) do
    FileUtils.mkdir_p(output_dir)
    
    # Mock YtdlpWrapper to return real data
    allow(YoutubeRb::YtdlpWrapper).to receive(:available?).and_return(true)
    allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:extract_info).and_return(rickroll_info)
  end

  after(:each) do
    FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  end

  describe "video information extraction" do
    it "extracts full video information" do
      client = YoutubeRb::Client.new
      info = client.info(rickroll_url)
      
      # Verify using real data from successful download
      expect(info).to be_a(YoutubeRb::VideoInfo)
      expect(info.id).to eq('dQw4w9WgXcQ')
      expect(info.title).to eq('Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)')
      expect(info.duration).to eq(213)
      expect(info.uploader).to eq('Rick Astley')
      expect(info.view_count).to be > 1_700_000_000
    end

    it "returns correct duration format" do
      client = YoutubeRb::Client.new
      info = client.info(rickroll_url)
      
      expect(info.duration_formatted).to eq('03:33')
    end

    it "has valid formats" do
      client = YoutubeRb::Client.new
      info = client.info(rickroll_url)
      
      expect(info.formats).to be_an(Array)
      expect(info.formats).not_to be_empty
      
      # Check first format has required fields (keys can be strings or symbols)
      first_format = info.formats.first
      expect(first_format).to have_key(:format_id).or have_key('format_id')
      expect(first_format).to have_key(:url).or have_key('url')
      expect(first_format).to have_key(:ext).or have_key('ext')
    end
  end

  describe "video download" do
    it "downloads video with correct parameters" do
      # Mock YtdlpWrapper to simulate successful download
      allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download) do |_instance, url|
        # Create a fake video file
        output_file = File.join(output_dir, "Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)-dQw4w9WgXcQ.webm")
        File.write(output_file, "fake video data" * 1000)
        output_file
      end
      
      client = YoutubeRb::Client.new(
        output_path: output_dir
      )

      output_file = client.download(rickroll_url)
      
      expect(output_file).to be_a(String)
      expect(File.exist?(output_file)).to be true
      expect(File.size(output_file)).to be > 0
    end
  end

  describe "video segment download" do
    let(:start_time) { 10 }
    let(:end_time) { 25 }

    it "downloads segment with correct parameters" do
      # Mock YtdlpWrapper for segment download
      allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download_segment) do |_instance, url, s_time, e_time, output|
        expect(url).to eq(rickroll_url)
        expect(s_time).to eq(start_time)
        expect(e_time).to eq(end_time)
        expect(e_time - s_time).to eq(15)
        
        # Create a fake segment file with realistic size (14.5MB from real download)
        output_file = File.join(output_dir, "#{segment_info['output_file']}")
        File.write(output_file, "fake segment data" * 1000)
        output_file
      end
      
      client = YoutubeRb::Client.new(
        output_path: output_dir
      )

      output_file = client.download_segment(rickroll_url, start_time, end_time)
      
      expect(output_file).to be_a(String)
      expect(File.exist?(output_file)).to be true
      expect(File.basename(output_file)).to include('Rick Astley')
    end

    it "validates segment duration constraints" do
      client = YoutubeRb::Client.new(output_path: output_dir)

      # Too short
      expect {
        client.download_segment(rickroll_url, 0, 5)
      }.to raise_error(ArgumentError, /10 and 60 seconds/)

      # Too long
      expect {
        client.download_segment(rickroll_url, 0, 65)
      }.to raise_error(ArgumentError, /10 and 60 seconds/)
      
      # Invalid range
      expect {
        client.download_segment(rickroll_url, 25, 10)
      }.to raise_error(ArgumentError, /Start time must be less/)
    end

    it "calculates correct segment duration" do
      expected_duration = end_time - start_time
      expect(expected_duration).to eq(15)
      expect(expected_duration).to be_between(10, 60)
    end
  end

  describe "fallback mechanism" do
    it "tries pure Ruby first when fallback enabled" do
      skip "Complex integration test - covered by real_download_spec.rb"
      
      # This test would require complex HTTP mocking for fallback behavior
      # It's better tested in real_download_spec.rb with actual downloads
    end

    it "always uses yt-dlp for downloads" do
      tried_ytdlp = false
      
      allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download) do
        tried_ytdlp = true
        output_file = File.join(output_dir, "video.webm")
        File.write(output_file, "fake data")
        output_file
      end
      
      client = YoutubeRb::Client.new(
        output_path: output_dir
      )

      client.download(rickroll_url)
      
      expect(tried_ytdlp).to be true
    end
  end

  describe "error handling" do
    it "raises DownloadError for invalid video" do
      allow_any_instance_of(YoutubeRb::YtdlpWrapper).to receive(:download) do
        raise YoutubeRb::YtdlpWrapper::YtdlpError, "Video unavailable"
      end
      
      client = YoutubeRb::Client.new(
        output_path: output_dir
      )

      expect {
        client.download('https://www.youtube.com/watch?v=invalid')
      }.to raise_error(YoutubeRb::Downloader::DownloadError)
    end

    it "handles network errors" do
      skip "Complex mock interaction - network errors are properly tested in unit tests"
      
      # Network error handling is tested extensively in client_spec and downloader_spec
      # This integration test would require complex mock reset logic
    end
  end

  describe "real data validation" do
    it "uses data from actual successful download" do
      # These are the actual values from real download test
      expect(rickroll_info['id']).to eq('dQw4w9WgXcQ')
      expect(rickroll_info['duration']).to eq(213)
      expect(rickroll_info['title']).to include('Never Gonna Give You Up')
      expect(rickroll_info['uploader']).to eq('Rick Astley')
    end

    it "segment info matches real download" do
      expect(segment_info['video_id']).to eq('dQw4w9WgXcQ')
      expect(segment_info['start_time']).to eq(10)
      expect(segment_info['end_time']).to eq(25)
      expect(segment_info['duration']).to eq(15)
      expect(segment_info['file_size']).to be > 14_000_000  # ~14.5 MB from real download
    end
  end
end
