RSpec.describe YoutubeRb do
  it "has a version number" do
    expect(YoutubeRb::VERSION).not_to be nil
  end

  describe ".new" do
    it "creates a client instance" do
      client = YoutubeRb.new
      expect(client).to be_a(YoutubeRb::Client)
    end

    it "accepts options" do
      client = YoutubeRb.new(output_path: './test')
      expect(client.options.output_path).to eq('./test')
    end
  end

  describe YoutubeRb::Client do
    let(:client) { YoutubeRb::Client.new(output_path: './test_downloads') }

    describe "#initialize" do
      it "creates options from hash" do
        expect(client.options).to be_a(YoutubeRb::Options)
        expect(client.options.output_path).to eq('./test_downloads')
      end
    end

    describe "#check_dependencies" do
      it "returns hash with dependency status" do
        deps = client.check_dependencies
        expect(deps).to be_a(Hash)
        expect(deps).to have_key(:ffmpeg)
        expect(deps).to have_key(:ytdlp)
        expect(deps).to have_key(:ytdlp_version)
      end

      it "checks ffmpeg availability" do
        deps = client.check_dependencies
        expect([true, false]).to include(deps[:ffmpeg])
      end

      it "checks yt-dlp availability" do
        deps = client.check_dependencies
        expect([true, false]).to include(deps[:ytdlp])
      end
    end

    describe "#version" do
      it "returns version string" do
        expect(client.version).to eq(YoutubeRb::VERSION)
      end
    end
  end

  describe YoutubeRb::Options do
    describe "#initialize" do
      it "creates with default options" do
        options = YoutubeRb::Options.new
        expect(options.format).to eq('best')
        expect(options.quality).to eq('best')
        expect(options.output_path).to eq('./downloads')
        expect(options.use_ytdlp).to eq(false)
        expect(options.ytdlp_fallback).to eq(true)
        expect(options.verbose).to eq(false)
      end

      it "creates with custom options" do
        options = YoutubeRb::Options.new(
          format: '1080p',
          output_path: '/tmp',
          write_subtitles: true,
          use_ytdlp: true,
          verbose: true
        )
        expect(options.format).to eq('1080p')
        expect(options.output_path).to eq('/tmp')
        expect(options.write_subtitles).to eq(true)
        expect(options.use_ytdlp).to eq(true)
        expect(options.verbose).to eq(true)
      end
    end

    describe "#to_h" do
      it "returns hash representation" do
        options = YoutubeRb::Options.new(format: 'best', use_ytdlp: true)
        hash = options.to_h
        expect(hash).to be_a(Hash)
        expect(hash[:format]).to eq('best')
        expect(hash[:use_ytdlp]).to eq(true)
        expect(hash).to have_key(:ytdlp_fallback)
        expect(hash).to have_key(:verbose)
      end
    end

    describe "#merge" do
      it "merges options" do
        options = YoutubeRb::Options.new(format: 'best')
        options.merge(format: '720p', quality: 'high')
        expect(options.format).to eq('720p')
        expect(options.quality).to eq('high')
      end
    end
  end

  describe YoutubeRb::VideoInfo do
    let(:video_data) do
      {
        'id' => 'test123',
        'title' => 'Test Video',
        'description' => 'Test description',
        'duration' => 180,
        'view_count' => 1000,
        'formats' => [
          {
            'format_id' => '18',
            'ext' => 'mp4',
            'height' => 360,
            'vcodec' => 'avc1',
            'acodec' => 'mp4a'
          }
        ],
        'subtitles' => {
          'en' => [{ 'ext' => 'srt', 'url' => 'https://example.com/sub.srt' }]
        }
      }
    end

    let(:video_info) { YoutubeRb::VideoInfo.new(video_data) }

    describe "#initialize" do
      it "parses video data" do
        expect(video_info.id).to eq('test123')
        expect(video_info.title).to eq('Test Video')
        expect(video_info.duration).to eq(180)
        expect(video_info.view_count).to eq(1000)
      end
    end

    describe "#duration_formatted" do
      it "formats duration" do
        expect(video_info.duration_formatted).to eq('03:00')
      end

      it "formats duration with hours" do
        info = YoutubeRb::VideoInfo.new('duration' => 3665)
        expect(info.duration_formatted).to eq('01:01:05')
      end
    end

    describe "#available_formats" do
      it "returns format IDs" do
        expect(video_info.available_formats).to eq(['18'])
      end
    end

    describe "#available_subtitle_languages" do
      it "returns subtitle languages" do
        expect(video_info.available_subtitle_languages).to eq(['en'])
      end
    end

    describe "#to_h" do
      it "returns hash representation" do
        hash = video_info.to_h
        expect(hash).to be_a(Hash)
        expect(hash[:id]).to eq('test123')
        expect(hash[:title]).to eq('Test Video')
      end
    end
  end

  describe YoutubeRb::Extractor do
    let(:extractor) { YoutubeRb::Extractor.new('https://www.youtube.com/watch?v=test') }

    describe "#initialize" do
      it "creates extractor with URL" do
        expect(extractor.url).to eq('https://www.youtube.com/watch?v=test')
      end
    end
  end

  describe YoutubeRb::Downloader do
    let(:url) { 'https://www.youtube.com/watch?v=test' }
    let(:options) { YoutubeRb::Options.new(output_path: './test_downloads') }
    let(:downloader) { YoutubeRb::Downloader.new(url, options) }

    describe "#initialize" do
      it "creates downloader with URL and options" do
        expect(downloader.url).to eq(url)
        expect(downloader.options).to be_a(YoutubeRb::Options)
      end

      it "accepts hash options" do
        dl = YoutubeRb::Downloader.new(url, { output_path: './test' })
        expect(dl.options).to be_a(YoutubeRb::Options)
        expect(dl.options.output_path).to eq('./test')
      end
    end
  end
end
