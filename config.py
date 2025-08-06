import os

# Application configuration
DEBUG = True
SECRET_KEY = os.environ.get("SESSION_SECRET", "dev-secret-key-change-in-production")

# Upload configuration
UPLOAD_FOLDER = os.environ.get("UPLOAD_FOLDER", os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads"))
THUMBNAIL_FOLDER = os.path.join(UPLOAD_FOLDER, "thumbnails")
MAX_CONTENT_LENGTH = 1024 * 1024 * 1024  # 1GB

# Allowed file extensions
ALLOWED_VIDEO_EXTENSIONS = {'mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv', 'm4v', 'mpg', 'mpeg', '3gp', '3g2', 'mxf', 'ts', 'mts', 'h264', 'h265', 'hevc', 'divx', 'f4v'}
ALLOWED_AUDIO_EXTENSIONS = {'mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac', 'opus', 'wma', 'alac', 'ape', 'ac3', 'dts', 'mid', 'midi', 'aiff', 'aif'}
ALLOWED_EXTENSIONS = ALLOWED_VIDEO_EXTENSIONS.union(ALLOWED_AUDIO_EXTENSIONS)

# FFmpeg configuration
FFMPEG_PATH = os.environ.get("FFMPEG_PATH", "ffmpeg")
FFPROBE_PATH = os.environ.get("FFPROBE_PATH", "ffprobe")

# Thumbnail generation
THUMBNAIL_POSITION = 5  # Position in seconds to take a thumbnail from a video

# Video quality presets for transcoding
VIDEO_QUALITY_PRESETS = {
    'low': {
        'resolution': '640x360',
        'bitrate': '500k',
        'audio_bitrate': '96k'
    },
    'medium': {
        'resolution': '1280x720',
        'bitrate': '1500k',
        'audio_bitrate': '128k'
    },
    'high': {
        'resolution': '1920x1080',
        'bitrate': '3000k',
        'audio_bitrate': '192k'
    }
}

# Default transcoding quality
DEFAULT_QUALITY = 'medium'

# Pagination
ITEMS_PER_PAGE = 12
