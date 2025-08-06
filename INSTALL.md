# StreamLite Installation Guide

This guide provides instructions for installing StreamLite on various hosting panels including cPanel, AaPanel, and CyberPanel.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
  - [Automatic Installation Script](#automatic-installation-script)
  - [Manual Installation](#manual-installation)
- [Panel-Specific Instructions](#panel-specific-instructions)
  - [cPanel](#cpanel)
  - [AaPanel](#aapanel)
  - [CyberPanel](#cyberpanel)
- [Configuration](#configuration)
  - [Database Setup](#database-setup)
  - [Web Server Configuration](#web-server-configuration)
  - [RTMP Streaming Setup](#rtmp-streaming-setup)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing StreamLite, ensure your server has the following:

- Ubuntu 20.04 LTS or later (recommended)
- Python 3.8 or later
- PostgreSQL 12 or later (recommended) or MySQL 8.0+
- Nginx with RTMP module
- FFmpeg
- Sufficient disk space (at least 2GB)
- A domain name pointed to your server

## Installation Methods

### Automatic Installation Script

The fastest way to install StreamLite is using our automatic installation script:

1. Download the application files to your server:
   ```bash
   git clone https://github.com/your-repo/streamlite.git
   cd streamlite
   ```

2. Make the installation script executable:
   ```bash
   chmod +x install.sh
   ```

3. Run the installation script:
   ```bash
   ./install.sh
   ```

4. Follow the on-screen instructions to complete the setup.

### Manual Installation

For advanced users who want more control over the installation process:

1. Create a Python virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

2. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure the database connection in `.env` file.

4. Initialize the database:
   ```bash
   python initialize.py
   ```

5. Set up your web server (Nginx/Apache) to serve the application.

6. Configure a process manager (systemd/supervisor) to keep the application running.

## Panel-Specific Instructions

We provide detailed, step-by-step guides for installation on popular hosting panels. Please refer to the appropriate guide in the HOSTING_GUIDES directory:

- [cPanel Installation Guide](HOSTING_GUIDES/cPanel_Installation.md) - Complete instructions for cPanel users
- [AaPanel Installation Guide](HOSTING_GUIDES/AaPanel_Installation.md) - Detailed guide for AaPanel installations
- [Environment Variables Guide](HOSTING_GUIDES/Environment_Variables_Guide.md) - How to manage environment variables across different platforms

### Brief Overview by Panel

#### cPanel

1. **Create a Python Application** using the Setup Python App interface
2. **Set up a PostgreSQL or MySQL database** via the cPanel Database tools
3. **Configure environment variables** in the `.env` file
4. **Set up Passenger** for process management
5. **Configure SSL** using Let's Encrypt in cPanel

For full details, see the [cPanel Installation Guide](HOSTING_GUIDES/cPanel_Installation.md).

#### AaPanel

1. **Set up a website** for your domain
2. **Install Python and Supervisor** from the App Store
3. **Create a PostgreSQL or MySQL database** via AaPanel Database tools
4. **Configure Nginx** with our template configuration
5. **Set up Supervisor** to manage the application process

For full details, see the [AaPanel Installation Guide](HOSTING_GUIDES/AaPanel_Installation.md).

#### CyberPanel

1. **Create a website** for your domain
2. **Set up Python environment** using SSH
3. **Configure database** through CyberPanel interface
4. **Modify Nginx configuration** for your StreamLite application
5. **Enable SSL** via CyberPanel's built-in Let's Encrypt integration

For CyberPanel installations, refer to the general steps in this guide along with the [Environment Variables Guide](HOSTING_GUIDES/Environment_Variables_Guide.md).

## Configuration

### Environment and Database Configuration

The `.env` file contains your application configuration including database credentials. Update it with your actual information:

```
# Database Configuration
DATABASE_URL="postgresql://username:password@localhost/streamlite"
PGDATABASE="streamlite"
PGUSER="db_username"
PGPASSWORD="db_password"
PGHOST="localhost"
PGPORT=5432
```

For MySQL:
```
DATABASE_URL="mysql://username:password@localhost/streamlite"
```

For comprehensive information about managing environment variables across different hosting platforms, including updating them after installation, please refer to our [Environment Variables Guide](HOSTING_GUIDES/Environment_Variables_Guide.md).

### Web Server Configuration

Our installation script creates a sample Nginx configuration file. You'll need to:

1. Update the `server_name` directive with your actual domain
2. Update the SSL certificate paths to point to your actual certificates
3. Ensure the file paths are correct for your server setup
4. Enable the configuration file in Nginx

Sample Nginx configuration file location: `nginx_config.conf`

### RTMP Streaming Setup

For live streaming functionality:

1. Ensure Nginx is compiled with the RTMP module
2. Configure the RTMP section in the Nginx configuration
3. Create HLS and DASH directories with proper permissions
4. Update the `.env` file with the correct RTMP server URL

## Troubleshooting

### Common Issues

1. **Application doesn't start**:
   - Check if Python and dependencies are correctly installed
   - Verify the virtual environment is activated
   - Check for errors in the application logs

2. **Database connection errors**:
   - Verify database credentials in `.env` file
   - Ensure the database server is running
   - Check database user permissions

3. **Live streaming doesn't work**:
   - Verify Nginx is compiled with RTMP module
   - Check if the RTMP port (1935) is open in your firewall
   - Ensure correct streaming key is being used

4. **Upload functionality issues**:
   - Check directory permissions for the uploads folder
   - Verify the `UPLOAD_FOLDER` path in the `.env` file
   - Ensure proper file size limits are set in Nginx

### Getting Help

If you encounter issues not covered in this guide:

1. Check the application logs in the `logs` directory
2. Review the Nginx error logs
3. Contact our support team at support@streamlite.example.com

## Post-Installation

After successful installation:

1. Access your StreamLite application at `https://yourdomain.com`
2. Log in with the default admin credentials:
   - Username: `admin`
   - Password: `streamlite_admin` (change this immediately!)
3. Go to Admin → Site Settings to customize your streaming platform
4. Create categories and set up your initial content structure

---

Thank you for installing StreamLite! We hope you enjoy your new streaming platform.