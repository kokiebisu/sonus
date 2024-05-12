require 'pathname'

require_relative 'scraper'

def process_media(url, base_path, output_mode, progressbar)
  begin
    scraper = YoutubeScraper.new(url)
    if output_mode == 'music'
      song_title, artist_name, album_name, thumbnail_img_url = scraper.scrape_song
      puts "Extracted song info: #{song_title} #{artist_name} #{album_name} #{thumbnail_img_url}"
      song_title = song_title.tr('/', '-') if song_title
      VideoProcessor.retrieve_song(url, song_title, artist_name, album_name, thumbnail_img_url, base_path)
      output_path = Pathname.new("#{base_path}/#{song_title}.mp3")
    elsif output_mode == 'video'
      # pass
      title = scraper.scrape_video
      puts "Extracted video info: #{title}"
      video_title = video_title.tr('/', '-') if video_title
      VideoProcessor.retrieve_video(url, title, base_path)
    end
    progressbar.increment
    output_path
  rescue => e
    puts "Error processing song #{e}"
  end
end

def process_playlist(playlist_url, base_path, output_mode, progressbar=nil)
  playlist_name, urls = YoutubeScraper.new(playlist_url).scrape_playlist(output_mode)
  output_path = Pathname.new("#{base_path}/#{playlist_name}")
  FileUtils.mkdir(output_path)
  progressbar ||= ProgressBar.create(title: "Processing Playlist", total: urls.length, format: '%a |%b>>%i| %p%% %t')
  urls.each do |url|
    process_media(url, output_path, output_mode, progressbar)
  end
  progressbar.finish unless progressbar.finished?
  return output_path
end

def process_release_albums(release_url, base_path)
  artist_name, playlist_urls = YoutubeScraper.new(release_url).scrape_release
  output_path = Pathname.new("#{base_path}/#{artist_name}")
  FileUtils.mkdir_p(output_path)
  progressbar = ProgressBar.create(title: "Processing Release", total: playlist_urls.length, format: '%a |%b>>%i| %p%% %t')
  max_threads = 4
  pool = Concurrent::FixedThreadPool.new(max_threads)
  playlist_urls.each do |playlist_url|
    pool.post do
      begin
        process_playlist(playlist_url, output_path, 'music', progressbar)
      rescue => e
        puts "Error in processing playlist: #{playlist_url}, Error: #{e}"
      end
    end
  end
  pool.shutdown
  pool.wait_for_termination
  progressbar.finish
  return output_path
end

def process_videos(videos_url, base_path)
  channel_name, video_urls = YoutubeScraper.new(videos_url).scrape_videos
  output_path = Pathname.new("#{base_path}/#{channel_name}")
  FileUtils.mkdir(output_path)
  progressbar ||= ProgressBar.create(title: "Processing Videos", total: video_urls.length, format: '%a |%b>>%i| %p%% %t')
  video_urls.each do |url|
    process_media(url, output_path, 'video', progressbar)
  end
  progressbar.finish unless progressbar.finished?
  return output_path
end

def process_url(url, output_mode)
  path = Utils.get_desktop_folder
  if url.include?('releases')
      output_path = process_release_albums(url, path)
  elsif url.include?('playlist')
    output_path = process_playlist(url, path, output_mode)
  elsif url.include?('videos')
    output_path = process_videos(url, path)
  else
    progressbar = ProgressBar.create(title: "Processing Song", total: 1, format: '%a |%b>>%i| %p%% %t')
    output_path = process_song(url, path, progressbar)
    progressbar.finish
  end
  {
    outputPath: output_path.to_s
  }
end
