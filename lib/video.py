from pathlib import Path

from pytube import YouTube
from pydub import AudioSegment
import urllib
import eyed3

from . import utils

eyed3.log.setLevel("ERROR")


def process_video(song_url, thumbnail_img_url, artist_name,
                  album_title, output_path, pbar):
    try:
        video_title = download_video(video_url=song_url,
                                     artist_name=artist_name.lower(),
                                     output_path=output_path)
        convert_video_to_audio(
            video_title=video_title, output_path=output_path)
        attach_metadata(video_title,
                        thumbnail_img_url, artist_name, album_title,
                        video_title, output_path)
        pbar.update(1)
    except Exception as e:
        print(f"Error processing {song_url}: {e}")
        raise e


def download_video(video_url, artist_name, output_path='.'):
    try:
        yt = YouTube(video_url)
        video_stream = yt.streams.get_highest_resolution()
        video_title = utils.sanitize_filename(
            yt.title, extra_keywords=artist_name.lower().split(' '))
        video_stream.download(output_path, filename=f'{video_title}.mp4')
    except Exception as e:
        print(f'Error downloading video: {e}')
        raise e
    return video_title


def convert_video_to_audio(video_title, output_path,
                           input_format='mp4', output_format='mp3'):
    try:
        source_path = Path(output_path) / f'{video_title}.{input_format}'
        dest_path = Path(output_path) / f'{video_title}.{output_format}'
        audio = AudioSegment.from_file(source_path, format=input_format)
        audio.export(dest_path, codec=output_format)
    except Exception as e:
        print(f'Error converting video format: {e}')
        raise e


def attach_metadata(
    video_title, thumbnail_img_url, artist_name, album_title, title,
        output_path):
    try:
        audiofile = eyed3.load(Path(output_path) / f'{video_title}.mp3')
        response = urllib.request.urlopen(thumbnail_img_url)
        imagedata = response.read()

        audiofile.tag.artist = artist_name
        audiofile.tag.album_artist = artist_name
        audiofile.tag.title = title
        audiofile.tag.album = album_title
        audiofile.tag.images.set(3, imagedata, "image/jpeg", u"cover")
        audiofile.tag.save()
    except Exception as e:
        print(f'Error attaching metadata: {e}')
        raise e
