# PostgreSQL Configuration Guide for StreamLite

This guide provides detailed instructions for setting up and troubleshooting PostgreSQL with StreamLite, especially when deploying in environments like AaPanel, cPanel, or CyberPanel.

## Initial PostgreSQL Setup

### Installation

If PostgreSQL is not already installed:

#### On Debian/Ubuntu:
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib
```

#### On CentOS/RHEL:
```bash
# Install PostgreSQL
sudo yum install -y postgresql-server postgresql-contrib
sudo postgresql-setup initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Creating Database and User

1. Connect to PostgreSQL as the postgres user:
```bash
sudo -u postgres psql
```

2. Create a database and user:
```sql
CREATE DATABASE streamlite;
CREATE USER streamlite WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE streamlite TO streamlite;
```

3. Give the user proper permissions (critical for StreamLite):
```sql
ALTER USER streamlite WITH SUPERUSER;
\c streamlite
GRANT ALL ON SCHEMA public TO streamlite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO streamlite;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO streamlite;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO streamlite;
```

4. Exit PostgreSQL:
```sql
\q
```

## Common PostgreSQL Permission Issues

### Schema Public Permission Denied

**Problem**: When trying to create tables, you get:
```
ERROR:  permission denied for schema public
LINE 1: CREATE TABLE user (
```

**Solution**:

This is usually due to PostgreSQL configurations that restrict the public schema. Follow these steps:

1. Connect to PostgreSQL as the postgres user:
```bash
sudo -u postgres psql
```

2. Grant permissions to the user:
```sql
ALTER USER streamlite WITH SUPERUSER;
\c streamlite
GRANT ALL ON SCHEMA public TO streamlite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO streamlite;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO streamlite;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO streamlite;
```

3. If still having issues, modify PostgreSQL's schema creation privileges:
```sql
\c postgres
ALTER DATABASE streamlite OWNER TO streamlite;
```

### Streamlite User Cannot Create Tables

**Problem**: The application can connect but cannot create tables.

**Solution**:

1. Grant create permissions:
```bash
sudo -u postgres psql
\c streamlite
GRANT CREATE ON SCHEMA public TO streamlite;
```

2. If that doesn't work, check ownership:
```sql
SELECT schema_name, schema_owner FROM information_schema.schemata WHERE schema_name = 'public';
```

3. Change ownership if needed:
```sql
ALTER SCHEMA public OWNER TO streamlite;
```

## PostgreSQL Connection Issues

### Unable to Connect to PostgreSQL

**Problem**: The application cannot connect to PostgreSQL:
```
sqlalchemy.exc.OperationalError: (psycopg2.OperationalError) could not connect to server
```

**Solution**:

1. Check PostgreSQL is running:
```bash
sudo systemctl status postgresql
```

2. Verify PostgreSQL connection settings in `pg_hba.conf`:
```bash
# On Debian/Ubuntu
sudo nano /etc/postgresql/13/main/pg_hba.conf
# On RHEL/CentOS
sudo nano /var/lib/pgsql/13/data/pg_hba.conf
```

3. Add or modify these lines to allow local connections:
```
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
```

4. Restart PostgreSQL:
```bash
sudo systemctl restart postgresql
```

### Authentication Failed

**Problem**: You get authentication errors:
```
FATAL: password authentication failed for user "streamlite"
```

**Solution**:

1. Reset the user's password:
```bash
sudo -u postgres psql
ALTER USER streamlite WITH PASSWORD 'new_secure_password';
\q
```

2. Update your `.env` file with the new password:
```
DATABASE_URL="postgresql://streamlite:new_secure_password@localhost/streamlite"
PGPASSWORD="new_secure_password"
```

3. Verify you can connect manually:
```bash
psql -U streamlite -d streamlite -h localhost
```

## Managing PostgreSQL in Control Panels

### AaPanel PostgreSQL Management

1. Install PostgreSQL via AaPanel's App Store.

2. Access PostgreSQL Manager through AaPanel's interface.

3. Create a database and user through the PostgreSQL Manager interface.

4. For command line access:
```bash
su - postgres
psql
```

5. Configure remote access (if needed):
```bash
# Edit postgresql.conf
nano /var/lib/pgsql/13/data/postgresql.conf
```

6. Change the listen address:
```
listen_addresses = '*'  # Be cautious with this setting
```

7. Restart PostgreSQL through AaPanel or command line:
```bash
systemctl restart postgresql-13
```

### cPanel PostgreSQL Management

1. In cPanel, use the PostgreSQL Database Wizard to create databases and users.

2. When connecting from StreamLite, use the full database name:
```
username_databasename
```

3. For troubleshooting permissions, you may need to contact your hosting provider as command-line access to PostgreSQL may be restricted.

### CyberPanel PostgreSQL Management

1. Install PostgreSQL from the CyberPanel interface if not already installed.

2. Use the Database Manager to create a database and user.

3. For command line access (after SSH login):
```bash
sudo -u postgres psql
```

4. For proper StreamLite integration, add the permissions as described earlier:
```sql
ALTER USER your_user WITH SUPERUSER;
\c your_database
GRANT ALL ON SCHEMA public TO your_user;
```

## Database Backups and Maintenance

### Creating Database Backups

1. Create a backup of the database:
```bash
pg_dump -U postgres -d streamlite > streamlite_backup.sql
```

2. For a compressed backup:
```bash
pg_dump -U postgres -d streamlite | gzip > streamlite_backup.sql.gz
```

### Restoring from Backup

1. Create the database if it doesn't exist:
```bash
sudo -u postgres psql -c "CREATE DATABASE streamlite;"
```

2. Restore from a backup:
```bash
psql -U postgres -d streamlite < streamlite_backup.sql
```

3. For compressed backups:
```bash
gunzip -c streamlite_backup.sql.gz | psql -U postgres -d streamlite
```

### Scheduled Maintenance

1. For automatic vacuuming, ensure autovacuum is enabled in postgresql.conf:
```
autovacuum = on
```

2. Set up a scheduled backup using cron:
```bash
# Edit crontab
crontab -e

# Add a daily backup at 2 AM
0 2 * * * pg_dump -U postgres -d streamlite | gzip > /backup/streamlite_$(date +\%Y\%m\%d).sql.gz
```

## Optimizing PostgreSQL for StreamLite

### Connection Pooling

StreamLite uses SQLAlchemy with connection pooling. In app.py, you'll see:

```python
app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
    "pool_recycle": 300,
    "pool_pre_ping": True,
    "pool_size": 10,
    "max_overflow": 20
}
```

These settings are generally good for most deployments. For high-traffic sites, consider increasing pool_size and max_overflow.

### Performance Tuning

Edit your postgresql.conf file to optimize for your server:

```
# Memory settings
shared_buffers = 256MB           # Increase for more memory
work_mem = 16MB                  # Increase for complex queries
maintenance_work_mem = 64MB      # For maintenance operations

# Write-ahead Log
wal_buffers = 8MB                # Helps with transaction throughput

# Background Writer
bgwriter_delay = 200ms           # Balance between CPU and write smoothing

# Query Planner
random_page_cost = 3.0           # Lower if using SSD

# Disk I/O
effective_io_concurrency = 2     # Increase for SSDs
```

The values should be adjusted based on your server's available resources.

## Advanced PostgreSQL Management for StreamLite

### Monitoring Database Size

Check the size of your StreamLite database:
```sql
SELECT pg_size_pretty(pg_database_size('streamlite'));
```

Check the size of specific tables:
```sql
SELECT relname as "Table",
  pg_size_pretty(pg_total_relation_size(relid)) As "Size"
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

### Finding Slow Queries

Enable query logging in postgresql.conf:
```
log_min_duration_statement = 200  # Log queries taking more than 200ms
```

### Setting Up Read Replicas

For high-traffic deployments, you can set up read replicas:

1. Configure primary server (postgresql.conf):
```
wal_level = replica
max_wal_senders = 10
```

2. Configure replica server:
```
primary_conninfo = 'host=primary_server_ip port=5432 user=replication_user password=password'
```

3. Modify your StreamLite application to distribute read queries to replicas.

## Troubleshooting Connection String Issues

### SQLAlchemy Connection String Format

If you're having issues connecting, verify your connection string format:

1. Standard format:
```
postgresql://username:password@hostname/database
```

2. With explicit port:
```
postgresql://username:password@hostname:5432/database
```

3. With additional parameters:
```
postgresql://username:password@hostname/database?client_encoding=utf8
```

### Testing Connection String

Test your connection string with a simple Python script:

```python
import psycopg2

# Replace with your actual connection details
conn_string = "dbname='streamlite' user='streamlite' password='your_password' host='localhost'"

try:
    conn = psycopg2.connect(conn_string)
    cursor = conn.cursor()
    cursor.execute("SELECT version();")
    db_version = cursor.fetchone()
    print("PostgreSQL version:", db_version)
    cursor.close()
    conn.close()
    print("Connection successful!")
except Exception as e:
    print("Connection failed:", e)
```

## PostgreSQL Version Compatibility

StreamLite works well with PostgreSQL 10 and above. If using PostgreSQL 15+, ensure that SQLAlchemy and psycopg2 are up to date:

```bash
pip install --upgrade sqlalchemy psycopg2-binary
```

For older Python versions, you might need to specify compatible versions:

```bash
pip install "sqlalchemy<2.0" "psycopg2-binary<2.9"
```

By following this guide, you should be able to successfully set up, configure, and troubleshoot PostgreSQL for your StreamLite deployment.