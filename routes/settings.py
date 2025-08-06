from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify
from flask_login import login_required, current_user
from app import db
from models import SiteSettings, SupportChat, SupportMessage, User
import os
from utils import allowed_file, save_uploaded_file
from datetime import datetime
import logging
from routes.admin import admin_required

logger = logging.getLogger(__name__)

settings_bp = Blueprint('settings', __name__, url_prefix='/settings')

# Site Settings and Customization (Admin Only)
@settings_bp.route('/site', methods=['GET', 'POST'])
@admin_required
def site_settings():
    """Manage site settings including logo, icon, and other customizations."""
    settings = SiteSettings.get_settings()
    
    if request.method == 'POST':
        # Update site name and text settings
        settings.site_name = request.form.get('site_name', 'StreamLite')
        settings.primary_color = request.form.get('primary_color', '#3b71ca')
        settings.accent_color = request.form.get('accent_color', '#14a44d')
        settings.footer_text = request.form.get('footer_text', '© StreamLite | Lightweight Streaming Platform')
        settings.logo_height = int(request.form.get('logo_height', 40))
        settings.logo_width = int(request.form.get('logo_width', 200))
        settings.enable_registration = 'enable_registration' in request.form
        settings.max_upload_size_mb = int(request.form.get('max_upload_size_mb', 500))
        settings.custom_css = request.form.get('custom_css', '')
        
        # Handle logo upload
        if 'logo' in request.files and request.files['logo'].filename:
            logo_file = request.files['logo']
            if logo_file and allowed_file(logo_file.filename, ['png', 'jpg', 'jpeg', 'gif', 'svg']):
                result = save_uploaded_file(logo_file, 'branding')
                if not result.get('error'):
                    # Delete old logo if it exists
                    if settings.logo_path and os.path.exists(settings.logo_path):
                        try:
                            os.remove(settings.logo_path)
                        except:
                            pass
                    settings.logo_path = result.get('file_path')
                else:
                    flash(f'Error uploading logo: {result.get("error")}', 'danger')
        
        # Handle favicon upload
        if 'favicon' in request.files and request.files['favicon'].filename:
            favicon_file = request.files['favicon']
            if favicon_file and allowed_file(favicon_file.filename, ['png', 'ico']):
                result = save_uploaded_file(favicon_file, 'branding')
                if not result.get('error'):
                    # Delete old favicon if it exists
                    if settings.favicon_path and os.path.exists(settings.favicon_path):
                        try:
                            os.remove(settings.favicon_path)
                        except:
                            pass
                    settings.favicon_path = result.get('file_path')
                else:
                    flash(f'Error uploading favicon: {result.get("error")}', 'danger')
        
        db.session.commit()
        flash('Site settings have been updated.', 'success')
        return redirect(url_for('settings.site_settings'))
    
    return render_template('admin/site_settings.html', settings=settings)


# Support Chat System
@settings_bp.route('/support/<int:stream_id>/open', methods=['POST'])
@login_required
def open_support_chat(stream_id):
    """Open a new support chat for a live stream."""
    subject = request.form.get('subject', 'Support Request')
    
    # Create a new support chat
    chat = SupportChat(
        subject=subject,
        user_id=current_user.id,
        live_stream_id=stream_id
    )
    
    # Add the initial message from the user
    message_text = request.form.get('message')
    if message_text:
        message = SupportMessage(
            message=message_text,
            user_id=current_user.id,
            support_chat_id=chat.id
        )
        chat.messages.append(message)
    
    db.session.add(chat)
    db.session.commit()
    
    # If this is an AJAX request, return JSON
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return jsonify({
            'success': True,
            'chat_id': chat.id
        })
    
    flash('Your support request has been submitted.', 'success')
    return redirect(url_for('live.view_stream', stream_id=stream_id))


@settings_bp.route('/support/<int:chat_id>/message', methods=['POST'])
@login_required
def send_support_message(chat_id):
    """Send a message in a support chat."""
    chat = SupportChat.query.get_or_404(chat_id)
    
    # Only allow messages from the chat owner or admins
    if current_user.id != chat.user_id and not current_user.is_admin:
        return jsonify({'error': 'Unauthorized'}), 403
    
    message_text = request.form.get('message')
    if not message_text:
        return jsonify({'error': 'Message is required'}), 400
    
    # Create the message
    message = SupportMessage(
        support_chat_id=chat.id,
        user_id=current_user.id,
        is_admin=current_user.is_admin,
        message=message_text
    )
    
    # Update the chat timestamp
    chat.updated_at = datetime.utcnow()
    
    db.session.add(message)
    db.session.commit()
    
    # If this is an AJAX request, return JSON
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return jsonify({
            'success': True,
            'message': {
                'id': message.id,
                'text': message.message,
                'is_admin': message.is_admin,
                'timestamp': message.created_at.strftime('%H:%M:%S'),
                'user': current_user.username
            }
        })
    
    return redirect(url_for('settings.view_support_chat', chat_id=chat.id))


@settings_bp.route('/support/<int:chat_id>')
@login_required
def view_support_chat(chat_id):
    """View a specific support chat conversation."""
    chat = SupportChat.query.get_or_404(chat_id)
    
    # Only allow access to chat owner or admins
    if current_user.id != chat.user_id and not current_user.is_admin:
        flash('You do not have permission to view this chat', 'danger')
        return redirect(url_for('media.dashboard'))
    
    # Mark all messages as read for this user
    if current_user.is_admin:
        # Admin is viewing, mark user messages as read
        SupportMessage.query.filter_by(
            support_chat_id=chat.id, 
            is_admin=False, 
            is_read=False
        ).update({SupportMessage.is_read: True})
    else:
        # Regular user viewing, mark admin messages as read
        SupportMessage.query.filter_by(
            support_chat_id=chat.id, 
            is_admin=True,
            is_read=False
        ).update({SupportMessage.is_read: True})
    
    db.session.commit()
    
    messages = SupportMessage.query.filter_by(support_chat_id=chat.id).order_by(SupportMessage.created_at).all()
    
    return render_template('support/view_chat.html', chat=chat, messages=messages)


@settings_bp.route('/support/<int:chat_id>/close', methods=['POST'])
@login_required
def close_support_chat(chat_id):
    """Close a support chat."""
    chat = SupportChat.query.get_or_404(chat_id)
    
    # Only allow chat owner or admins to close the chat
    if current_user.id != chat.user_id and not current_user.is_admin:
        flash('You do not have permission to close this chat', 'danger')
        return redirect(url_for('media.dashboard'))
    
    chat.is_active = False
    chat.updated_at = datetime.utcnow()
    
    # Add a system message about the closing
    message = SupportMessage(
        support_chat_id=chat.id,
        user_id=current_user.id,
        is_admin=current_user.is_admin,
        is_system_message=True,
        message="Support chat closed by " + ("administrator" if current_user.is_admin else "user")
    )
    
    db.session.add(message)
    db.session.commit()
    
    flash('Support chat closed successfully', 'success')
    
    if current_user.is_admin:
        return redirect(url_for('admin.support_chats'))
    else:
        return redirect(url_for('media.dashboard'))


# Admin-only support chat management
@settings_bp.route('/admin/support-chats')
@admin_required
def support_chats():
    """List all active support chat sessions."""
    active_chats = SupportChat.query.filter_by(is_active=True).order_by(SupportChat.updated_at.desc()).all()
    closed_chats = SupportChat.query.filter_by(is_active=False).order_by(SupportChat.updated_at.desc()).limit(20).all()
    
    return render_template('admin/support_chats.html', active_chats=active_chats, closed_chats=closed_chats)


@settings_bp.route('/support/check_messages/<int:chat_id>')
@login_required
def check_support_messages(chat_id):
    """Check for new messages in a support chat."""
    chat = SupportChat.query.get_or_404(chat_id)
    
    # Only allow chat owner or admins to access
    if current_user.id != chat.user_id and not current_user.is_admin:
        return jsonify({'error': 'Unauthorized'}), 403
    
    last_id = request.args.get('last_id', 0, type=int)
    
    # Get messages newer than last_id
    messages = SupportMessage.query.filter(
        SupportMessage.support_chat_id == chat.id,
        SupportMessage.id > last_id
    ).order_by(SupportMessage.created_at).all()
    
    # Format messages for the response
    formatted_messages = []
    for message in messages:
        formatted_messages.append({
            'id': message.id,
            'username': message.user.username,
            'timestamp': message.created_at.strftime('%H:%M:%S'),
            'message': message.message,
            'is_admin': message.is_admin,
            'is_system_message': message.is_system_message
        })
    
    # Mark messages as read
    if current_user.is_admin:
        # Admin viewing - mark user messages as read
        unread_messages = SupportMessage.query.filter(
            SupportMessage.support_chat_id == chat.id,
            SupportMessage.is_admin == False,
            SupportMessage.is_read == False
        ).all()
    else:
        # User viewing - mark admin messages as read
        unread_messages = SupportMessage.query.filter(
            SupportMessage.support_chat_id == chat.id,
            SupportMessage.is_admin == True,
            SupportMessage.is_read == False
        ).all()
    
    for message in unread_messages:
        message.is_read = True
    
    db.session.commit()
    
    return jsonify({
        'messages': formatted_messages
    })


@settings_bp.route('/support/unread/count')
@login_required
def unread_support_messages():
    """Get the count of unread support messages."""
    if current_user.is_admin:
        # For admins, count unread messages across all active chats
        count = SupportMessage.query.join(SupportChat).filter(
            SupportChat.is_active == True,
            SupportMessage.is_admin == False,
            SupportMessage.is_read == False
        ).count()
    else:
        # For regular users, count unread messages in their chats
        count = SupportMessage.query.join(SupportChat).filter(
            SupportChat.user_id == current_user.id,
            SupportChat.is_active == True,
            SupportMessage.is_admin == True,
            SupportMessage.is_read == False
        ).count()
    
    return jsonify({
        'unread_count': count
    })