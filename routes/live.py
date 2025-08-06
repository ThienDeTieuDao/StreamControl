from flask import Blueprint, render_template, flash, redirect, url_for, request, jsonify, abort
from flask_login import login_required, current_user
import os
import secrets
from werkzeug.utils import secure_filename
import datetime
from sqlalchemy import desc
import time

from app import db
from models import LiveStream, Category, ChatMessage, StreamAnalytics, User, SupportChat
from utils import allowed_file, save_uploaded_file

live_bp = Blueprint('live', __name__, url_prefix='/live')


@live_bp.route('/')
def index():
    """Show all live streams currently active."""
    # Get active live streams
    live_streams = LiveStream.query.filter_by(is_live=True, is_public=True).order_by(desc(LiveStream.viewer_count)).all()
    
    # Get featured stream (the one with most viewers or most recent)
    featured_stream = None
    if live_streams:
        featured_stream = live_streams[0]
        live_streams = live_streams[1:]  # Remove featured from regular list
    
    # Get categories
    categories = Category.query.all()
    
    # Get some recommended on-demand media
    from models import Media
    recommended_media = Media.query.filter_by(is_public=True, is_processed=True).order_by(desc(Media.created_at)).limit(8).all()
    
    return render_template('live/index.html', 
                          live_streams=live_streams,
                          featured_stream=featured_stream,
                          categories=categories,
                          recommended_media=recommended_media,
                          now=datetime.datetime.utcnow())


@live_bp.route('/<int:stream_id>')
def view_stream(stream_id):
    """View a specific live stream."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Check if private and not owner
    if not stream.is_public and (not current_user.is_authenticated or current_user.id != stream.user_id):
        flash('This stream is private.', 'warning')
        return redirect(url_for('live.index'))
    
    # Increment viewer count if live
    if stream.is_live:
        stream.viewer_count += 1
        db.session.commit()
    
    # Get related streams
    related_streams = []
    if stream.category:
        related_streams = LiveStream.query.filter(
            LiveStream.category_id == stream.category_id,
            LiveStream.id != stream.id,
            LiveStream.is_live == True,
            LiveStream.is_public == True
        ).limit(4).all()
    
    # If not enough related streams by category, add some general live streams
    if len(related_streams) < 4:
        additional_streams = LiveStream.query.filter(
            LiveStream.id != stream.id,
            LiveStream.is_live == True,
            LiveStream.is_public == True
        ).limit(4 - len(related_streams)).all()
        related_streams.extend(additional_streams)
    
    # Get recent media from this streamer
    from models import Media
    recent_media = Media.query.filter_by(
        user_id=stream.user_id,
        is_public=True,
        is_processed=True
    ).order_by(desc(Media.created_at)).limit(4).all()
    
    # Get active support chat for this stream if user is authenticated
    active_support_chat = None
    if current_user.is_authenticated:
        # Look for an active support chat for this user and stream
        active_support_chat = SupportChat.query.filter_by(
            user_id=current_user.id,
            live_stream_id=stream_id,
            is_active=True
        ).first()
    
    return render_template('live/view.html', 
                          stream=stream,
                          related_streams=related_streams,
                          recent_media=recent_media,
                          active_support_chat=active_support_chat,
                          now=datetime.datetime.utcnow())


@live_bp.route('/setup', methods=['GET', 'POST'])
@login_required
def setup_stream():
    """Set up a new live stream."""
    if request.method == 'POST':
        title = request.form.get('title')
        description = request.form.get('description', '')
        category_id = request.form.get('category_id')
        is_public = 'is_public' in request.form
        
        if not title:
            flash('Title is required.', 'danger')
            return redirect(url_for('live.setup_stream'))
        
        # Generate a secure random stream key
        stream_key = secrets.token_hex(16)
        
        # Create a new stream
        new_stream = LiveStream(
            title=title,
            description=description,
            user_id=current_user.id,
            stream_key=stream_key,
            is_public=is_public,
            created_at=datetime.datetime.utcnow(),
            stream_settings={
                'resolution': '720p',
                'bitrate': '2500k',
                'fps': 30,
                'video_codec': 'h264',
                'audio_codec': 'aac'
            }
        )
        
        if category_id:
            new_stream.category_id = category_id
        
        # Handle thumbnail upload
        if 'thumbnail' in request.files:
            thumbnail_file = request.files['thumbnail']
            if thumbnail_file and thumbnail_file.filename and allowed_file(thumbnail_file.filename):
                file_path = save_uploaded_file(thumbnail_file, subfolder='thumbnails')
                if file_path:
                    new_stream.thumbnail_path = file_path
        
        db.session.add(new_stream)
        db.session.commit()
        
        flash('Your stream has been created successfully.', 'success')
        return redirect(url_for('live.stream_control', stream_id=new_stream.id))
    
    # For GET request
    categories = Category.query.all()
    return render_template('live/setup.html', categories=categories)


@live_bp.route('/dashboard')
@login_required
def dashboard():
    """User's streaming dashboard showing their streams."""
    # Get all streams for the current user
    streams = LiveStream.query.filter_by(user_id=current_user.id).order_by(desc(LiveStream.created_at)).all()
    
    return render_template('live/dashboard.html', 
                          streams=streams,
                          now=datetime.datetime.utcnow())


@live_bp.route('/control/<int:stream_id>')
@login_required
def stream_control(stream_id):
    """Control panel for a specific stream."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Ensure the current user owns this stream
    if stream.user_id != current_user.id:
        flash('You do not have permission to access this stream.', 'danger')
        return redirect(url_for('live.dashboard'))
    
    return render_template('live/control.html', stream=stream)


@live_bp.route('/control/<int:stream_id>/toggle_stream', methods=['POST'])
@login_required
def toggle_stream(stream_id):
    """Manually toggle the stream status (on/off)."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Ensure the current user owns this stream
    if stream.user_id != current_user.id:
        flash('You do not have permission to control this stream.', 'danger')
        return redirect(url_for('live.dashboard'))
    
    # Toggle the stream status
    if stream.is_live:
        # Stop the stream
        stream.is_live = False
        stream.ended_at = datetime.datetime.utcnow()
        
        # Store analytics
        if stream.started_at:
            duration = (stream.ended_at - stream.started_at).total_seconds()
            
            analytics = StreamAnalytics(
                date=stream.ended_at.date(),
                total_viewers=stream.viewer_count,
                peak_viewers=stream.viewer_count,
                average_watch_time=int(duration / max(1, stream.viewer_count)),
                unique_viewers=stream.viewer_count,
                live_stream_id=stream.id
            )
            db.session.add(analytics)
        
        # Create a system message in chat
        system_message = ChatMessage(
            message="Stream has ended",
            is_system_message=True,
            user_id=stream.user_id,
            live_stream_id=stream.id
        )
        db.session.add(system_message)
        flash('Stream has been stopped.', 'success')
    else:
        # Start the stream
        stream.is_live = True
        stream.started_at = datetime.datetime.utcnow()
        stream.viewer_count = 0
        
        # Create a system message in chat
        system_message = ChatMessage(
            message="Stream has started",
            is_system_message=True,
            user_id=stream.user_id,
            live_stream_id=stream.id
        )
        db.session.add(system_message)
        flash('Stream has been started.', 'success')
    
    db.session.commit()
    return redirect(url_for('live.stream_control', stream_id=stream_id))


@live_bp.route('/api/start/<stream_key>', methods=['POST'])
def start_stream(stream_key):
    """API endpoint to start a stream (called by streaming software)."""
    stream = LiveStream.query.filter_by(stream_key=stream_key).first()
    
    if not stream:
        return jsonify({'success': False, 'message': 'Invalid stream key'}), 404
    
    # Update stream status
    stream.is_live = True
    stream.started_at = datetime.datetime.utcnow()
    stream.viewer_count = 0
    db.session.commit()
    
    # Create a system message in chat
    system_message = ChatMessage(
        message="Stream has started",
        is_system_message=True,
        user_id=stream.user_id,
        live_stream_id=stream.id
    )
    db.session.add(system_message)
    db.session.commit()
    
    return jsonify({'success': True, 'message': 'Stream started successfully'})


@live_bp.route('/api/end/<stream_key>', methods=['POST'])
def end_stream(stream_key):
    """API endpoint to end a stream (called by streaming software)."""
    stream = LiveStream.query.filter_by(stream_key=stream_key).first()
    
    if not stream:
        return jsonify({'success': False, 'message': 'Invalid stream key'}), 404
    
    # Update stream status
    stream.is_live = False
    stream.ended_at = datetime.datetime.utcnow()
    
    # Store analytics
    if stream.started_at:
        duration = (stream.ended_at - stream.started_at).total_seconds()
        
        analytics = StreamAnalytics(
            date=stream.ended_at.date(),
            total_viewers=stream.viewer_count,
            peak_viewers=stream.viewer_count,  # Ideally this would be tracked throughout the stream
            average_watch_time=int(duration / max(1, stream.viewer_count)),
            unique_viewers=stream.viewer_count,  # Ideally this would track unique IPs/users
            live_stream_id=stream.id
        )
        db.session.add(analytics)
    
    # Create a system message in chat
    system_message = ChatMessage(
        message="Stream has ended",
        is_system_message=True,
        user_id=stream.user_id,
        live_stream_id=stream.id
    )
    db.session.add(system_message)
    
    db.session.commit()
    
    return jsonify({'success': True, 'message': 'Stream ended successfully'})


@live_bp.route('/api/stream/authenticate', methods=['POST', 'GET'])
@live_bp.route('/api/stream/auth', methods=['POST', 'GET'])  # Alias for Nginx RTMP module
def authenticate_stream():
    """Authenticate a stream key for RTMP/RTMPS streaming.
    
    This endpoint is called by Nginx's RTMP module to validate stream keys
    before allowing a stream to start. It expects either:
    - A 'name' parameter in the POST data (from RTMP module)
    - A 'key' parameter in the query string (for testing)
    
    Returns 200 OK if the stream key is valid, 404 otherwise.
    """
    # Get the stream key from either POST data or query string
    if request.method == 'POST':
        # RTMP module sends the stream key as 'name'
        stream_key = request.form.get('name')
    else:
        # For testing, allow query string
        stream_key = request.args.get('key')
    
    if not stream_key:
        return 'Stream key missing', 404
    
    # Find the stream by key
    stream = LiveStream.query.filter_by(stream_key=stream_key).first()
    
    if not stream:
        # Log invalid attempt
        print(f"Invalid stream key attempt: {stream_key}")
        return 'Invalid stream key', 404
    
    # Stream key is valid
    return 'OK', 200


@live_bp.route('/api/chat/<int:stream_id>', methods=['POST'])
@login_required
def post_chat(stream_id):
    """API endpoint to post a chat message."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Check if stream is live
    if not stream.is_live:
        return jsonify({'success': False, 'message': 'Stream is not active'}), 400
    
    data = request.get_json()
    message = data.get('message', '').strip()
    
    if not message:
        return jsonify({'success': False, 'message': 'Message cannot be empty'}), 400
    
    # Create a new chat message
    new_message = ChatMessage(
        message=message,
        user_id=current_user.id,
        live_stream_id=stream_id,
        created_at=datetime.datetime.utcnow()
    )
    db.session.add(new_message)
    db.session.commit()
    
    # Return the message in a format suitable for display
    return jsonify({
        'id': new_message.id,
        'message': new_message.message,
        'username': current_user.username,
        'timestamp': new_message.created_at.strftime('%H:%M'),
        'is_system': False
    })


@live_bp.route('/api/chat/<int:stream_id>', methods=['GET'])
def get_chat(stream_id):
    """API endpoint to get recent chat messages."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Get last_id from query param to enable polling for new messages
    last_id = request.args.get('last_id', 0, type=int)
    
    # Get messages newer than last_id
    messages = ChatMessage.query.filter(
        ChatMessage.live_stream_id == stream_id,
        ChatMessage.id > last_id
    ).order_by(ChatMessage.created_at).limit(50).all()
    
    # Format messages for JSON response
    formatted_messages = []
    for msg in messages:
        try:
            username = User.query.get(msg.user_id).username if not msg.is_system_message else "System"
        except:
            username = "Unknown" if not msg.is_system_message else "System"
            
        formatted_messages.append({
            'id': msg.id,
            'message': msg.message,
            'username': username,
            'timestamp': msg.created_at.strftime('%H:%M'),
            'is_system': msg.is_system_message
        })
    
    # Count online viewers (approximate)
    online_users = stream.viewer_count
    
    return jsonify({
        'messages': formatted_messages,
        'online_users': online_users,
        'stream_active': stream.is_live
    })


@live_bp.route('/api/viewers/<int:stream_id>')
def get_viewers(stream_id):
    """API endpoint to get current viewer count."""
    stream = LiveStream.query.get_or_404(stream_id)
    return jsonify({'viewer_count': stream.viewer_count})
    
@live_bp.route('/api/stream/check_status/<int:stream_id>')
def check_stream_status(stream_id):
    """Check if a stream is actually live by verifying the manifest file exists."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Get the HLS manifest URL - check different possible locations
    possible_paths = [
        f"/var/hls/{stream.stream_key}.m3u8",  # Default nginx-rtmp path
        f"/var/www/hls/{stream.stream_key}.m3u8",  # Alternative nginx path
        os.path.join(os.getcwd(), f"hls/{stream.stream_key}.m3u8"),  # Local development path
        f"/hls/{stream.stream_key}.m3u8",  # Path relative to web root
        f"/live/hls/{stream.stream_key}.m3u8",  # Additional path for /live/hls
        f"/var/www/html/live/hls/{stream.stream_key}.m3u8",  # Common aapanel path
        f"/home/wwwroot/default/live/hls/{stream.stream_key}.m3u8"  # Another common path
    ]
    
    manifest_exists = False
    for path in possible_paths:
        if os.path.exists(path):
            manifest_exists = True
            break
    
    # Also attempt to directly check if the file is accessible via HTTP
    if not manifest_exists:
        try:
            import urllib.request
            import urllib.error
            
            # Try both HTTP and HTTPS
            urls = [
                f"http://hwosecurity.org/live/hls/{stream.stream_key}.m3u8",
                f"https://hwosecurity.org/live/hls/{stream.stream_key}.m3u8"
            ]
            
            for url in urls:
                try:
                    # Simple HEAD request with a timeout
                    req = urllib.request.Request(url, method="HEAD")
                    response = urllib.request.urlopen(req, timeout=2)
                    if response.status == 200:
                        manifest_exists = True
                        break
                except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
                    # File not accessible via this URL, try next one
                    continue
        except Exception as e:
            # Log the error but continue
            print(f"Error checking HTTP access to manifest: {str(e)}")
    
    is_actually_live = manifest_exists and stream.is_live
    
    # If it claims to be live but the file doesn't exist for more than 30 seconds, update the status
    if stream.is_live and not manifest_exists:
        # Just report the discrepancy for now
        pass
    
    return jsonify({
        'is_live': stream.is_live,
        'has_manifest': manifest_exists,
        'status': 'active' if is_actually_live else 'inactive',
        'stream_key': stream.stream_key,
        'timestamp': time.time()
    })


@live_bp.route('/edit/<int:stream_id>', methods=['GET', 'POST'])
@login_required
def edit_stream(stream_id):
    """Edit stream settings."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Ensure the current user owns this stream
    if stream.user_id != current_user.id:
        flash('You do not have permission to edit this stream.', 'danger')
        return redirect(url_for('live.dashboard'))
    
    if request.method == 'POST':
        title = request.form.get('title')
        description = request.form.get('description', '')
        category_id = request.form.get('category_id')
        is_public = 'is_public' in request.form
        
        if not title:
            flash('Title is required.', 'danger')
            return redirect(url_for('live.edit_stream', stream_id=stream_id))
        
        # Update stream details
        stream.title = title
        stream.description = description
        stream.is_public = is_public
        
        if category_id:
            stream.category_id = category_id
        else:
            stream.category_id = None
        
        # Handle thumbnail upload
        if 'thumbnail' in request.files:
            thumbnail_file = request.files['thumbnail']
            if thumbnail_file and thumbnail_file.filename and allowed_file(thumbnail_file.filename):
                file_path = save_uploaded_file(thumbnail_file, subfolder='thumbnails')
                if file_path:
                    # Remove old thumbnail if it exists
                    if stream.thumbnail_path:
                        try:
                            os.remove(stream.thumbnail_path)
                        except:
                            pass  # Ignore error if file doesn't exist
                    stream.thumbnail_path = file_path
        
        # Update stream settings
        resolution = request.form.get('resolution', '720p')
        bitrate = request.form.get('bitrate', '2500k')
        fps = request.form.get('fps', 30, type=int)
        
        stream.stream_settings = {
            'resolution': resolution,
            'bitrate': bitrate,
            'fps': fps,
            'video_codec': 'h264',
            'audio_codec': 'aac'
        }
        
        db.session.commit()
        flash('Stream settings updated successfully.', 'success')
        return redirect(url_for('live.stream_control', stream_id=stream_id))
    
    # For GET request
    categories = Category.query.all()
    return render_template('live/edit.html', stream=stream, categories=categories)


@live_bp.route('/delete/<int:stream_id>', methods=['POST'])
@login_required
def delete_stream(stream_id):
    """Delete a stream."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Ensure the current user owns this stream
    if stream.user_id != current_user.id and not current_user.is_admin:
        flash('You do not have permission to delete this stream.', 'danger')
        return redirect(url_for('live.dashboard'))
    
    # Delete associated chat messages
    ChatMessage.query.filter_by(live_stream_id=stream_id).delete()
    
    # Delete associated analytics
    StreamAnalytics.query.filter_by(live_stream_id=stream_id).delete()
    
    # Delete the stream
    db.session.delete(stream)
    db.session.commit()
    
    flash('Stream deleted successfully.', 'success')
    return redirect(url_for('live.dashboard'))


@live_bp.route('/analytics/<int:stream_id>')
@login_required
def stream_analytics(stream_id):
    """View analytics for a specific stream."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Ensure the current user owns this stream
    if stream.user_id != current_user.id and not current_user.is_admin:
        flash('You do not have permission to view analytics for this stream.', 'danger')
        return redirect(url_for('live.dashboard'))
    
    # Get analytics for this stream
    analytics = StreamAnalytics.query.filter_by(live_stream_id=stream_id).all()
    
    return render_template('live/analytics.html', stream=stream, analytics=analytics)


@live_bp.route('/streaming-guide')
def streaming_guide():
    """Show a guide on how to stream to the platform."""
    return render_template('live/streaming_guide.html')


@live_bp.route('/hls/<path:filename>')
@live_bp.route('/live/hls/<path:filename>')  # Adding additional route for the /live/hls path
def serve_hls(filename):
    """Serve HLS manifest files and segments."""
    # Check different possible locations for HLS files
    possible_paths = [
        "/var/hls",  # Default nginx-rtmp path
        "/var/www/hls",  # Alternative nginx path
        os.path.join(os.getcwd(), "hls"),  # Local development path
        "/var/www/html/live/hls",  # Common aapanel path
        "/home/wwwroot/default/live/hls",  # Another common path
    ]
    
    for base_path in possible_paths:
        file_path = os.path.join(base_path, filename)
        if os.path.exists(file_path):
            # Determine content type based on file extension
            ext = os.path.splitext(filename)[1].lower()
            content_type = 'application/octet-stream'  # Default content type
            
            # HLS specific formats
            if ext == '.m3u8':
                content_type = 'application/vnd.apple.mpegurl'
            elif ext == '.ts':
                content_type = 'video/mp2t'
            # Video formats
            elif ext in ['.mp4', '.m4v', '.mov']:
                content_type = 'video/mp4'
            elif ext == '.webm':
                content_type = 'video/webm'
            elif ext == '.mkv':
                content_type = 'video/x-matroska'
            elif ext in ['.avi', '.divx']:
                content_type = 'video/x-msvideo'
            elif ext in ['.wmv', '.asf']:
                content_type = 'video/x-ms-wmv'
            elif ext in ['.flv', '.f4v']:
                content_type = 'video/x-flv'
            elif ext in ['.3gp', '.3g2']:
                content_type = 'video/3gpp'
            elif ext in ['.mpg', '.mpeg']:
                content_type = 'video/mpeg'
            # Audio formats
            elif ext == '.mp3':
                content_type = 'audio/mpeg'
            elif ext == '.m4a':
                content_type = 'audio/mp4'
            elif ext == '.aac':
                content_type = 'audio/aac'
            elif ext == '.wav':
                content_type = 'audio/wav'
            elif ext == '.ogg':
                content_type = 'audio/ogg'
            elif ext == '.flac':
                content_type = 'audio/flac'
            elif ext in ['.wma', '.asf']:
                content_type = 'audio/x-ms-wma'
                
            # Open and serve the file with appropriate headers
            try:
                with open(file_path, 'rb') as f:
                    response = f.read()
                
                # Set up CORS and caching headers
                headers = {
                    'Content-Type': content_type,
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, OPTIONS',
                    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
                }
                
                # Set appropriate cache control based on file type
                if ext == '.m3u8':
                    # Don't cache manifest files
                    headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
                    headers['Pragma'] = 'no-cache'
                    headers['Expires'] = '0'
                elif ext == '.ts':
                    # Cache segments for a short time
                    headers['Cache-Control'] = 'public, max-age=60'
                else:
                    # Cache other files more aggressively
                    headers['Cache-Control'] = 'public, max-age=86400'
                
                return response, 200, headers
            except Exception as e:
                print(f"Error serving file {file_path}: {str(e)}")
                continue
    
    # If file not found in any location, try to forward the request
    try:
        import urllib.request
        import urllib.error
        
        # Try both possible external URLs
        external_urls = [
            f"https://hwosecurity.org/live/hls/{filename}",
            f"http://hwosecurity.org/live/hls/{filename}"
        ]
        
        for url in external_urls:
            try:
                with urllib.request.urlopen(url, timeout=3) as response:
                    if response.status == 200:
                        content = response.read()
                        content_type = response.headers.get('Content-Type', 'application/octet-stream')
                        
                        return content, 200, {
                            'Content-Type': content_type,
                            'Access-Control-Allow-Origin': '*',
                            'Cache-Control': 'no-cache'
                        }
            except Exception:
                continue
    except Exception as e:
        print(f"Error trying to proxy file {filename}: {str(e)}")
    
    # If file not found in any location and proxy failed
    return "Media file not found", 404


@live_bp.route('/<int:stream_id>/embed')
def embed_stream(stream_id):
    """Embeddable view for a specific live stream."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Check if stream is private
    if not stream.is_public:
        return render_template('live/embed_error.html', message="This stream is private or not available")
    
    # Increment viewer count if live
    if stream.is_live:
        stream.viewer_count += 1
        db.session.commit()
    
    # Get streamer info
    streamer = User.query.get(stream.user_id)
    
    # Get customization options from query parameters
    show_info = request.args.get('show_info', '1') == '1'
    show_watermark = request.args.get('show_watermark', '1') == '1'
    show_viewers = request.args.get('show_viewers', '1') == '1'
    theme = request.args.get('theme', 'dark')
    
    return render_template('live/embed.html', 
                          stream=stream,
                          streamer=streamer,
                          now=datetime.datetime.utcnow(),
                          show_info=show_info,
                          show_watermark=show_watermark,
                          show_viewers=show_viewers,
                          theme=theme)


@live_bp.route('/<int:stream_id>/embed-codes')
def embed_codes(stream_id):
    """Page with embed codes and stream URLs for a specific stream."""
    stream = LiveStream.query.get_or_404(stream_id)
    
    # Check permissions
    if not stream.is_public and (not current_user.is_authenticated or stream.user_id != current_user.id):
        flash('This stream is private.', 'danger')
        return redirect(url_for('live.index'))
    
    # Get streamer info
    streamer = User.query.get(stream.user_id)
    
    return render_template('live/embed_codes.html',
                          stream=stream,
                          streamer=streamer)