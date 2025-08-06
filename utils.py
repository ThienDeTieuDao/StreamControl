import os
import uuid
import json
from werkzeug.utils import secure_filename
from config import ALLOWED_EXTENSIONS, UPLOAD_FOLDER
import logging

logger = logging.getLogger(__name__)

def allowed_file(filename, allowed_extensions=None):
    """Check if the file extension is allowed.
    
    Args:
        filename: The filename to check
        allowed_extensions: Optional list of allowed extensions, uses ALLOWED_EXTENSIONS by default
    """
    if not allowed_extensions:
        allowed_extensions = ALLOWED_EXTENSIONS
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in allowed_extensions

def get_file_type(filename):
    """Determine if a file is audio or video based on its extension."""
    from config import ALLOWED_VIDEO_EXTENSIONS, ALLOWED_AUDIO_EXTENSIONS
    
    ext = filename.rsplit('.', 1)[1].lower()
    if ext in ALLOWED_VIDEO_EXTENSIONS:
        return 'video'
    elif ext in ALLOWED_AUDIO_EXTENSIONS:
        return 'audio'
    return None

def generate_unique_filename(filename):
    """Generate a unique filename while preserving the original extension."""
    ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
    unique_filename = f"{uuid.uuid4().hex}.{ext}"
    return unique_filename

def save_uploaded_file(file, subfolder=None, allowed_extensions=None):
    """Save an uploaded file to the filesystem with a unique filename.
    
    Args:
        file: The file object from request.files
        subfolder: Optional subfolder within UPLOAD_FOLDER to store the file
        allowed_extensions: Optional list of allowed extensions
        
    Returns:
        Dictionary with file info on success, or error info on failure
    """
    if file and allowed_file(file.filename, allowed_extensions):
        original_filename = secure_filename(file.filename)
        unique_filename = generate_unique_filename(original_filename)
        
        # Determine path based on subfolder
        if subfolder:
            # Create subfolder if it doesn't exist
            subfolder_path = os.path.join(UPLOAD_FOLDER, subfolder)
            os.makedirs(subfolder_path, exist_ok=True)
            file_path = os.path.join(subfolder_path, unique_filename)
        else:
            file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
        
        try:
            file.save(file_path)
            # Return dictionary with file information
            return {
                'file_path': file_path,
                'original_filename': original_filename,
                'unique_filename': unique_filename,
                'error': None
            }
        except Exception as e:
            logger.error(f"Error saving file: {str(e)}")
            return {'error': str(e), 'file_path': None}
    
    return {'error': 'Invalid file type', 'file_path': None}

def format_file_size(size_bytes):
    """Format file size from bytes to human-readable format."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"

def format_duration(seconds):
    """Format duration from seconds to HH:MM:SS format."""
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    seconds = seconds % 60
    
    if hours > 0:
        return f"{int(hours)}:{int(minutes):02d}:{int(seconds):02d}"
    else:
        return f"{int(minutes):02d}:{int(seconds):02d}"

def delete_file(file_path):
    """Safely delete a file from the filesystem."""
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            return True
    except Exception as e:
        logger.error(f"Error deleting file {file_path}: {str(e)}")
    return False
