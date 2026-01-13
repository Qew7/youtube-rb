# Integration tests for yt-dlp backend
# These tests require yt-dlp to be installed and an internet connection
# Run with: bundle exec rspec spec/integration --tag integration

RSpec.describe "YoutubeRb + yt-dlp Integration", :integration do
  # Test URL - Rick Astley (public domain, always available)
  let(:test_url) { 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' }
  let(:test_video_id) { 'dQw4w9WgXcQ' }

  before(:all) do
    @client = YoutubeRb::Client.new
    @deps = @client.check_dependencies
    
    unless @deps[:ytdlp]
      skip "yt-dlp is not installed. Install with: pip install -U yt-dlp"
    end
  end

  describe "dependency check" do
    it "detects yt-dlp installation" do
      expect(@deps[:ytdlp]).to be true
      expect(@deps[:ytdlp_version]).to be_a(String)
      expect(@deps[:ytdlp_version]).not_to eq('not installed')
    end

    it "reports yt-dlp version" do
      expect(@deps[:ytdlp_version]).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe "video information extraction" do
    it "extracts video info using default client" do
      info = YoutubeRb.info(test_url)
      
      expect(info).to be_a(YoutubeRb::VideoInfo)
      expect(info.id).to eq(test_video_id)
      expect(info.title).to include('Rick Astley')
      expect(info.duration).to be > 0
      expect(info.uploader).not_to be_nil
    end

    it "extracts info with yt-dlp wrapper directly" do
      wrapper = YoutubeRb::YtdlpWrapper.new
      info = wrapper.extract_info(test_url)
      
      expect(info).to be_a(Hash)
      expect(info['id']).to eq(test_video_id)
      expect(info['title']).to be_a(String)
      expect(info['duration']).to be_a(Integer)
    end
  end

  describe "client configuration" do
    it "creates client with verbose mode" do
      client = YoutubeRb::Client.new(verbose: true)
      expect(client.options.verbose).to be true
    end
  end

  describe "YtdlpWrapper availability" do
    it "reports availability correctly" do
      expect(YoutubeRb::YtdlpWrapper.available?).to be true
    end

    it "returns version string" do
      version = YoutubeRb::YtdlpWrapper.version
      expect(version).to be_a(String)
      expect(version).not_to be_empty
      expect(version).not_to eq('not installed')
    end
  end

  describe "download with yt-dlp (slow)", :slow do
    let(:output_dir) { './spec/tmp/downloads' }

    before(:each) do
      FileUtils.mkdir_p(output_dir)
    end

    after(:each) do
      FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
    end

    it "downloads video segment using yt-dlp backend" do
      client = YoutubeRb::Client.new(
        output_path: output_dir,
        verbose: false
      )

      # Download just the first 10 seconds to speed up test
      output_file = client.download_segment(test_url, 0, 10)
      
      expect(output_file).to be_a(String)
      expect(File.exist?(output_file)).to be true
      expect(File.size(output_file)).to be > 0
    end
  end
end
