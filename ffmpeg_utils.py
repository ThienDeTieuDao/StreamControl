import os
import subprocess
import json
import logging
from config import FFMPEG_PATH, FFPROBE_PATH, THUMBNAIL_POSITION, THUMBNAIL_FOLDER

logger = logging.getLogger(__name__)

def get_media_info(file_path):
    """
    Use ffprobe to get media file information.
    
    Returns a dictionary with:
    - duration: in seconds
    - format: container format
    - width and height: for video files
    - bitrate: in kbps
    """
    try:
        # Run ffprobe to get JSON output of media info
        cmd = [
            FFPROBE_PATH,
            '-v', 'quiet',
            '-print_format', 'json',
            '-show_format',
            '-show_streams',
            file_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"Error running ffprobe: {result.stderr}")
            return None
        
        info = json.loads(result.stdout)
        
        # Initialize response object
        media_info = {
            'duration': 0,
            'format': '',
            'width': 0,
            'height': 0,
            'bitrate': 0,
            'filesize': 0
        }
        
        # Extract format information
        if 'format' in info:
            media_info['format'] = info['format'].get('format_name', '').split(',')[0]
            media_info['duration'] = int(float(info['format'].get('duration', 0)))
            media_info['filesize'] = int(info['format'].get('size', 0))
            media_info['bitrate'] = int(info['format'].get('bit_rate', 0)) // 1000  # Convert to kbps
        
        # Extract video stream information if available
        for stream in info.get('streams', []):
            if stream.get('codec_type') == 'video':
                media_info['width'] = stream.get('width', 0)
                media_info['height'] = stream.get('height', 0)
                break
        
        return media_info
    
    except Exception as e:
        logger.error(f"Error retrieving media info: {str(e)}")
        return None

def generate_thumbnail(file_path, media_id):
    """
    Generate a thumbnail from a video file using ffmpeg.
    
    Args:
        file_path: Path to the video file
        media_id: ID of the media record to use for thumbnail naming
    
    Returns:
        Path to the generated thumbnail or None if failed
    """
    thumbnail_filename = f"{media_id}_thumbnail.jpg"
    thumbnail_path = os.path.join(THUMBNAIL_FOLDER, thumbnail_filename)
    
    try:
        # Make sure the thumbnails directory exists
        os.makedirs(THUMBNAIL_FOLDER, exist_ok=True)
        
        # Run ffmpeg to extract a frame at the specified position
        cmd = [
            FFMPEG_PATH,
            '-i', file_path,
            '-ss', str(THUMBNAIL_POSITION),
            '-vframes', '1',
            '-vf', 'scale=640:-1',
            '-q:v', '2',
            thumbnail_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"Error generating thumbnail: {result.stderr}")
            return None
        
        return thumbnail_path
    
    except Exception as e:
        logger.error(f"Exception generating thumbnail: {str(e)}")
        return None

def transcode_media(file_path, output_path, quality_preset="medium"):
    """
    Transcode a media file to a different format or quality.
    
    Args:
        file_path: Path to the source media file
        output_path: Path where the transcoded file should be saved
        quality_preset: Quality preset to use (low, medium, high)
    
    Returns:
        True if transcoding succeeded, False otherwise
    """
    from config import VIDEO_QUALITY_PRESETS
    
    try:
        quality = VIDEO_QUALITY_PRESETS.get(quality_preset, VIDEO_QUALITY_PRESETS['medium'])
        
        # Get media info to determine if it's audio or video
        media_info = get_media_info(file_path)
        
        if not media_info:
            # Try with more aggressive error recovery options
            logger.warning(f"Could not get media info for {file_path}, trying with error recovery")
            return transcode_with_error_recovery(file_path, output_path, quality_preset)
        
        # For video files
        if media_info.get('width', 0) > 0:
            cmd = [
                FFMPEG_PATH,
                '-y',  # Overwrite output file if it exists
                '-err_detect', 'ignore_err',  # Ignore errors
                '-i', file_path,
                '-c:v', 'libx264',  # Use H.264 for maximum compatibility
                '-profile:v', 'main',  # Main profile for better compatibility
                '-pix_fmt', 'yuv420p',  # Standard pixel format for compatibility
                '-preset', 'medium',  # Balance between speed and quality
                '-b:v', quality['bitrate'],
                '-vf', f"scale={quality['resolution']}",
                '-c:a', 'aac',
                '-b:a', quality['audio_bitrate'],
                '-ar', '44100',  # Standard audio sample rate
                '-movflags', '+faststart',  # Web optimization
                output_path
            ]
        # For audio files
        else:
            cmd = [
                FFMPEG_PATH,
                '-y',  # Overwrite output file if it exists
                '-err_detect', 'ignore_err',  # Ignore errors
                '-i', file_path,
                '-c:a', 'aac',
                '-b:a', quality['audio_bitrate'],
                '-ar', '44100',  # Standard audio sample rate
                output_path
            ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"Error transcoding media: {result.stderr}")
            # Try with more aggressive error recovery options
            return transcode_with_error_recovery(file_path, output_path, quality_preset)
        
        return True
    
    except Exception as e:
        logger.error(f"Exception during transcoding: {str(e)}")
        return False

def transcode_with_error_recovery(file_path, output_path, quality_preset="medium"):
    """
    Attempt to transcode a problematic media file with more aggressive error recovery options.
    
    Args:
        file_path: Path to the source media file
        output_path: Path where the transcoded file should be saved
        quality_preset: Quality preset to use (low, medium, high)
    
    Returns:
        True if transcoding succeeded, False otherwise
    """
    from config import VIDEO_QUALITY_PRESETS
    
    try:
        quality = VIDEO_QUALITY_PRESETS.get(quality_preset, VIDEO_QUALITY_PRESETS['medium'])
        
        # Try to determine if it's audio or video based on file extension
        file_ext = os.path.splitext(file_path)[1].lower()
        
        # Common video extensions
        video_exts = {'.mp4', '.avi', '.mkv', '.mov', '.webm', '.flv', '.wmv', '.m4v', '.mpg', '.mpeg', '.ts', '.mts'}
        is_video = file_ext in video_exts
        
        # Use more aggressive error recovery flags
        if is_video:
            cmd = [
                FFMPEG_PATH,
                '-y',  # Overwrite output file if it exists
                '-err_detect', 'ignore_err',  # Ignore errors
                '-fflags', '+genpts+discardcorrupt+igndts',  # Generate PTS, discard corrupt packets
                '-ignore_unknown',  # Ignore unknown streams
                '-i', file_path,
                '-c:v', 'libx264',
                '-profile:v', 'baseline',  # Most compatible profile
                '-level', '3.0',  # Compatible level
                '-pix_fmt', 'yuv420p',
                '-preset', 'slow',  # Better quality
                '-crf', '23',  # Constant quality instead of bitrate
                '-vf', f"scale={quality['resolution']}",
                '-c:a', 'aac',
                '-b:a', quality['audio_bitrate'],
                '-ar', '44100',
                '-ac', '2',  # Stereo audio
                '-max_muxing_queue_size', '9999',  # Handle complex demuxing
                '-movflags', '+faststart',
                output_path
            ]
        else:
            cmd = [
                FFMPEG_PATH,
                '-y',
                '-err_detect', 'ignore_err',
                '-fflags', '+genpts+discardcorrupt',
                '-i', file_path,
                '-c:a', 'aac',
                '-b:a', quality['audio_bitrate'],
                '-ar', '44100',
                '-ac', '2',  # Stereo audio
                output_path
            ]
        
        logger.info(f"Attempting transcoding with error recovery for {file_path}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"Error during recovery transcoding: {result.stderr}")
            return False
        
        return True
    
    except Exception as e:
        logger.error(f"Exception during recovery transcoding: {str(e)}")
        return False
