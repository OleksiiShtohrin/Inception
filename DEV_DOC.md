# Inception — Developer Documentation

## 1. Project Overview

Inception is a Docker-based infrastructure project developed as part of the 42 curriculum.

The infrastructure consists of seven long-running services and one on-demand backup job:

```text
                         HOST MACHINE
                 ┌──────────────────────────┐
                 │ HTTPS :443               │
                 │ FTP :21, :21100-21110    │
                 └────────────┬─────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │      NGINX      │
                     │   TLS 1.2/1.3   │
                     └────────┬────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
                ▼             ▼             ▼
          WordPress        Adminer     Static Website
          PHP-FPM          PHP-FPM     NGINX :80
                │             │             │
                └──────┬──────┘             │
                       │              /static/ proxy
                       ▼                    │
                  ┌─────────┐               │
                  │ MariaDB │               │
                  │  :3306  │               │
                  └─────────┘               │
                                            │
                 ┌──────────────────────────┘
                 │
                 ▼
          ┌──────────────┐
          │     FTP      │
          │  vsftpd :21  │
          └──────┬───────┘
                 │
                 ▼
          Shared WordPress files
          (wordpress_data volume)

          ┌─────────────────────────────┐
          │       Docker Network        │
          │         inception           │
          │                             │
          │ Redis — object cache        │
          │ Backup — on-demand job      │
          └─────────────────────────────┘

          Persistent data:
          - MariaDB database
          - WordPress files
          - SQL backups on the host
```

The seven long-running services are:

- **NGINX** — the public HTTPS entry point, terminates TLS and routes requests to the application and static website.
- **WordPress + PHP-FPM** — serves the WordPress website.
- **MariaDB** — stores the WordPress database.
- **Redis** — provides object caching for WordPress through the Redis Object Cache plugin.
- **Adminer** — provides a web interface for managing MariaDB through NGINX over HTTPS.
- **FTP** — provides authenticated file transfer access to the shared WordPress files.
- **Static Website** — serves static HTML and CSS through the main NGINX reverse proxy.

The backup service is a separate on-demand job. It creates SQL dumps of the MariaDB database and stores them in a host directory.

Each long-running service runs in its own dedicated Docker container. The backup container runs only when requested and exits after the job finishes.

The containers communicate through a dedicated Docker bridge network.

Persistent application data is stored using two Docker named volumes: one for MariaDB and one for WordPress files. Database backups are stored separately on the host under `/home/oshtohri/data/backups/`.

---

# 2. Prerequisites

The project is designed to run inside a Virtual Machine.

The development environment used for this project is:

- Debian 12
- Docker Engine
- Docker Compose
- GNU Make

Check the installed versions:

```bash
docker --version
docker compose version
make --version
```

The project should be executed from the repository root:

```text
Inception/
```

---

# 3. Project Structure

```text
Inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
│
├── scripts/
│   ├── check-config.sh
│   └── create-secrets.sh
│
├── secrets/                  # Local files; excluded from Git
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   ├── wp_user_password.txt
│   └── ftp_password.txt
│
└── srcs/
    ├── .env                  # Local file; excluded from Git
    ├── .env.example
    ├── docker-compose.yml
    │
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── my.cnf
        │   └── tools/
        │       └── init-db.sh
        │
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── nginx.conf
        │   └── tools/
        │       └── init-nginx.sh
        │
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── www.conf
        │   └── tools/
        │       └── init-wp.sh
        │
        └── bonus/
            ├── adminer/
            │   └── Dockerfile
            │
            ├── redis/
            │   ├── Dockerfile
            │   └── conf/
            │       └── redis.conf
            │
            ├── ftp/
            │   ├── Dockerfile
            │   ├── conf/
            │   │   └── vsftpd.conf
            │   └── tools/
            │       └── ftp-entrypoint.sh
            │
            ├── static-site/
            │   ├── Dockerfile
            │   └── html/
            │       ├── index.html
            │       └── style.css
            │
            └── backup/
                ├── Dockerfile
                └── tools/
                    └── backup.sh
```

The project separates service-specific configuration, Dockerfiles and startup
scripts into their respective service directories.

---

# 4. Environment Configuration

The project uses:

```text
srcs/.env
```

for non-sensitive configuration values.

The current configuration contains:

```dotenv
DOMAIN_NAME=oshtohri.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user

WP_ADMIN_USER=oshtohri
WP_ADMIN_EMAIL=oshtohri@example.com

WP_USER=student
WP_USER_EMAIL=student@example.com

MYSQL_HOST=mariadb
MYSQL_PORT=3306
```

`MYSQL_PORT` defines the MariaDB port used by WordPress when connecting to the database.
The default value is `3306`. The WordPress initialization script uses
`MYSQL_HOST` and `MYSQL_PORT` to configure the database connection in
`wp-config.php`.

The `.env` file is not committed to Git.

It is excluded through:

```gitignore
/srcs/.env
```

Environment variables are used for configuration because these values are not
passwords.

---

# 5. Docker Secrets

Passwords are stored separately from normal configuration.

The project uses five secret files:

```text
secrets/
├── db_password.txt
├── db_root_password.txt
├── wp_admin_password.txt
├── wp_user_password.txt
└── ftp_password.txt
```

These files are excluded from Git:

```gitignore
/secrets/
```

Docker Compose makes the secrets available inside the relevant containers under:

```text
/run/secrets/
```

The secret names available to containers include:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
/run/secrets/ftp_password
```

Each service receives only the secrets configured for it in Docker Compose. Startup scripts read the required passwords from these files.

Passwords are not hard-coded into Dockerfiles.

### Generating Secrets

The project provides a script to generate the five required secret files:

```bash
./scripts/create-secrets.sh
```

The script creates a secret only if the corresponding file does not already exist. Each generated secret contains 12 hexadecimal characters. The files are assigned permissions `600`, and the `secrets/` directory is assigned permissions `700`.

Existing secret files are preserved when the script is run again. This helps prevent accidental password changes for an already initialized database.

**Important:** Generate the secrets before the first MariaDB initialization. If MariaDB has already been initialized, changing the secret files does not automatically update the database users' passwords.

For a fresh installation, prepare the environment and secrets before starting the services:

```bash
./scripts/create-secrets.sh
make check-config
docker compose -f srcs/docker-compose.yml config -q
```

The script does not print or display the generated passwords.

---

# 6. Docker Compose

The main orchestration file is:

```text
srcs/docker-compose.yml
```

It defines seven long-running services:

```text
mariadb
wordpress
nginx
redis
adminer
ftp
static-site
```

The `backup` service is defined separately as an on-demand job. It runs when explicitly requested and exits after completing the database dump.

The Compose configuration also defines:

- the Docker network;
- the MariaDB named volume;
- the WordPress named volume;
- Docker Secrets;
- the configuration and port mappings required by each service.

NGINX publishes HTTPS port `443` to the host. FTP publishes port `21` and the passive port range `21100-21110`. The remaining services do not publish their own ports directly to the host.

WordPress, MariaDB, Redis and Adminer communicate through the Docker network. Adminer is accessed through NGINX over HTTPS at `https://oshtohri.42.fr/adminer/`. The static website is served through the main NGINX reverse proxy at `https://oshtohri.42.fr/static/`. FTP provides separate authenticated access to the shared WordPress files.

The services use their own Dockerfiles. For example:

```yaml
build:
  context: ./requirements/mariadb
  dockerfile: Dockerfile
```

and equivalent configurations for WordPress and NGINX.

The images are built locally.

No ready-made MariaDB, WordPress or NGINX service image is used as the
runtime image.

---

# 7. MariaDB Container

The MariaDB service is built from:

```text
srcs/requirements/mariadb/Dockerfile
```

The Dockerfile uses Debian 12 as its base image and installs MariaDB.

The MariaDB configuration is:

```text
srcs/requirements/mariadb/conf/my.cnf
```

The startup script is:

```text
srcs/requirements/mariadb/tools/init-db.sh
```

## Initialization

The initialization script:

1. reads the required secrets;
2. prepares the MariaDB runtime directory;
3. starts a temporary MariaDB server using a local socket;
4. waits until MariaDB is ready;
5. configures the root password;
6. creates the WordPress database;
7. creates the WordPress database user;
8. grants the required privileges;
9. creates an initialization marker;
10. shuts down the temporary server;
11. starts MariaDB as the container's main process.

The initialization marker is stored in the database volume:

```text
/var/lib/mysql/.inception_initialized
```

This makes the initialization process idempotent.

If the database already exists, the initialization phase is skipped.

The final MariaDB process is started with:

```bash
exec mariadbd --user=mysql --console
```

Therefore MariaDB runs as the main container process.

---

# 8. WordPress Container

The WordPress service is built from:

```text
srcs/requirements/wordpress/Dockerfile
```

The image contains:

- WordPress;
- PHP 8.2;
- PHP-FPM;
- required PHP extensions;
- MariaDB client utilities;
- WP-CLI.

The PHP-FPM configuration is:

```text
srcs/requirements/wordpress/conf/www.conf
```

PHP-FPM listens internally on:

```text
9000
```

The WordPress initialization script is:

```text
srcs/requirements/wordpress/tools/init-wp.sh
```

---

# 9. WordPress Initialization

The startup script performs several steps.

## Step 1 — WordPress Files

If WordPress is not already present in:

```text
/var/www/html
```

the files are copied from:

```text
/usr/src/wordpress
```

to the persistent WordPress volume.

If the files already exist, they are preserved.

---

## Step 2 — WordPress Configuration

If `wp-config.php` does not exist, WP-CLI creates it using:

- database name;
- database user;
- database password;
- MariaDB hostname.

The database password is read from:

```text
/run/secrets/db_password
```

---

## Step 3 — Database Readiness

The script checks the MariaDB connection using WP-CLI.

It performs a bounded retry loop.

The script waits for MariaDB to become available instead of assuming that
both containers start at exactly the same time.

If MariaDB does not become available within the configured retry period, the
script exits with an error.

---

## Step 4 — WordPress Installation

If WordPress is not installed, WP-CLI executes the installation.

The administrator account is created using the values from `.env` and the
administrator password from Docker Secrets.

A second WordPress user is also created.

The current users are:

```text
oshtohri  → administrator
student   → subscriber
```

---

## Step 5 — PHP-FPM

After initialization, PHP-FPM is started in foreground mode:

```bash
exec php-fpm8.2 -F
```

Using `exec` replaces the shell process with PHP-FPM.

PHP-FPM therefore becomes PID 1 of the WordPress container.

---

# 10. Redis Container

The Redis service is built from:

```text
srcs/requirements/bonus/redis/Dockerfile
```

Redis is installed on a Debian 12 base image.

The Redis configuration file is:

```text
srcs/requirements/bonus/redis/conf/redis.conf
```

The configuration specifies:

- port `6379`;
- listening on `0.0.0.0`;
- `protected-mode no`.

Redis provides object caching for WordPress through the Redis Object Cache
plugin. It is accessible through the internal Docker network and does not
publish port `6379` to the host.

Because Redis is configured with `protected-mode no`, its security depends
on network isolation and ensuring that the Redis port is not exposed outside
the Docker network.

---

# 11. NGINX Container

The NGINX service is built from:

```text
srcs/requirements/nginx/Dockerfile
```

The NGINX configuration is:

```text
srcs/requirements/nginx/conf/nginx.conf
```

The startup script is:

```text
srcs/requirements/nginx/tools/init-nginx.sh
```

NGINX is configured to listen on HTTPS port:

```text
443
```

TLS protocols are restricted to:

```text
TLSv1.2
TLSv1.3
```

NGINX forwards PHP requests for the WordPress application to:

```text
wordpress:9000
```

Adminer is available through the `/adminer/` route and its PHP requests are forwarded to the Adminer container.

The static website is available through the `/static/` route and is proxied to:

```text
http://static-site/
```

The WordPress volume is mounted read-only in the NGINX container. FTP provides a separate file-transfer path to the shared WordPress volume.

---

# 12. Adminer Container

The Adminer service is built from:

```text
srcs/requirements/bonus/adminer/Dockerfile
```

The Dockerfile uses Debian 12 and installs:

- Adminer;
- PHP 8.2-FPM;
- the PHP MySQL extension.

The container copies Adminer's application files to:

```text
/var/www/adminer/
```

PHP-FPM listens on the internal port `9000`.

NGINX forwards Adminer PHP requests to the Adminer container and serves its
static CSS and JavaScript files.

Adminer is accessible through NGINX over HTTPS at:

```text
https://oshtohri.42.fr/adminer/
```

Adminer does not publish a port directly to the host. It connects to MariaDB
through the internal Docker network.

---

# 13. TLS Certificate

The project uses a self-signed TLS certificate for the local development
environment.

The certificate and private key are generated by:

```text
init-nginx.sh
```

The files are stored inside the NGINX container under:

```text
/etc/nginx/ssl/
```

The private key is protected with restrictive filesystem permissions.

The certificate is generated only when it does not already exist.

---

# 14. FTP Container

## Overview

The FTP service provides authenticated access to the WordPress files stored in the shared `wordpress_data` volume.

The service is built from Debian 12 and uses `vsftpd` as its FTP server.

## File Structure

- `srcs/requirements/bonus/ftp/Dockerfile` — builds the FTP image.
- `srcs/requirements/bonus/ftp/conf/vsftpd.conf` — configures the FTP server.
- `srcs/requirements/bonus/ftp/tools/ftp-entrypoint.sh` — prepares the FTP environment and starts the server.

## Docker Configuration

The service uses the image `ftp:1.0` and the container name `ftp`.

It has the following configuration:

- **Restart policy:** `always`.
- **Docker network:** `inception`.
- **Secret:** `ftp_password`.
- **Shared volume:** `wordpress_data:/var/www/html`.

### Published Ports

| Host port | Container port | Purpose |
|---|---|---|
| `21` | `21` | FTP control connection |
| `21100-21110` | `21100-21110` | Passive-mode data connections |

The Dockerfile's `EXPOSE` instruction documents the container ports. The `ports` section in Docker Compose publishes these ports on the host.

## FTP Server Configuration

The `vsftpd.conf` file configures the server as follows:

- Anonymous access is disabled.
- Local-user authentication is enabled.
- File-writing operations are enabled.
- The local user is restricted to the configured FTP root.
- The FTP root is `/var/www/html`.
- Passive mode is enabled, using ports `21100-21110`.
- `seccomp_sandbox=NO` disables the vsftpd seccomp sandbox.

## Authentication and Entrypoint

The entrypoint script performs these operations:

1. Creates `/var/run/vsftpd/empty` and sets its permissions to `555`.
2. Checks that `/run/secrets/ftp_password` exists and is not empty. The container exits with an error if the secret is missing or empty.
3. Creates the `ftpuser` account if it does not already exist, using UID and GID `33`.
4. Sets the FTP user's password using the Docker secret.
5. Starts `vsftpd` in the foreground using `exec`.

The FTP password is supplied through the `ftp_password` Docker secret rather than being hardcoded in the Dockerfile.

## Shared WordPress Files

The volume mapping `wordpress_data:/var/www/html` gives the FTP service access to the same persistent files used by WordPress.

This allows authorized FTP operations to modify the website files. Changes made through FTP can therefore affect the running WordPress site.

## Security Considerations

- Anonymous access is disabled.
- The FTP user is restricted to the configured FTP root.
- The password is supplied through a Docker secret.
- `seccomp_sandbox=NO` disables an additional security mechanism in vsftpd.
- **This configuration does not enable FTP over TLS.** Standard FTP does not encrypt credentials or transferred files, so this service should be used only in a trusted development environment unless additional protection is configured.

---

# 15. Static Website Container

## Overview

The `static-site` service hosts a static website using NGINX inside a Debian 12 container.

It is built independently from the main NGINX service and communicates with other services through the `inception` Docker network.

## File Structure

- `srcs/requirements/bonus/static-site/Dockerfile` — builds the static website image.
- `srcs/requirements/bonus/static-site/html/` — contains the static website files copied into the image.

## Dockerfile

The Dockerfile performs the following operations:

1. Uses `debian:12` as the base image.
2. Updates the package lists and installs NGINX without installing recommended packages.
3. Removes the package-list cache to reduce the resulting image size.
4. Copies the contents of `html/` to `/var/www/html/` inside the image.
5. Documents port `80` using the `EXPOSE` instruction.
6. Starts NGINX in the foreground using `nginx -g "daemon off;"`.

The resulting image is tagged `static-site:1.0`.

## Networking and Reverse Proxy

The container listens on port `80` and joins the `inception` Docker network.

The service does not publish a host port. Instead, the main NGINX service forwards requests to the static website using the internal service address `http://static-site/`.

The website is available through the main HTTPS endpoint:

`https://oshtohri.42.fr/static/`

This architecture allows the static website to be served through the main NGINX entry point without exposing the static-site container directly on a host port.

## Runtime

The container uses `restart: always` in Docker Compose. NGINX runs as the container's main foreground process, allowing Docker to track the service process.

## NGINX Reverse Proxy Configuration

The main NGINX configuration is stored in `srcs/requirements/nginx/conf/nginx.conf`.

The configuration handles the static website through two location blocks:

- `location = /static` returns an HTTP `301` redirect to `/static/`.
- `location ^~ /static/` forwards requests to `http://static-site/`.

Because the `proxy_pass` URL ends with `/`, NGINX replaces the matched `/static/` prefix with `/` when forwarding the request.

For example, a request for `/static/css/style.css` is forwarded to the static-site container as `/css/style.css`.

The proxy also forwards the original `Host` header and client/request metadata using `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto`.

---

# 16. Backup Container

## Overview

The backup service creates SQL dumps of the configured MariaDB database.

It is designed as an on-demand job rather than a continuously running service. The Docker Compose configuration uses `restart: "no"`, so the container is not automatically restarted after it exits.

## File Structure

- `srcs/requirements/bonus/backup/Dockerfile` — builds the backup image.
- `srcs/requirements/bonus/backup/tools/backup.sh` — contains the backup procedure.

## Docker Image

The image is based on Debian 12 and installs `mariadb-client`, which provides the client utilities needed to check database availability and create SQL dumps.

The image copies `backup.sh` to `/usr/local/bin/backup.sh`, makes it executable, and configures it as the container entrypoint.

The resulting image is tagged `backup:1.0`.

## Configuration and Authentication

The script requires `MYSQL_DATABASE` and `MYSQL_USER`. If either variable is missing, the script exits with an error.

`MYSQL_HOST` and `MYSQL_PORT` have default values of `mariadb` and `3306`, respectively, when they are unset.

The database password is read from the Docker secret at `/run/secrets/db_password`. The script exits with an error if the secret is missing or empty.

## Backup Procedure

The script performs the following operations:

1. Reads the database connection settings.
2. Verifies that the password secret exists and is not empty.
3. Creates the backup directory if necessary.
4. Generates a timestamp and constructs a filename in the format `<database>_YYYYMMDD_HHMMSS.sql`.
5. Waits for MariaDB to become available using `mariadb-admin ping`, retrying every two seconds.
6. Runs `mariadb-dump` with `--single-transaction`, `--routines`, and `--triggers`.
7. Sets the resulting file permissions to `600` and reports the file path.

If the dump command fails, the script removes the incomplete output file, prints an error message to standard error, and exits with a non-zero status.

The readiness-check loop has no retry limit or timeout.

## Persistent Backup Storage

The host backup directory is `/home/oshtohri/data/backups/`, mounted into the container at `/backups`.

Backup files are stored outside the container's writable layer, allowing them to remain available after the backup container exits or is removed.

The backup directory is separate from the MariaDB and WordPress data directories.

## Running a Backup

Run the backup job manually from the project root:

`docker compose -f srcs/docker-compose.yml run --rm backup`

The `run` command creates a one-off container from the backup service configuration. The `--rm` option removes the container after it exits, while the SQL dump remains in the mounted host backup directory.

The backup service is not configured with an automatic schedule.

## Security and Recovery Considerations

- The database password is supplied through a Docker secret.
- Successful dump files are created with permissions `600`.
- Backup files may contain sensitive website and database information and must be protected accordingly.
- Creating a dump does not by itself prove that it can be restored successfully. Restoration should be tested separately.
- The backup job does not currently implement a retention policy or automatically delete older successful backups.

---

# 17. Docker Network

The project uses a dedicated Docker bridge network:

```text
inception
```

Docker Compose creates the actual project network using the Compose project
name.

The containers communicate internally using service names.

Examples:

```text
wordpress → mariadb:3306
nginx     → wordpress:9000
```

No host networking is used.

The project does not use:

```text
network: host
--link
links:
```

NGINX publishes HTTPS port `443` to the host. FTP separately publishes port `21` and the passive port range `21100-21110`.

The remaining services do not publish their ports directly to the host. They communicate through the Docker bridge network using service names and internal ports.

---

# 18. Persistent Volumes

The project uses two Docker named volumes:

```text
mariadb_data
wordpress_data
```

The MariaDB volume is mounted inside the MariaDB container at:

```text
/var/lib/mysql
```

The WordPress volume is mounted at:

```text
/var/www/html
```

NGINX mounts the WordPress volume read-only:

```text
/var/www/html:ro
```

The named volumes are configured with Docker's local volume driver so that
their data is stored under:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

The project uses Docker named volumes rather than declaring direct host-path
bind mounts in the service volume definitions.

Database backups are stored separately from the named volumes in the host directory:

```text id="b91zcp"
/home/oshtohri/data/backups/
```

The backup service mounts this directory at `/backups` inside its container. This allows SQL dump files to remain on the host independently of the backup container's lifecycle.

---

# 19. Persistence Model

Container lifecycle and application data lifecycle are separated.

Removing containers does not automatically delete the persistent application data stored in the host directories.

For example:

```bash
make down
make up
```

removes and recreates the containers while preserving the database and WordPress files.

The command:

```bash
make clean
```

stops and removes the containers and requests removal of the Docker named volumes using `docker compose down -v`.

The project configures these volumes with the local driver and host-directory bind options. With this configuration, the data directories are managed on the host. The exact behavior of volume removal depends on the volume configuration and Docker implementation, so important data should be backed up before cleanup operations.

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

To delete the persistent application data, use:

```bash
make fclean
```

**Warning:** `make fclean` deletes the contents of the MariaDB and WordPress data directories. This can permanently remove the database and WordPress files.

The backup directory is separate:

```text
/home/oshtohri/data/backups/
```

The current `make fclean` target does not delete the contents of this backup directory. However, a backup should not be considered valid until its contents and restoration procedure have been verified.

---

# 20. Makefile

The Makefile is located at:

```text
Makefile
```

The Compose command is defined as:

```makefile
COMPOSE = docker compose -f srcs/docker-compose.yml
```

Available targets:

### `make check-config`

Validates the required environment variables and Docker Secrets before the infrastructure is started.

```bash
make check-config
```

### `make prepare`

Creates the host directories used for persistent MariaDB and WordPress data.

```bash
make prepare
```

### `make`

Builds the images and starts the complete infrastructure.

```bash
make
```

### `make build`

Builds the Docker images without starting the services.

```bash
make build
```

### `make up`

Starts the services in detached mode, creating containers when necessary.

```bash
make up
```

### `make down`

Stops and removes containers.

```bash
make down
```

### `make re`

Stops the containers and starts the infrastructure again with rebuilt images. Persistent application data is not intentionally deleted by this target.

```bash
make re
```

### `make clean`

Stops the project and removes Docker volumes.

```bash
make clean
```

### `make fclean`

Stops the project, removes Docker volumes, and deletes the contents of the
persistent data directories.

```bash
make fclean
```

This is a destructive operation and should only be used when a complete
reset of the project data is intended.

**Warning:** `make fclean` is destructive. It removes Docker volumes and deletes the contents of `/home/oshtohri/data/mariadb` and `/home/oshtohri/data/wordpress`. Do not run it unless you intentionally want to erase the persistent database and WordPress files.

---

# 21. Container Restart Policy

The seven long-running services use:

```yaml
restart: always
```

This instructs Docker to restart a container if its main process exits, subject to Docker's restart-policy behavior.

The long-running services are:

```text
mariadb
wordpress
nginx
redis
adminer
ftp
static-site
```

The `backup` service uses `restart: "no"` because it is an on-demand job. It runs when explicitly requested and exits after the backup operation finishes.

---

# 22. PID 1 and Container Processes

The project avoids using artificial infinite-loop commands to keep containers
alive.

The containers run their actual services as their main processes.

The main processes of the long-running containers are:

```text
MariaDB       → mariadbd
WordPress     → php-fpm8.2 -F
NGINX         → nginx -g "daemon off;"
Redis         → redis-server
Adminer       → php-fpm8.2 -F
FTP           → vsftpd
Static Website → nginx -g "daemon off;"
```

The backup container runs its backup script and exits after the operation finishes.

This follows the container model where the main application process remains
the foreground process of the container.

Commands such as the following are not used as container keep-alive
mechanisms:

```text
tail -f
sleep infinity
while true
```

---

# 23. Build Process

Build all images:

```bash
make build
```

The resulting images can be checked with:

```bash
docker images
```

The project uses explicit image tags:

```text
mariadb:1.0
wordpress:1.0
nginx:1.0
redis:1.0
adminer:1.0
ftp:1.0
static-site:1.0
backup:1.0
```

The `latest` tag is not used.

---

# 24. Starting the Infrastructure

The normal development workflow is:

```bash
make
```

Then verify:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected long-running services:

```text
mariadb
wordpress
nginx
redis
adminer
ftp
static-site
```

The `backup` service is not expected to remain running because it is an on-demand job.

Check the logs if necessary:

```bash
docker compose -f srcs/docker-compose.yml logs
```

---

# 25. Configuration Validation

Before starting the infrastructure, the Compose configuration can be
validated with:

```bash
docker compose -f srcs/docker-compose.yml config
```

This is useful for detecting:

- YAML errors;
- invalid variable substitutions;
- incorrect service definitions;
- invalid volume definitions;
- invalid secret definitions;
- invalid network configuration.

---

# 26. Debugging

## Container status

```bash
docker compose -f srcs/docker-compose.yml ps
```

## Service logs

```bash
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

## Follow logs

```bash
docker compose -f srcs/docker-compose.yml logs -f
```

## Enter a container

For example:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress bash
```

or:

```bash
docker compose -f srcs/docker-compose.yml exec mariadb bash
```

The shell should only be used for debugging or inspection. It is not used as
the container's main process.

---

# 27. Checking WordPress

WP-CLI can be used inside the WordPress container.

List WordPress users:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp user list \
    --path=/var/www/html \
    --allow-root
```

Check the WordPress database:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp db check \
    --path=/var/www/html \
    --allow-root
```

Check whether WordPress is installed:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp core is-installed \
    --path=/var/www/html \
    --allow-root
```

---

# 28. Checking MariaDB

Enter the MariaDB container:

```bash
docker compose -f srcs/docker-compose.yml exec mariadb bash
```

Inside the container, check the running processes:

```bash
ps
```

To inspect the MariaDB container from the host, use:

```bash
docker compose -f srcs/docker-compose.yml ps mariadb
docker compose -f srcs/docker-compose.yml logs mariadb
```

The database data is stored in:

```text
/var/lib/mysql
```

inside the container and persisted through the MariaDB named volume.

---

# 29. Checking NGINX

Validate the NGINX configuration:

```bash
docker compose -f srcs/docker-compose.yml exec nginx nginx -t
```

Check the HTTPS endpoint:

```bash
curl -k -I https://oshtohri.42.fr
```

Check TLS 1.2:

```bash
curl -k --tlsv1.2 --tls-max 1.2 -I https://oshtohri.42.fr
```

Check TLS 1.3:

```bash
curl -k --tlsv1.3 -I https://oshtohri.42.fr
```

---

# 30. Checking Volumes

List volumes:

```bash
docker volume ls
```

Inspect the MariaDB volume:

```bash
docker volume inspect srcs_mariadb_data
```

Inspect the WordPress volume:

```bash
docker volume inspect srcs_wordpress_data
```

The volume configuration should point to the required host storage
directories:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

---

# 31. Checking the Network

List Docker networks:

```bash
docker network ls
```

Inspect the project network:

```bash
docker network inspect srcs_inception
```

The expected long-running services are:

```text
mariadb
wordpress
nginx
redis
adminer
ftp
static-site
```

All seven long-running services communicate through the project Docker network. The `backup` container also joins the network when the backup job runs.

---

# 32. Git and Sensitive Files

Sensitive files must not be committed.

The project uses:

```text
.gitignore
```

The project uses the following `.gitignore` rules:

```gitignore
/secrets/
/srcs/.env
```

Before creating a commit, verify:

```bash
git status
```

The local secrets directory and `srcs/.env` must not be committed. Dockerfiles must never contain passwords or other sensitive credentials.

---

# 33. Rebuilding After Configuration Changes

If a Dockerfile changes:

```bash
make build
```

If a service needs to be rebuilt and restarted:

```bash
make re
```

If the project configuration changes, validate the Compose file first:

```bash
make check-config
```

```bash
docker compose -f srcs/docker-compose.yml config
```

Then rebuild the affected infrastructure.

---

# 34. Complete Development Workflow

A typical development workflow is:

```text
1. Modify configuration or source files
             ↓
2. Validate docker-compose.yml
             ↓
3. Build images
             ↓
4. Start containers
             ↓
5. Check container status
             ↓
6. Check service logs
             ↓
7. Test the website
             ↓
8. Test persistence if required
             ↓
9. Check Git status
             ↓
10. Commit only safe project files
```

Useful commands:

```bash
docker compose -f srcs/docker-compose.yml config
make build
make
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs
```

---

# 35. Important Development Rules

When modifying the project, preserve the following architecture:

- NGINX remains the public HTTPS entry point for the web application.
- HTTPS port `443` is published by NGINX.
- FTP separately publishes port `21` and passive ports `21100-21110`.
- WordPress remains separated from NGINX and serves PHP through PHP-FPM.
- MariaDB remains separated from WordPress.
- Services communicate through the Docker network.
- The static website is served through the main NGINX reverse proxy.
- FTP provides authenticated access to the shared WordPress files.
- Redis provides object caching for WordPress.
- Adminer is accessed through NGINX over HTTPS.
- The backup service runs on demand and stores SQL dumps under `/home/oshtohri/data/backups/`.
- Persistent application data remains in the two Docker named volumes.
- The two persistent volumes must continue storing their data under `/home/oshtohri/data/mariadb` and `/home/oshtohri/data/wordpress`.
- Passwords remain in Docker Secrets.
- Non-sensitive configuration remains in `.env`.
- Passwords must not be placed in Dockerfiles.
- The `latest` tag must not be introduced.
- Long-running containers must run their actual services as their main processes.
- The backup container exits after the backup operation finishes.
- Infinite-loop keep-alive hacks must not be introduced.
- `make fclean` is destructive and must only be used when intentionally deleting the persistent MariaDB and WordPress data.


