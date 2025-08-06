from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify
from flask_login import login_required, current_user
from app import db
from models import User, Media, Category, SiteSettings, SupportChat, SupportMessage, LiveStream
import logging
import os
from werkzeug.utils import secure_filename
from utils import allowed_file, save_uploaded_file
from datetime import datetime

logger = logging.getLogger(__name__)

admin_bp = Blueprint('admin', __name__, url_prefix='/admin')

# Admin authentication decorator
def admin_required(f):
    """Decorator that checks if the current user is an admin."""
    @login_required
    def decorated_function(*args, **kwargs):
        if not current_user.is_admin:
            flash('Admin access required', 'danger')
            return redirect(url_for('media.dashboard'))
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

@admin_bp.route('/')
@admin_required
def dashboard():
    """Admin dashboard with system overview."""
    user_count = User.query.count()
    media_count = Media.query.count()
    category_count = Category.query.count()
    
    # Get recent uploads
    recent_media = Media.query.order_by(Media.created_at.desc()).limit(5).all()
    
    # Get storage statistics
    total_storage = Media.query.with_entities(db.func.sum(Media.file_size)).scalar() or 0
    
    return render_template('admin/dashboard.html', 
                           user_count=user_count,
                           media_count=media_count,
                           category_count=category_count,
                           recent_media=recent_media,
                           total_storage=total_storage)

@admin_bp.route('/users')
@admin_required
def manage_users():
    """List and manage users."""
    page = request.args.get('page', 1, type=int)
    users = User.query.paginate(page=page, per_page=20)
    
    return render_template('admin/manage_users.html', users=users)

@admin_bp.route('/users/<int:user_id>/toggle_admin', methods=['POST'])
@admin_required
def toggle_admin(user_id):
    """Toggle admin status for a user."""
    user = User.query.get_or_404(user_id)
    
    # Don't allow removing admin from self
    if user.id == current_user.id:
        flash('You cannot remove your own admin privileges', 'danger')
        return redirect(url_for('admin.manage_users'))
    
    user.is_admin = not user.is_admin
    
    try:
        db.session.commit()
        flash(f"Admin status for {user.username} updated", 'success')
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error updating admin status: {str(e)}")
        flash('An error occurred while updating user', 'danger')
    
    return redirect(url_for('admin.manage_users'))

@admin_bp.route('/users/<int:user_id>/delete', methods=['POST'])
@admin_required
def delete_user(user_id):
    """Delete a user and all their media."""
    user = User.query.get_or_404(user_id)
    
    # Don't allow deleting self
    if user.id == current_user.id:
        flash('You cannot delete your own account', 'danger')
        return redirect(url_for('admin.manage_users'))
    
    try:
        # Delete all media files first
        for media in user.media_items:
            # This will also delete the files from disk
            db.session.delete(media)
        
        # Delete the user
        db.session.delete(user)
        db.session.commit()
        
        flash(f"User {user.username} and all their media deleted", 'success')
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error deleting user: {str(e)}")
        flash('An error occurred while deleting user', 'danger')
    
    return redirect(url_for('admin.manage_users'))

@admin_bp.route('/media')
@admin_required
def manage_media():
    """List and manage all media files."""
    page = request.args.get('page', 1, type=int)
    media_items = Media.query.paginate(page=page, per_page=20)
    
    return render_template('admin/manage_media.html', media_items=media_items)

@admin_bp.route('/categories', methods=['GET', 'POST'])
@admin_required
def manage_categories():
    """List and manage categories."""
    if request.method == 'POST':
        name = request.form.get('name')
        description = request.form.get('description', '')
        
        if not name:
            flash('Category name is required', 'danger')
            return redirect(url_for('admin.manage_categories'))
        
        # Check if category already exists
        if Category.query.filter_by(name=name).first():
            flash('Category already exists', 'danger')
            return redirect(url_for('admin.manage_categories'))
        
        # Create new category
        category = Category(name=name, description=description)
        
        try:
            db.session.add(category)
            db.session.commit()
            flash('Category added successfully', 'success')
        except Exception as e:
            db.session.rollback()
            logger.error(f"Error adding category: {str(e)}")
            flash('An error occurred while adding category', 'danger')
        
        return redirect(url_for('admin.manage_categories'))
    
    categories = Category.query.all()
    return render_template('admin/manage_categories.html', categories=categories)

@admin_bp.route('/categories/<int:category_id>/edit', methods=['POST'])
@admin_required
def edit_category(category_id):
    """Edit a category."""
    category = Category.query.get_or_404(category_id)
    
    name = request.form.get('name')
    description = request.form.get('description', '')
    
    if not name:
        flash('Category name is required', 'danger')
        return redirect(url_for('admin.manage_categories'))
    
    # Check if new name already exists for a different category
    existing = Category.query.filter_by(name=name).first()
    if existing and existing.id != category.id:
        flash('Category name already exists', 'danger')
        return redirect(url_for('admin.manage_categories'))
    
    try:
        category.name = name
        category.description = description
        db.session.commit()
        flash('Category updated successfully', 'success')
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error updating category: {str(e)}")
        flash('An error occurred while updating category', 'danger')
    
    return redirect(url_for('admin.manage_categories'))

@admin_bp.route('/categories/<int:category_id>/delete', methods=['POST'])
@admin_required
def delete_category(category_id):
    """Delete a category."""
    category = Category.query.get_or_404(category_id)
    
    try:
        # Update media items to have no category
        Media.query.filter_by(category_id=category.id).update({Media.category_id: None})
        
        # Delete the category
        db.session.delete(category)
        db.session.commit()
        
        flash('Category deleted successfully', 'success')
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error deleting category: {str(e)}")
        flash('An error occurred while deleting category', 'danger')
    
    return redirect(url_for('admin.manage_categories'))
