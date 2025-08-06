# Managing Environment Variables in StreamLite

This guide explains how to manage environment variables for your StreamLite installation across different hosting platforms.

> **Important Note**: StreamLite requires a Python virtual environment for proper functioning. If you encounter the error "ensurepip is not available" when creating a virtual environment, you need to install the Python venv package:
> 
> ```bash
> # For Ubuntu/Debian
> sudo apt install python3-venv
> 
> # For specific Python versions on Ubuntu 20.04+
> sudo apt install python3.10-venv  # Replace 3.10 with your Python version
> 
> # For CentOS/RHEL
> sudo yum install python3-devel
> ```

## Understanding Environment Variables

Environment variables are a set of key-value pairs that configure your StreamLite application. They control database connections, application settings, security keys, and more without requiring code changes.

### Important Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| DATABASE_URL | Database connection string | `postgresql://user:password@localhost/dbname` |
| SESSION_SECRET | Secret key for session security | `your-secure-random-string` |
| UPLOAD_FOLDER | Path to file uploads | `/path/to/uploads` |
| ALLOWED_EXTENSIONS | File types allowed for upload | `jpg,jpeg,png,mp4,mkv` |
| RTMP_SERVER | RTMP server URL for streaming | `rtmp://yourdomain.com/live` |
| LOG_LEVEL | Logging verbosity | `INFO` |

## The .env File

StreamLite uses a `.env` file in the application's root directory to store environment variables. This file looks like:

```
# Database Configuration
DATABASE_URL="postgresql://username:password@localhost/streamlite"
PGDATABASE="streamlite"
PGUSER="streamlite_user"
PGPASSWORD="your_password"
PGHOST="localhost"
PGPORT=5432

# Application Settings
FLASK_APP=app.py
FLASK_ENV=production
SESSION_SECRET="your-secure-random-string"
UPLOAD_FOLDER="/path/to/uploads"
ALLOWED_EXTENSIONS=jpg,jpeg,png,mp4,mkv,avi,mov,webm,mp3,ogg,wav
LOG_LEVEL=INFO

# RTMP Settings
RTMP_SERVER=rtmp://yourdomain.com/live
```

## Updating Environment Variables on Different Hosting Platforms

### Standard VPS/Dedicated Server

On a standard Linux server:

1. **Using a text editor**:
   ```bash
   nano /path/to/streamlite/.env
   ```
   Make your changes, save (Ctrl+O), and exit (Ctrl+X).

2. **Using environment variables in systemd**:
   Edit the service file:
   ```bash
   sudo nano /etc/systemd/system/streamlite.service
   ```
   
   Add environment variables in the `[Service]` section:
   ```
   [Service]
   Environment="DATABASE_URL=postgresql://user:password@localhost/streamlite"
   Environment="SESSION_SECRET=your-secure-key"
   ```
   
   Reload systemd and restart the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart streamlite
   ```

### cPanel

1. **Using File Manager**:
   - Go to cPanel > **File Manager**
   - Navigate to your application directory
   - Edit the `.env` file
   - Save changes and restart your application

2. **Using Python App Environment Variables**:
   - In cPanel > **Setup Python App**
   - Select your application
   - Add environment variables in the provided interface
   - Restart the application

### AaPanel

1. **Using File Manager**:
   - In AaPanel, go to **Files**
   - Navigate to your website directory
   - Edit the `.env` file
   - Save changes

2. **Using Supervisor**:
   - In AaPanel, go to **App Store** > **Supervisor**
   - Select your StreamLite application
   - Edit the environment variables section
   - Restart the application

### Docker (If Using Containerized Deployment)

1. **Using .env file**:
   - Update the `.env` file before building your Docker image
   - Or mount the `.env` file as a volume

2. **Using Docker environment variables**:
   ```bash
   docker run -e DATABASE_URL=postgresql://user:pass@host/db -e SESSION_SECRET=key streamlite
   ```

3. **Using docker-compose**:
   ```yaml
   version: '3'
   services:
     streamlite:
       image: streamlite
       environment:
         - DATABASE_URL=postgresql://user:pass@host/db
         - SESSION_SECRET=your-secure-key
   ```

## Common Configuration Changes

### Changing Database Connection

If you need to change your database connection:

1. Update the `DATABASE_URL` in your `.env` file:
   ```
   DATABASE_URL="postgresql://new_user:new_password@new_host/new_database"
   ```

2. If using PostgreSQL, also update individual parameters:
   ```
   PGDATABASE="new_database"
   PGUSER="new_user"
   PGPASSWORD="new_password"
   PGHOST="new_host"
   ```

### Changing Upload Limits

To change file upload size limits:

1. Update the `max_upload_size_mb` in your site settings through the admin panel.

2. Ensure your web server configuration also allows larger uploads:
   - For Nginx, set `client_max_body_size 500M;` in your server block
   - For Apache, set `LimitRequestBody 524288000` (in bytes) in your virtual host

### Adding Custom RTMP Settings

If you need to configure custom RTMP settings:

1. Update the `RTMP_SERVER` variable in your `.env` file:
   ```
   RTMP_SERVER="rtmp://your-new-rtmp-server/live"
   ```

2. Update your Nginx RTMP module configuration to match

## Security Considerations

1. **Never commit `.env` files to version control**
2. **Use strong, random values for SECRET_KEY**
3. **Limit access to the `.env` file to only necessary users**
4. **Consider using a secret management service for production deployments**

## Troubleshooting

If changes to environment variables don't take effect:

1. **Verify the application was restarted** after updating variables
2. **Check for syntax errors** in your `.env` file (missing quotes, etc.)
3. **Verify file permissions** on the `.env` file (should be readable by the application user)
4. **Check application logs** for any error messages related to configuration

For more help, refer to the hosting-specific guides in the HOSTING_GUIDES directory.