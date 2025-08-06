from app import db
from flask_login import UserMixin
from datetime import datetime
from sqlalchemy import JSON

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    profile_image = db.Column(db.String(512))
    bio = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    
    # Relationships
    media_items = db.relationship('Media', backref='uploader', lazy=True)
    live_streams = db.relationship('LiveStream', backref='streamer', lazy=True)
    chat_messages = db.relationship('ChatMessage', backref='user', lazy=True)
    
    def __repr__(self):
        return f'<User {self.username}>'

class Category(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(64), unique=True, nullable=False)
    description = db.Column(db.String(256))
    icon = db.Column(db.String(64))
    
    # Relationships
    media_items = db.relationship('Media', backref='category', lazy=True)
    live_streams = db.relationship('LiveStream', backref='category', lazy=True)
    
    def __repr__(self):
        return f'<Category {self.name}>'

class Media(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(128), nullable=False)
    description = db.Column(db.Text)
    filename = db.Column(db.String(256), nullable=False)
    original_filename = db.Column(db.String(256), nullable=False)
    file_path = db.Column(db.String(512), nullable=False)
    thumbnail_path = db.Column(db.String(512))
    media_type = db.Column(db.String(16), nullable=False)  # video, audio
    file_size = db.Column(db.Integer)  # Size in bytes
    duration = db.Column(db.Integer)   # Duration in seconds
    format = db.Column(db.String(32))  # mp4, mkv, etc.
    is_public = db.Column(db.Boolean, default=True)
    is_processed = db.Column(db.Boolean, default=False)
    views = db.Column(db.Integer, default=0)
    likes = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    tags = db.Column(db.String(256))
    
    # Advanced properties
    encoding_settings = db.Column(JSON, default={})
    playback_stats = db.Column(JSON, default={})
    
    # Foreign keys
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('category.id'))
    
    def __repr__(self):
        return f'<Media {self.title}>'

class LiveStream(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(128), nullable=False)
    description = db.Column(db.Text)
    thumbnail_path = db.Column(db.String(512))
    stream_key = db.Column(db.String(64), unique=True, nullable=False)
    is_live = db.Column(db.Boolean, default=False)
    is_public = db.Column(db.Boolean, default=True)
    viewer_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    started_at = db.Column(db.DateTime)
    ended_at = db.Column(db.DateTime)
    
    # Stream configuration
    stream_settings = db.Column(JSON, default={})
    stream_stats = db.Column(JSON, default={})
    
    # Foreign keys
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('category.id'))
    
    # Relationships
    chat_messages = db.relationship('ChatMessage', backref='live_stream', lazy=True)
    
    def __repr__(self):
        return f'<LiveStream {self.title}>'

class ChatMessage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    message = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_pinned = db.Column(db.Boolean, default=False)
    is_system_message = db.Column(db.Boolean, default=False)
    
    # Foreign keys
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    live_stream_id = db.Column(db.Integer, db.ForeignKey('live_stream.id'), nullable=False)
    
    def __repr__(self):
        return f'<ChatMessage {self.id}>'

class StreamAnalytics(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    date = db.Column(db.Date, nullable=False)
    total_viewers = db.Column(db.Integer, default=0)
    peak_viewers = db.Column(db.Integer, default=0)
    average_watch_time = db.Column(db.Integer)  # in seconds
    unique_viewers = db.Column(db.Integer, default=0)
    geographic_data = db.Column(JSON, default={})
    engagement_metrics = db.Column(JSON, default={})
    
    # Foreign keys
    live_stream_id = db.Column(db.Integer, db.ForeignKey('live_stream.id'), nullable=False)
    
    def __repr__(self):
        return f'<StreamAnalytics {self.id}>'


class SiteSettings(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    site_name = db.Column(db.String(128), default='StreamLite')
    logo_path = db.Column(db.String(512))
    favicon_path = db.Column(db.String(512))
    primary_color = db.Column(db.String(32), default='#3b71ca')
    accent_color = db.Column(db.String(32), default='#14a44d')
    logo_height = db.Column(db.Integer, default=40)
    logo_width = db.Column(db.Integer, default=200)
    # Additional site-wide settings
    enable_registration = db.Column(db.Boolean, default=True)
    max_upload_size_mb = db.Column(db.Integer, default=500)  # Maximum upload size in MB
    footer_text = db.Column(db.String(512), default='© StreamLite | Lightweight Streaming Platform')
    custom_css = db.Column(db.Text)
    
    @classmethod
    def get_settings(cls):
        """Get the current site settings or create default if none exists"""
        settings = cls.query.first()
        if not settings:
            settings = cls()
            db.session.add(settings)
            db.session.commit()
        return settings


class SupportChat(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    subject = db.Column(db.String(256))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Foreign keys
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    live_stream_id = db.Column(db.Integer, db.ForeignKey('live_stream.id'), nullable=True)
    
    # Relationships
    user = db.relationship('User', backref='support_chats')
    live_stream = db.relationship('LiveStream', backref='support_chats')
    messages = db.relationship('SupportMessage', backref='chat', lazy=True, cascade="all, delete-orphan")
    
    def __repr__(self):
        return f'<SupportChat {self.id}>'


class SupportMessage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    message = db.Column(db.Text, nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    is_read = db.Column(db.Boolean, default=False)
    is_system_message = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Foreign keys
    support_chat_id = db.Column(db.Integer, db.ForeignKey('support_chat.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Relationships
    user = db.relationship('User', backref='support_messages')
    
    def __repr__(self):
        return f'<SupportMessage {self.id}>'
