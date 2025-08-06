from flask import Blueprint, render_template, redirect, url_for, flash, request, send_from_directory
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
import os
import logging
from models import Media, Category
from app import db
from utils import save_uploaded_file, format_file_size, format_duration, get_file_type
from ffmpeg_utils import get_media_info, generate_thumbnail
from config import UPLOAD_FOLDER, ITEMS_PER_PAGE

logger = logging.getLogger(__name__)

media_bp = Blueprint('media', __name__)

@media_bp.route('/')
def index():
    """Homepage showing featured/recent content."""
    page = request.args.get('page', 1, type=int)
    media_items = Media.query.filter_by(is_public=True, is_processed=True).order_by(Media.created_at.desc()).paginate(
        page=page, per_page=ITEMS_PER_PAGE
    )
    
    categories = Category.query.all()
    
    return render_template('browse.html', 
                           media_items=media_items,
                           categories=categories,
                           title="Browse Media")

@media_bp.route('/dashboard')
@login_required
def dashboard():
    """User dashboard showing their uploaded content."""
    page = request.args.get('page', 1, type=int)
    user_media = Media.query.filter_by(user_id=current_user.id).order_by(Media.created_at.desc()).paginate(
        page=page, per_page=ITEMS_PER_PAGE
    )
    
    return render_template('dashboard.html', media_items=user_media)

@media_bp.route('/upload', methods=['GET', 'POST'])
@login_required
def upload():
    """Handle media upload and processing."""
    if request.method == 'POST':
        # Check if the post request has the file part
        if 'media_file' not in request.files:
            flash('No file part', 'danger')
            return redirect(request.url)
        
        file = request.files['media_file']
        
        # If user does not select file, browser submits an empty file
        if file.filename == '':
            flash('No file selected', 'danger')
            return redirect(request.url)
        
        # Get form data
        title = request.form.get('title', '')
        description = request.form.get('description', '')
        category_id = request.form.get('category_id')
        is_public = 'is_public' in request.form
        
        # Validate form data
        if not title:
            flash('Title is required', 'danger')
            return redirect(request.url)
        
        # Save the uploaded file
        file_path = save_uploaded_file(file)
        
        if not file_path:
            flash('Error saving file. Please try again.', 'danger')
            return redirect(request.url)
        
        # Extract original filename
        original_filename = secure_filename(file.filename)
        filename = os.path.basename(file_path)
        media_type = get_file_type(original_filename)
        
        # Get media information using ffprobe
        media_info = get_media_info(file_path)
        
        if not media_info:
            flash('Failed to process media file', 'danger')
            return redirect(request.url)
        
        # Create new media record
        new_media = Media(
            title=title,
            description=description,
            filename=filename,
            original_filename=original_filename,
            file_path=file_path,
            media_type=media_type,
            file_size=media_info['filesize'],
            duration=media_info['duration'],
            format=media_info['format'],
            is_public=is_public,
            is_processed=True,  # For simplicity, mark as processed right away
            user_id=current_user.id
        )
        
        # Set category if provided
        if category_id and category_id.isdigit():
            category = Category.query.get(int(category_id))
            if category:
                new_media.category_id = category.id
        
        try:
            # Add to database
            db.session.add(new_media)
            db.session.commit()
            
            # Generate thumbnail for video files
            if new_media.media_type == 'video':
                thumbnail_path = generate_thumbnail(file_path, new_media.id)
                if thumbnail_path:
                    new_media.thumbnail_path = thumbnail_path
                    db.session.commit()
            
            flash('Media uploaded successfully', 'success')
            return redirect(url_for('media.dashboard'))
        
        except Exception as e:
            db.session.rollback()
            logger.error(f"Error saving media: {str(e)}")
            flash('An error occurred while saving media', 'danger')
            return redirect(request.url)
    
    # GET request - show upload form
    categories = Category.query.all()
    return render_template('upload.html', categories=categories)

@media_bp.route('/watch/<int:media_id>')
def watch(media_id):
    """View a specific media item."""
    media = Media.query.get_or_404(media_id)
    
    # Check if media is public or user is the owner
    if not media.is_public and (not current_user.is_authenticated or media.user_id != current_user.id):
        flash('You do not have permission to view this media', 'danger')
        return redirect(url_for('media.index'))
    
    # Increment view count
    media.views += 1
    db.session.commit()
    
    # Format media information for display
    formatted_size = format_file_size(media.file_size)
    formatted_duration = format_duration(media.duration)
    
    return render_template('watch.html', 
                           media=media, 
                           formatted_size=formatted_size,
                           formatted_duration=formatted_duration)

@media_bp.route('/category/<int:category_id>')
def category(category_id):
    """Browse media by category."""
    category = Category.query.get_or_404(category_id)
    page = request.args.get('page', 1, type=int)
    
    media_items = Media.query.filter_by(category_id=category.id, is_public=True, is_processed=True).paginate(
        page=page, per_page=ITEMS_PER_PAGE
    )
    
    return render_template('category.html', 
                           category=category, 
                           media_items=media_items)

@media_bp.route('/media/<path:filename>')
def serve_media(filename):
    """Serve media files."""
    return send_from_directory(UPLOAD_FOLDER, filename)

@media_bp.route('/media/<int:media_id>/edit', methods=['GET', 'POST'])
@login_required
def edit_media(media_id):
    """Edit media metadata."""
    media = Media.query.get_or_404(media_id)
    
    # Ensure user is the owner
    if media.user_id != current_user.id and not current_user.is_admin:
        flash('You do not have permission to edit this media', 'danger')
        return redirect(url_for('media.dashboard'))
    
    if request.method == 'POST':
        # Update media information
        media.title = request.form.get('title', media.title)
        media.description = request.form.get('description', media.description)
        media.is_public = 'is_public' in request.form
        
        category_id = request.form.get('category_id')
        if category_id and category_id.isdigit():
            category = Category.query.get(int(category_id))
            if category:
                media.category_id = category.id
        else:
            media.category_id = None
        
        try:
            db.session.commit()
            flash('Media updated successfully', 'success')
            return redirect(url_for('media.watch', media_id=media.id))
        except Exception as e:
            db.session.rollback()
            logger.error(f"Error updating media: {str(e)}")
            flash('An error occurred while updating media', 'danger')
    
    categories = Category.query.all()
    return render_template('edit_media.html', media=media, categories=categories)

@media_bp.route('/media/<int:media_id>/delete', methods=['POST'])
@login_required
def delete_media(media_id):
    """Delete a media item."""
    media = Media.query.get_or_404(media_id)
    
    # Ensure user is the owner or an admin
    if media.user_id != current_user.id and not current_user.is_admin:
        flash('You do not have permission to delete this media', 'danger')
        return redirect(url_for('media.dashboard'))
    
    try:
        # Delete the file from filesystem
        if os.path.exists(media.file_path):
            os.remove(media.file_path)
        
        # Delete thumbnail if exists
        if media.thumbnail_path and os.path.exists(media.thumbnail_path):
            os.remove(media.thumbnail_path)
        
        # Delete database record
        db.session.delete(media)
        db.session.commit()
        
        flash('Media deleted successfully', 'success')
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error deleting media: {str(e)}")
        flash('An error occurred while deleting media', 'danger')
    
    return redirect(url_for('media.dashboard'))

@media_bp.route('/search')
def search():
    """Search for media."""
    query = request.args.get('q', '')
    page = request.args.get('page', 1, type=int)
    
    if not query:
        return redirect(url_for('media.index'))
    
    # Search in title and description
    search_results = Media.query.filter(
        Media.is_public == True,
        Media.is_processed == True,
        (Media.title.ilike(f'%{query}%') | Media.description.ilike(f'%{query}%'))
    ).paginate(page=page, per_page=ITEMS_PER_PAGE)
    
    return render_template('search_results.html', 
                           media_items=search_results, 
                           query=query)
