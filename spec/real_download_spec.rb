# Real download tests - require internet connection and yt-dlp
# Run with: bundle exec rspec spec/real_download_spec.rb --tag real_download
# These tests actually download videos from YouTube

RSpec.describe "Real video downloads", :real_download do
  let(:output_dir) { './spec/tmp/real_downloads' }
  
  before(:all) do
    # Allow real HTTP connections for these tests
    WebMock.allow_net_connect!
    
    # Check if yt-dlp is available
    unless YoutubeRb::YtdlpWrapper.available?
      skip "yt-dlp is not installed. Install with: pip install -U yt-dlp"
    end
  end

  after(:all) do
    # Restore WebMock behavior
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  before(:each) do
    FileUtils.mkdir_p(output_dir)
  end

  after(:each) do
    # Clean up downloaded files
    FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  end

  describe "Rick Astley - Never Gonna Give You Up" do
    # Rick Astley video works without cookies
    let(:rickroll_url) { 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' }
    let(:rickroll_id) { 'dQw4w9WgXcQ' }

    it "extracts full video information" do
      puts "\n  → Testing video info extraction for Rick Astley"
      
      info = YoutubeRb.info(rickroll_url)
      
      expect(info).to be_a(YoutubeRb::VideoInfo)
      expect(info.id).to eq(rickroll_id)
      expect(info.title).to include('Never Gonna Give You Up')
      expect(info.duration).to eq(213)
      expect(info.uploader).to eq('Rick Astley')
      
      puts "  ✓ Title: #{info.title}"
      puts "  ✓ Duration: #{info.duration} seconds"
      puts "  ✓ Uploader: #{info.uploader}"
      
      # Save the response for mocking later
      File.write('./spec/fixtures/rickroll_full_info.json', JSON.pretty_generate(info.to_h))
      puts "  ✓ Saved response to spec/fixtures/rickroll_full_info.json for mocking"
    end

    it "downloads 15-second segment from 10 to 25 seconds" do
      puts "\n  → Testing segment download: Rick Astley (10-25 sec)"
      puts "  → This will download ~14MB of video segment..."
      
      start_time = 10
      end_time = 25
      
      client = YoutubeRb::Client.new(
        output_path: output_dir,
        verbose: true
      )

      output_file = client.download_segment(rickroll_url, start_time, end_time)
      
      # Verify download
      expect(output_file).to be_a(String)
      expect(File.exist?(output_file)).to be true
      expect(File.size(output_file)).to be > 50_000  # At least 50KB for 15 sec
      
      # Verify segment duration using ffprobe if available
      if system('which ffprobe > /dev/null 2>&1')
        duration_cmd = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 '#{output_file}'"
        duration = `#{duration_cmd}`.strip.to_f
        
        # Duration should be approximately 15 seconds (allow generous variance)
        # NOTE: Without re-encoding (--force-keyframes-at-cuts), yt-dlp cuts at keyframes only,
        # which can result in segments being a few seconds longer than requested.
        # This is acceptable for performance reasons - cutting at keyframes is 10x faster.
        # Expected: 15 seconds, but may be 20-30 seconds due to keyframe positions.
        expect(duration).to be_between(10, 30)
        puts "  ✓ Segment duration: #{duration.round(1)} seconds (requested: 15s)"
      end
      
      puts "  ✓ Downloaded to: #{output_file}"
      puts "  ✓ File size: #{(File.size(output_file) / 1024.0).round(2)} KB"
      
      # Save info about what we downloaded for mocking
      segment_info = {
        url: rickroll_url,
        video_id: rickroll_id,
        start_time: start_time,
        end_time: end_time,
        duration: end_time - start_time,
        file_size: File.size(output_file),
        output_file: File.basename(output_file)
      }
      File.write('./spec/fixtures/rickroll_segment_info.json', JSON.pretty_generate(segment_info))
      puts "  ✓ Saved segment info to spec/fixtures/rickroll_segment_info.json"
    end

    it "downloads full video using yt-dlp backend", :very_slow do
      puts "\n  → Testing full video download: Rick Astley (dQw4w9WgXcQ)"
      puts "  → This will download ~240MB of video data..."
      puts "  → This may take a few minutes depending on your connection..."
      
      client = YoutubeRb::Client.new(
        output_path: output_dir,
        verbose: true
      )

      output_file = client.download(rickroll_url)
      
      # Verify download
      expect(output_file).to be_a(String)
      expect(File.exist?(output_file)).to be true
      expect(File.size(output_file)).to be > 10_000_000  # At least 10MB
      
      puts "  ✓ Downloaded to: #{output_file}"
      puts "  ✓ File size: #{(File.size(output_file) / 1024.0 / 1024.0).round(2)} MB"
    end
  end

  describe "error handling" do
    it "raises error for invalid video ID" do
      puts "\n  → Testing error handling for invalid video"
      
      client = YoutubeRb::Client.new(
        output_path: output_dir
      )

      invalid_url = 'https://www.youtube.com/watch?v=invalidvideoid'
      
      expect {
        client.download(invalid_url)
      }.to raise_error(YoutubeRb::Downloader::DownloadError)
      
      puts "  ✓ Correctly raised error for invalid video"
    end
  end
end
