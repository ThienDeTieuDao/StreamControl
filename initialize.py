#!/usr/bin/env python3
"""
StreamLite Initialization Script
This script initializes the database and creates the initial admin user
"""

import os
import sys
import getpass
import logging
from datetime import datetime
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("app")

# Load environment variables from .env file
load_dotenv()

# Import necessary components
from app import app, db
from models import User, Category, SiteSettings
from werkzeug.security import generate_password_hash

def create_tables():
    """Create all database tables"""
    print("Creating database tables...")
    with app.app_context():
        db.create_all()
        print("Database tables created successfully.")

def create_admin_user(username, email, password):
    """Create an admin user if one doesn't exist"""
    with app.app_context():
        # Check if any admin user exists
        admin_exists = User.query.filter_by(is_admin=True).first()
        
        if admin_exists:
            print(f"Admin user already exists: {admin_exists.username}")
            return admin_exists
        
        # Create new admin user
        admin_user = User(
            username=username,
            email=email,
            password_hash=generate_password_hash(password),
            is_admin=True,
            created_at=datetime.utcnow(),
            last_login=datetime.utcnow()
        )
        
        db.session.add(admin_user)
        db.session.commit()
        print(f"Admin user created successfully: {username}")
        return admin_user

def create_default_categories():
    """Create default content categories if none exist"""
    with app.app_context():
        # Check if any categories exist
        categories_exist = Category.query.first()
        
        if categories_exist:
            print("Categories already exist.")
            return
        
        # Create default categories
        default_categories = [
            {"name": "Entertainment", "description": "Entertainment videos", "icon": "film"},
            {"name": "Gaming", "description": "Gaming streams and videos", "icon": "gamepad"},
            {"name": "Music", "description": "Music videos and performances", "icon": "music"},
            {"name": "Education", "description": "Educational content", "icon": "graduation-cap"},
            {"name": "Sports", "description": "Sports videos and live streams", "icon": "futbol"},
            {"name": "News", "description": "News and current events", "icon": "newspaper"},
            {"name": "Technology", "description": "Technology tutorials and reviews", "icon": "laptop-code"}
        ]
        
        for cat_data in default_categories:
            category = Category(**cat_data)
            db.session.add(category)
        
        db.session.commit()
        print(f"Created {len(default_categories)} default categories.")

def create_site_settings():
    """Create default site settings if none exist"""
    with app.app_context():
        # Check if settings exist
        settings_exist = SiteSettings.query.first()
        
        if settings_exist:
            print("Site settings already exist.")
            return
        
        # Create default settings
        default_settings = SiteSettings(
            site_name="StreamLite",
            primary_color="#3b71ca",
            accent_color="#14a44d",
            footer_text="© StreamLite | Lightweight Streaming Platform"
        )
        
        db.session.add(default_settings)
        db.session.commit()
        print("Default site settings created.")

def interactive_setup():
    """Run interactive setup process"""
    print("=" * 50)
    print("StreamLite Initialization")
    print("=" * 50)
    print("\nThis script will set up your StreamLite installation.")
    
    # Ask for admin user details
    print("\nPlease provide admin user details:")
    username = input("Admin username [admin]: ") or "admin"
    email = input("Admin email [admin@example.com]: ") or "admin@example.com"
    
    while True:
        password = getpass.getpass("Admin password: ")
        if len(password) < 8:
            print("Password must be at least 8 characters long.")
            continue
        
        confirm_password = getpass.getpass("Confirm password: ")
        if password != confirm_password:
            print("Passwords do not match. Please try again.")
            continue
        
        break
    
    # Confirm setup
    print("\nReady to initialize with the following settings:")
    print(f"- Admin Username: {username}")
    print(f"- Admin Email: {email}")
    
    confirm = input("\nProceed with initialization? [Y/n]: ") or "Y"
    if confirm.lower() not in ["y", "yes"]:
        print("Initialization cancelled.")
        return False
    
    # All database operations should already be within an app context from the main function
    # Create database tables
    create_tables()
    
    # Create admin user
    create_admin_user(username, email, password)
    
    # Create default categories
    create_default_categories()
    
    # Create default site settings
    create_site_settings()
    
    print("\n" + "=" * 50)
    print("Initialization Complete!")
    print("=" * 50)
    print("\nYou can now login with your admin credentials.")
    
    return True

def main():
    """Main function"""
    # Check if running in non-interactive mode
    if "--non-interactive" in sys.argv:
        with app.app_context():
            create_tables()
            create_admin_user("admin", "admin@example.com", "streamlite_admin")
            create_default_categories()
            create_site_settings()
            print("Non-interactive initialization complete.")
            return
    
    # Otherwise, run interactive setup
    with app.app_context():
        interactive_setup()

if __name__ == "__main__":
    main()