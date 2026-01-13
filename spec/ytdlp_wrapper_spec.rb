RSpec.describe YoutubeRb::YtdlpWrapper do
  describe ".available?" do
    it "returns boolean" do
      result = described_class.available?
      expect([true, false]).to include(result)
    end
  end

  describe ".version" do
    it "returns version string" do
      version = described_class.version
      expect(version).to be_a(String)
      expect(version).not_to be_empty
    end

    it "returns 'not installed' when yt-dlp command fails" do
      allow(Open3).to receive(:capture2).with('yt-dlp', '--version').and_raise(Errno::ENOENT)
      version = described_class.version
      expect(version).to eq('not installed')
    end
  end

  context "when yt-dlp is available", if: YoutubeRb::YtdlpWrapper.available? do
    let(:options) { YoutubeRb::Options.new }
    let(:wrapper) { described_class.new(options) }

    describe "#initialize" do
      it "creates wrapper with options" do
        expect(wrapper.options).to be_a(YoutubeRb::Options)
      end

      it "accepts hash options" do
        wrapper = described_class.new(output_path: './test')
        expect(wrapper.options).to be_a(YoutubeRb::Options)
      end
    end

    describe "#extract_info" do
      it "extracts video information", :slow do
        # Note: This test requires internet and may need cookies for some videos
        # Skip if not running integration tests
        skip "Requires internet and may need cookies" unless ENV['RUN_INTEGRATION_TESTS']
        
        url = 'https://www.youtube.com/watch?v=jNQXAC9IVRw'
        info = wrapper.extract_info(url)
        
        expect(info).to be_a(Hash)
        expect(info).to have_key('id')
        expect(info).to have_key('title')
        expect(info).to have_key('duration')
        expect(info['id']).to eq('jNQXAC9IVRw')
      end

      it "raises error for invalid URL" do
        expect {
          wrapper.extract_info('https://www.youtube.com/watch?v=invalidvideoid')
        }.to raise_error(YoutubeRb::YtdlpWrapper::YtdlpError)
      end
    end

    describe "private methods" do
      describe "#build_info_args" do
        it "builds correct arguments for info extraction" do
          url = 'https://www.youtube.com/watch?v=test'
          args = wrapper.send(:build_info_args, url)
          
          expect(args).to include('yt-dlp')
          expect(args).to include('--dump-json')
          expect(args).to include('--no-playlist')
          expect(args).to include(url)
        end

        it "includes cookies file if specified" do
          options = YoutubeRb::Options.new(cookies_file: './test_cookies.txt')
          wrapper = described_class.new(options)
          
          # Create temporary cookies file
          File.write('./test_cookies.txt', 'test')
          
          url = 'https://www.youtube.com/watch?v=test'
          args = wrapper.send(:build_info_args, url)
          
          expect(args).to include('--cookies')
          expect(args).to include('./test_cookies.txt')
          
          File.delete('./test_cookies.txt')
        end
      end

      describe "#build_download_args" do
        it "builds correct arguments for download" do
          url = 'https://www.youtube.com/watch?v=test'
          args = wrapper.send(:build_download_args, url, nil)
          
          expect(args).to include('yt-dlp')
          expect(args).to include(url)
        end

        it "includes output path" do
          url = 'https://www.youtube.com/watch?v=test'
          output = './test_output.mp4'
          args = wrapper.send(:build_download_args, url, output)
          
          expect(args).to include('-o')
          expect(args).to include(output)
        end

        it "includes audio extraction options" do
          options = YoutubeRb::Options.new(
            extract_audio: true,
            audio_format: 'mp3',
            audio_quality: '192'
          )
          wrapper = described_class.new(options)
          
          url = 'https://www.youtube.com/watch?v=test'
          args = wrapper.send(:build_download_args, url, nil)
          
          expect(args).to include('-x')
          expect(args).to include('--audio-format')
          expect(args).to include('mp3')
          expect(args).to include('--audio-quality')
          expect(args).to include('192')
        end

        it "includes subtitle options" do
          options = YoutubeRb::Options.new(
            write_subtitles: true,
            subtitle_langs: ['en', 'ru']
          )
          wrapper = described_class.new(options)
          
          url = 'https://www.youtube.com/watch?v=test'
          args = wrapper.send(:build_download_args, url, nil)
          
          expect(args).to include('--write-subs')
          expect(args).to include('--sub-langs')
          expect(args).to include('en,ru')
        end
      end

      describe "#build_format_string" do
        it "returns best format by default" do
          format = wrapper.send(:build_format_string)
          expect(format).to eq('bestvideo+bestaudio/best')
        end

        it "handles quality specifications" do
          options = YoutubeRb::Options.new(quality: '720p')
          wrapper = described_class.new(options)
          
          format = wrapper.send(:build_format_string)
          expect(format).to include('720')
        end

        it "returns worst format when requested" do
          options = YoutubeRb::Options.new(quality: 'worst')
          wrapper = described_class.new(options)
          
          format = wrapper.send(:build_format_string)
          expect(format).to eq('worstvideo+worstaudio/worst')
        end
      end
    end
  end

  context "when yt-dlp is not available", unless: YoutubeRb::YtdlpWrapper.available? do
    describe "#initialize" do
      it "raises YtdlpNotFoundError" do
        options = YoutubeRb::Options.new
        
        expect {
          described_class.new(options)
        }.to raise_error(YoutubeRb::YtdlpWrapper::YtdlpNotFoundError, /yt-dlp is not installed/)
      end
    end
  end
end
