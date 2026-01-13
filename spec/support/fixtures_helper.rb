module FixturesHelper
  def fixture_path(filename)
    File.join(__dir__, '..', 'fixtures', filename)
  end

  def load_fixture(filename)
    File.read(fixture_path(filename))
  end

  def load_json_fixture(filename)
    JSON.parse(load_fixture(filename))
  end

  # Real data from rickroll video
  def rickroll_video_info
    @rickroll_video_info ||= load_json_fixture('rickroll_info.json')
  end

  # Sample video data for testing
  def sample_video_data
    {
      'id' => 'test123abc',
      'title' => 'Test Video Title',
      'fulltitle' => 'Test Video Title',
      'description' => 'This is a test video description',
      'uploader' => 'Test Channel',
      'uploader_id' => 'UC1234567890',
      'duration' => 180,
      'view_count' => 1000,
      'like_count' => 50,
      'upload_date' => '20240101',
      'thumbnail' => 'https://example.com/thumbnail.jpg',
      'ext' => 'mp4',
      'webpage_url' => 'https://www.youtube.com/watch?v=test123abc',
      'formats' => [
        {
          'format_id' => '18',
          'ext' => 'mp4',
          'height' => 360,
          'url' => 'https://example.com/video.mp4',
          'vcodec' => 'avc1.42001E',
          'acodec' => 'mp4a.40.2',
          'quality' => 'medium',
          'tbr' => 500
        },
        {
          'format_id' => '22',
          'ext' => 'mp4',
          'height' => 720,
          'url' => 'https://example.com/video-720p.mp4',
          'vcodec' => 'avc1.64001F',
          'acodec' => 'mp4a.40.2',
          'quality' => 'hd720',
          'tbr' => 2000
        }
      ],
      'subtitles' => {
        'en' => [
          {
            'ext' => 'vtt',
            'url' => 'https://example.com/subtitles-en.vtt',
            'name' => 'English'
          }
        ],
        'es' => [
          {
            'ext' => 'vtt',
            'url' => 'https://example.com/subtitles-es.vtt',
            'name' => 'Spanish'
          }
        ]
      }
    }
  end

  # Sample subtitle content (VTT format)
  def sample_subtitle_vtt
    <<~VTT
      WEBVTT

      00:00:00.000 --> 00:00:05.000
      Welcome to this test video

      00:00:05.000 --> 00:00:10.000
      This is a sample subtitle

      00:00:10.000 --> 00:00:15.000
      Testing subtitle trimming

      00:00:15.000 --> 00:00:20.000
      End of subtitle test
    VTT
  end

  # Sample video binary data (minimal MP4 header)
  def sample_video_binary
    # Minimal valid MP4 file (just ftyp box)
    [
      0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
      0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
      0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
      0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31
    ].pack('C*')
  end
end

RSpec.configure do |config|
  config.include FixturesHelper
end
