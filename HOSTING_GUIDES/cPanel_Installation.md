# StreamLite Installation Guide for cPanel

This guide provides step-by-step instructions for installing StreamLite on a cPanel server.

## Prerequisites

- cPanel access with admin privileges
- Python 3.8 or higher available on your server
- SSH access to your server (for some steps)
- FFmpeg installed (or ability to install it)
- Domain pointed to your cPanel account

## Installation Steps

### 1. Preparing Your Environment

1. Log in to your cPanel account.
2. Go to the **File Manager** and navigate to your domain's document root (usually `public_html`).
3. Create a directory for your StreamLite application (e.g., `streamlite`).
4. Upload your StreamLite application files to this directory.

### 2. Setting Up Python Environment

cPanel provides the **Setup Python App** interface to create and manage Python applications:

1. In cPanel, go to **Software** > **Setup Python App**.
2. Click on **Create Application**.
3. Fill in the following details:
   - **Python Version**: Select Python 3.8 or higher
   - **Application Root**: Enter the path to your StreamLite directory (e.g., `/home/username/public_html/streamlite`)
   - **Application URL**: Choose your domain or a subdomain
   - **Application Startup File**: `main.py`
   - **Application Entry Point**: `app`
4. Click **Create**.

### 3. Setting Up Virtual Environment Manually (Alternative Method)

If the Python App interface doesn't meet your needs, you can set up a virtual environment manually:

1. Connect to your server via SSH.
2. Navigate to your application directory:
   ```bash
   cd ~/public_html/streamlite
   ```

3. Install the Python virtual environment package (if not already installed):
   
   For most cPanel servers, you'll need to contact the hosting provider to install the Python venv package as you may not have root privileges. If you do have sudo access, you can try:
   ```bash
   # For Ubuntu/Debian
   sudo apt install python3-venv
   
   # For Ubuntu 20.04+ with specific Python version
   sudo apt install python3.10-venv  # Replace 3.10 with your Python version
   
   # For CentOS/RHEL
   sudo yum install python3-devel
   ```

4. Create a virtual environment:
   ```bash
   python3 -m venv venv
   ```
   
   If you encounter the error "ensurepip is not available," it means the Python venv package is not installed. Ask your hosting provider to install it for you, or if you have sufficient privileges, use the commands in step 3.

5. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```

6. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### 4. Database Configuration

1. In cPanel, go to **Databases** > **MySQL Databases** or **PostgreSQL Databases**.
2. Create a new database (e.g., `username_streamlite`).
3. Create a new database user and set a secure password.
4. Add the user to the database with all privileges.
5. Note down the database name, username, and password.

### 5. Creating and Managing Environment Configuration

Create a `.env` file in your application directory with the following content:

```
# Database Configuration (for MySQL)
DATABASE_URL="mysql://username_streamuser:password@localhost/username_streamlite"

# OR for PostgreSQL
# DATABASE_URL="postgresql://username_streamuser:password@localhost/username_streamlite"

# Application Settings
FLASK_APP=app.py
FLASK_ENV=production
SESSION_SECRET="your-secure-random-string"
UPLOAD_FOLDER="/home/username/public_html/streamlite/uploads"
ALLOWED_EXTENSIONS=jpg,jpeg,png,mp4,mkv,avi,mov,webm,mp3,ogg,wav
LOG_LEVEL=INFO

# RTMP Settings (if using RTMP)
RTMP_SERVER=rtmp://yourdomain.com/live
```

Replace the placeholders with your actual credentials and paths.

#### Managing Environment Variables in cPanel

There are several ways to update your environment variables in cPanel:

1. **Using File Manager**:
   - Go to cPanel > **File Manager**
   - Navigate to your application directory
   - Right-click on the `.env` file and select **Edit**
   - Make your changes and save the file
   - Restart your Python application

2. **Using SSH**:
   - Connect to your server via SSH
   - Use a text editor like nano or vim to edit the file:
     ```bash
     nano /home/username/public_html/streamlite/.env
     ```
   - Make your changes, save the file, and exit the editor
   - Restart your application

3. **Using Environment Variables in Python App Configuration**:
   - In cPanel > **Setup Python App**
   - Select your application
   - Under **Environment Variables**, you can add key-value pairs
   - These variables will be available to your application without needing a `.env` file
   - Note: This approach is only for select environment variables; for full configuration, the `.env` file is recommended

### 6. Initializing the Database

1. Connect to your server via SSH.
2. Navigate to your application directory:
   ```bash
   cd ~/public_html/streamlite
   ```
3. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```
4. Run the initialization script:
   ```bash
   python initialize.py
   ```

### 7. Setting Up Passenger for Production (Recommended)

cPanel uses Passenger to run Python applications in production:

1. Create a `passenger_wsgi.py` file in your application directory:
   ```python
   import os
   import sys
   
   # Add your virtual environment's site-packages to path
   VENV_PATH = os.path.join(os.getcwd(), 'venv')
   SITE_PACKAGES = os.path.join(VENV_PATH, 'lib', 'python3.8', 'site-packages')
   sys.path.insert(0, SITE_PACKAGES)
   
   # Set environment variables
   from dotenv import load_dotenv
   load_dotenv()
   
   # Import your Flask application
   from main import app as application
   ```

2. Restart Python application from cPanel interface:
   - Go to **Software** > **Setup Python App**
   - Select your application
   - Click on **Restart App**

### 8. SSL Configuration

To secure your application with SSL:

1. In cPanel, go to **Security** > **SSL/TLS**.
2. Choose **Generate, view, upload, or delete SSL certificates**.
3. Generate or upload your SSL certificate.
4. Go back to **SSL/TLS** and click on **Install and Manage SSL for your site (HTTPS)**.
5. Select your domain and install the certificate.

### 9. RTMP Setup for Live Streaming (Optional)

If you need RTMP for live streaming, you'll need a custom Nginx build with RTMP module. This usually requires root access or assistance from your hosting provider:

1. Contact your hosting provider to enable Nginx with RTMP module.
2. Once enabled, create an Nginx configuration similar to the sample in `sample_nginx.conf`.

### 10. Final Steps

1. Test your application by accessing your domain in a web browser.
2. Log in with the default admin credentials:
   - Username: `admin`
   - Password: `streamlite_admin` (change this immediately!)
3. Go to Admin → Site Settings to customize your streaming platform.

## Troubleshooting

### Common Issues in cPanel

1. **500 Internal Server Error**:
   - Check the error logs in cPanel's **Metrics** > **Error Log**.
   - Ensure file permissions are correct (755 for directories, 644 for files).
   - Verify the `.env` file contains the correct paths.

2. **Python Application Not Starting**:
   - Ensure your `passenger_wsgi.py` is configured correctly.
   - Check the Python version in the virtual environment matches the one selected in the Python App interface.

3. **Database Connection Issues**:
   - Verify the database credentials in your `.env` file.
   - Ensure the database user has the correct permissions.

4. **File Upload Problems**:
   - Check the permissions on your upload directory.
   - Ensure your PHP settings allow for file uploads of your desired size.

For additional help, refer to the cPanel documentation or contact your hosting provider for assistance with cPanel-specific issues.