from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify
from flask_login import login_required, current_user
from app import db
from models import LiveStream
import os
import json
import uuid

# Create blueprint with a unique name
webrtc_bp = Blueprint('webrtc_routes', __name__, url_prefix='/webrtc-integration')

@webrtc_bp.route('/')
def index():
    """WebRTC landing page for choosing between broadcasting or viewing"""
    # Redirect to the external WebRTC server
    return redirect('https://hwosecurity.org:5443/webrtc')

@webrtc_bp.route('/new')
@login_required
def create_stream():
    """Create a new WebRTC stream with a unique stream key"""
    # Generate a new stream key
    stream_key = f"webrtc_{uuid.uuid4().hex[:16]}"
    
    # Create a new LiveStream record
    new_stream = LiveStream(
        title=f"{current_user.username}'s WebRTC Stream",
        description="WebRTC live stream",
        stream_key=stream_key,
        is_public=True,
        user_id=current_user.id
    )
    
    # Set WebRTC specific settings
    new_stream.stream_settings = {
        'type': 'webrtc',
        'port': 5443,
        'created_at': str(new_stream.created_at)
    }
    
    # Save to database
    db.session.add(new_stream)
    db.session.commit()
    
    # Redirect to the external WebRTC server broadcast page
    flash('WebRTC stream created successfully!', 'success')
    return redirect(f'https://hwosecurity.org:5443/webrtc/broadcast?stream_key={stream_key}')

@webrtc_bp.route('/streams')
def list_streams():
    """List active WebRTC streams"""
    active_streams = LiveStream.query.filter_by(is_live=True, is_public=True).all()
    webrtc_streams = [s for s in active_streams if s.stream_settings.get('type') == 'webrtc']
    
    # Instead of using a template, redirect to the WebRTC server streams page
    return redirect('https://hwosecurity.org:5443/webrtc')

def setup_routes(app):
    """Register the WebRTC blueprint with the Flask app"""
    # No need to register here, it's already registered in app.py