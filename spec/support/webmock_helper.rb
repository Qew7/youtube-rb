module WebmockHelper
  # Stub YouTube page request
  def stub_youtube_page(video_id, video_data)
    # Stub the main video page
    url = "https://www.youtube.com/watch?v=#{video_id}"
    
    # Also stub various YouTube URL formats
    stub_youtube_url_variant("https://www.youtube.com/watch?v=#{video_id}", video_id, video_data)
    stub_youtube_url_variant("https://youtu.be/#{video_id}", video_id, video_data)
    stub_youtube_url_variant("https://www.youtube.com/embed/#{video_id}", video_id, video_data)
  end

  def stub_youtube_url_variant(url, video_id, video_data)
    # Create a fake YouTube page HTML with player response
    player_response = {
      'videoDetails' => {
        'videoId' => video_data['id'],
        'title' => video_data['title'],
        'shortDescription' => video_data['description'],
        'lengthSeconds' => video_data['duration'].to_s,
        'viewCount' => video_data['view_count'].to_s,
        'author' => video_data['uploader'],
        'channelId' => video_data['uploader_id']
      },
      'streamingData' => {
        'formats' => video_data['formats'].map { |f| format_to_player_format(f) }
      },
      'captions' => {
        'playerCaptionsTracklistRenderer' => {
          'captionTracks' => subtitles_to_caption_tracks(video_data['subtitles'])
        }
      },
      'microformat' => {
        'playerMicroformatRenderer' => {
          'title' => video_data['title'],
          'description' => video_data['description'],
          'uploadDate' => format_upload_date(video_data['upload_date']),
          'ownerChannelName' => video_data['uploader'],
          'externalChannelId' => video_data['uploader_id'],
          'thumbnail' => {
            'thumbnails' => [
              { 'url' => video_data['thumbnail'] }
            ]
          }
        }
      }
    }

    html = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>#{video_data['title']}</title></head>
      <body>
        <script>
          var ytInitialPlayerResponse = #{player_response.to_json};
        </script>
      </body>
      </html>
    HTML

    stub_request(:get, url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })
  end

  # Stub video download
  def stub_video_download(url, content = nil)
    content ||= sample_video_binary
    
    # Stub both with and without Range header
    stub_request(:get, url)
      .to_return(status: 200, body: content, headers: { 'Content-Type' => 'video/mp4' })
    
    # Also stub all example.com video URLs
    stub_request(:get, /example\.com\/video.*\.mp4/)
      .to_return(status: 200, body: content, headers: { 'Content-Type' => 'video/mp4' })
  end

  # Stub subtitle download
  def stub_subtitle_download(url, content = nil)
    content ||= sample_subtitle_vtt
    
    stub_request(:get, url)
      .to_return(status: 200, body: content, headers: { 'Content-Type' => 'text/vtt' })
  end

  # Stub thumbnail download
  def stub_thumbnail_download(url, content = nil)
    content ||= "\xFF\xD8\xFF\xE0" # JPEG header
    
    stub_request(:get, url)
      .to_return(status: 200, body: content, headers: { 'Content-Type' => 'image/jpeg' })
  end

  private

  def format_to_player_format(format)
    {
      'itag' => format['format_id'].to_i,
      'url' => format['url'],
      'mimeType' => "video/#{format['ext']}; codecs=\"#{format['vcodec']}, #{format['acodec']}\"",
      'width' => format['width'],
      'height' => format['height'],
      'quality' => format['quality'],
      'qualityLabel' => "#{format['height']}p",
      'bitrate' => format['tbr'] ? format['tbr'] * 1000 : nil
    }
  end

  def subtitles_to_caption_tracks(subtitles)
    return [] unless subtitles

    subtitles.flat_map do |lang, subs|
      subs.map do |sub|
        {
          'languageCode' => lang,
          'baseUrl' => sub['url'],
          'name' => { 'simpleText' => sub['name'] }
        }
      end
    end
  end

  def format_upload_date(date_str)
    return nil unless date_str
    # Convert YYYYMMDD to YYYY-MM-DD
    "#{date_str[0..3]}-#{date_str[4..5]}-#{date_str[6..7]}"
  end
end

RSpec.configure do |config|
  config.include WebmockHelper
end
