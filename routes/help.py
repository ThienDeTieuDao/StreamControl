from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user

from app import db
from models import SupportChat, SupportMessage, User

help_bp = Blueprint('help', __name__, url_prefix='/help')

@help_bp.route('/')
def index():
    """Help center index page."""
    return render_template('help/index.html')

@help_bp.route('/obs-setup')
def obs_setup():
    """OBS Studio setup guide."""
    return render_template('guides/obs_setup.html')

@help_bp.route('/rtmp-guide')
def rtmp_guide():
    """RTMP streaming guide."""
    return render_template('guides/rtmp_guide.html')

@help_bp.route('/webrtc-guide')
def webrtc_guide():
    """WebRTC streaming guide."""
    return render_template('guides/webrtc_guide.html')

@help_bp.route('/faq')
def faq():
    """Frequently asked questions."""
    return render_template('help/faq.html')

@help_bp.route('/contact', methods=['GET', 'POST'])
def contact():
    """Contact support form."""
    if request.method == 'POST':
        subject = request.form.get('subject')
        message = request.form.get('message')
        
        if not subject or not message:
            flash('Please fill out all fields.', 'danger')
            return render_template('help/contact.html')
        
        # Create a support chat
        support_chat = SupportChat(
            subject=subject,
            user_id=current_user.id if current_user.is_authenticated else None
        )
        db.session.add(support_chat)
        db.session.flush()  # Get the ID for the new chat
        
        # Add the initial message
        support_message = SupportMessage(
            message=message,
            support_chat_id=support_chat.id,
            user_id=current_user.id if current_user.is_authenticated else None,
            is_system_message=False if current_user.is_authenticated else True
        )
        db.session.add(support_message)
        db.session.commit()
        
        flash('Your support request has been submitted. We will respond as soon as possible.', 'success')
        return redirect(url_for('help.index'))
        
    return render_template('help/contact.html')