module YoutubeRb
  class VideoInfo
    attr_reader :id, :title, :description, :uploader, :uploader_id,
                :duration, :view_count, :like_count, :upload_date,
                :thumbnail, :formats, :subtitles, :url, :ext,
                :webpage_url, :fulltitle

    def initialize(data)
      @id = data['id'] || data[:id]
      @title = data['title'] || data[:title]
      @fulltitle = data['fulltitle'] || data[:fulltitle] || @title
      @description = data['description'] || data[:description]
      @uploader = data['uploader'] || data[:uploader]
      @uploader_id = data['uploader_id'] || data[:uploader_id]
      @duration = parse_duration(data['duration'] || data[:duration])
      @view_count = data['view_count'] || data[:view_count]
      @like_count = data['like_count'] || data[:like_count]
      @upload_date = data['upload_date'] || data[:upload_date]
      @thumbnail = data['thumbnail'] || data[:thumbnail]
      @formats = parse_formats(data['formats'] || data[:formats] || [])
      @subtitles = parse_subtitles(data['subtitles'] || data[:subtitles] || {})
      @url = data['url'] || data[:url]
      @ext = data['ext'] || data[:ext]
      @webpage_url = data['webpage_url'] || data[:webpage_url]
    end

    def available_formats
      @formats.map { |f| f[:format_id] }
    end

    def available_qualities
      @formats.map { |f| f[:quality] }.uniq.compact
    end

    def available_subtitle_languages
      @subtitles.keys
    end

    def best_format
      @formats.max_by { |f| format_priority(f) }
    end

    def worst_format
      @formats.min_by { |f| format_priority(f) }
    end

    def best_video_format
      video_formats.max_by { |f| format_priority(f) }
    end

    def best_audio_format
      audio_formats.max_by { |f| format_priority(f) }
    end

    def video_formats
      @formats.select { |f| f[:vcodec] && f[:vcodec] != 'none' }
    end

    def audio_formats
      @formats.select { |f| f[:acodec] && f[:acodec] != 'none' }
    end

    def get_format(format_id)
      @formats.find { |f| f[:format_id] == format_id }
    end

    def get_subtitle(lang)
      @subtitles[lang]
    end

    def duration_in_seconds
      @duration
    end

    def duration_formatted
      return nil unless @duration
      
      hours = @duration / 3600
      minutes = (@duration % 3600) / 60
      seconds = @duration % 60

      if hours > 0
        format("%02d:%02d:%02d", hours, minutes, seconds)
      else
        format("%02d:%02d", minutes, seconds)
      end
    end

    def to_h
      {
        id: @id,
        title: @title,
        fulltitle: @fulltitle,
        description: @description,
        uploader: @uploader,
        uploader_id: @uploader_id,
        duration: @duration,
        duration_formatted: duration_formatted,
        view_count: @view_count,
        like_count: @like_count,
        upload_date: @upload_date,
        thumbnail: @thumbnail,
        formats: @formats,
        subtitles: @subtitles,
        url: @url,
        ext: @ext,
        webpage_url: @webpage_url
      }
    end

    private

    def parse_duration(duration)
      return nil unless duration
      duration.is_a?(Numeric) ? duration.to_i : duration.to_s.to_i
    end

    def parse_formats(formats_data)
      return [] unless formats_data.is_a?(Array)

      formats_data.map do |format|
        {
          format_id: format['format_id'] || format[:format_id],
          format_note: format['format_note'] || format[:format_note],
          ext: format['ext'] || format[:ext],
          url: format['url'] || format[:url],
          width: format['width'] || format[:width],
          height: format['height'] || format[:height],
          fps: format['fps'] || format[:fps],
          vcodec: format['vcodec'] || format[:vcodec],
          acodec: format['acodec'] || format[:acodec],
          tbr: format['tbr'] || format[:tbr],
          abr: format['abr'] || format[:abr],
          vbr: format['vbr'] || format[:vbr],
          filesize: format['filesize'] || format[:filesize],
          quality: format['quality'] || format[:quality],
          protocol: format['protocol'] || format[:protocol]
        }
      end
    end

    def parse_subtitles(subtitles_data)
      return {} unless subtitles_data.is_a?(Hash)

      subtitles_data.transform_values do |subtitle_formats|
        subtitle_formats.map do |sub|
          {
            ext: sub['ext'] || sub[:ext],
            url: sub['url'] || sub[:url],
            name: sub['name'] || sub[:name]
          }
        end
      end
    end

    def format_priority(format)
      # Priority calculation based on multiple factors
      priority = 0
      
      # Video quality
      if format[:height]
        priority += format[:height] * 100
      end
      
      # Bitrate
      if format[:tbr]
        priority += format[:tbr]
      end
      
      # Prefer certain codecs
      if format[:vcodec]
        priority += 10 if format[:vcodec].include?('avc')
        priority += 5 if format[:vcodec].include?('vp9')
      end
      
      priority
    end
  end
end
