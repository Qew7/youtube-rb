module YoutubeRb
  class Options
    attr_accessor :format, :quality, :output_path, :output_template,
                  :playlist_start, :playlist_end, :playlist_items,
                  :max_downloads, :min_filesize, :max_filesize,
                  :rate_limit, :retries, :buffer_size,
                  :write_subtitles, :write_auto_sub, :subtitle_format, :subtitle_langs,
                  :username, :password, :netrc, :video_password,
                  :cookies_file, :user_agent, :referer,
                  :extract_audio, :audio_format, :audio_quality,
                  :time_range, :start_time, :end_time

    # Filesystem options
    attr_accessor :no_overwrites, :continue_download, :no_part,
                  :write_description, :write_info_json, :write_thumbnail

    # Video selection options
    attr_accessor :match_title, :reject_title, :date, :datebefore, :dateafter,
                  :min_views, :max_views, :no_playlist, :yes_playlist

    def initialize(**options)
      # Video Selection
      @playlist_start = options[:playlist_start]
      @playlist_end = options[:playlist_end]
      @playlist_items = options[:playlist_items]
      @match_title = options[:match_title]
      @reject_title = options[:reject_title]
      @max_downloads = options[:max_downloads]
      @min_filesize = options[:min_filesize]
      @max_filesize = options[:max_filesize]
      @date = options[:date]
      @datebefore = options[:datebefore]
      @dateafter = options[:dateafter]
      @min_views = options[:min_views]
      @max_views = options[:max_views]
      @no_playlist = options.fetch(:no_playlist, false)
      @yes_playlist = options.fetch(:yes_playlist, false)

      # Download Options
      @format = options.fetch(:format, 'best')
      @quality = options.fetch(:quality, 'best')
      @rate_limit = options[:rate_limit]
      @retries = options.fetch(:retries, 10)
      @buffer_size = options.fetch(:buffer_size, 1024)
      @extract_audio = options.fetch(:extract_audio, false)
      @audio_format = options.fetch(:audio_format, 'mp3')
      @audio_quality = options.fetch(:audio_quality, '192')

      # Filesystem Options
      @output_path = options.fetch(:output_path, './downloads')
      @output_template = options.fetch(:output_template, '%(title)s-%(id)s.%(ext)s')
      @no_overwrites = options.fetch(:no_overwrites, false)
      @continue_download = options.fetch(:continue_download, true)
      @no_part = options.fetch(:no_part, false)
      @write_description = options.fetch(:write_description, false)
      @write_info_json = options.fetch(:write_info_json, false)
      @write_thumbnail = options.fetch(:write_thumbnail, false)

      # Subtitle Options
      @write_subtitles = options.fetch(:write_subtitles, false)
      @write_auto_sub = options.fetch(:write_auto_sub, false)
      @subtitle_format = options.fetch(:subtitle_format, 'srt')
      @subtitle_langs = options.fetch(:subtitle_langs, ['en'])

      # Authentication Options
      @username = options[:username]
      @password = options[:password]
      @netrc = options[:netrc]
      @video_password = options[:video_password]
      @cookies_file = options[:cookies_file]

      # Network Options
      @user_agent = options[:user_agent]
      @referer = options[:referer]

      # Time range options for video segments
      @time_range = options[:time_range]
      @start_time = options[:start_time]
      @end_time = options[:end_time]
    end

    def to_h
      {
        format: @format,
        quality: @quality,
        output_path: @output_path,
        output_template: @output_template,
        playlist_start: @playlist_start,
        playlist_end: @playlist_end,
        playlist_items: @playlist_items,
        max_downloads: @max_downloads,
        min_filesize: @min_filesize,
        max_filesize: @max_filesize,
        rate_limit: @rate_limit,
        retries: @retries,
        buffer_size: @buffer_size,
        write_subtitles: @write_subtitles,
        write_auto_sub: @write_auto_sub,
        subtitle_format: @subtitle_format,
        subtitle_langs: @subtitle_langs,
        username: @username,
        password: @password,
        netrc: @netrc,
        video_password: @video_password,
        cookies_file: @cookies_file,
        user_agent: @user_agent,
        referer: @referer,
        extract_audio: @extract_audio,
        audio_format: @audio_format,
        audio_quality: @audio_quality,
        time_range: @time_range,
        start_time: @start_time,
        end_time: @end_time,
        no_overwrites: @no_overwrites,
        continue_download: @continue_download,
        no_part: @no_part,
        write_description: @write_description,
        write_info_json: @write_info_json,
        write_thumbnail: @write_thumbnail,
        match_title: @match_title,
        reject_title: @reject_title,
        date: @date,
        datebefore: @datebefore,
        dateafter: @dateafter,
        min_views: @min_views,
        max_views: @max_views,
        no_playlist: @no_playlist,
        yes_playlist: @yes_playlist
      }
    end

    def merge(other_options)
      return self unless other_options

      other_options.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=") && !value.nil?
      end
      self
    end
  end
end
