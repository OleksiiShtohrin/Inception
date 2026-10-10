# Inception — Developer Documentation

## 1. Project Overview

Inception is a Docker-based infrastructure project developed as part of the 42 curriculum.

The infrastructure consists of five independent services:

```text
                         NGINX
                      HTTPS :443
                            │
                 ┌──────────┴──────────┐
                 │                     │
            FastCGI :9000         FastCGI :9000
                 │                     │
                 ▼                     ▼
          WordPress + PHP-FPM       Adminer
                 │                     │
                 └──────────┬──────────┘
                            │
                       MySQL :3306
                            │
                            ▼
                         MariaDB

          Redis — WordPress object cache
```

The five services are:
- NGINX — the only service exposed to the host; terminates HTTPS and routes requests to the appropriate application.
- WordPress + PHP-FPM — serves the WordPress website.
- MariaDB — stores the WordPress database.
- Redis — provides object caching for WordPress through the Redis Object Cache plugin.
- Adminer — provides a web interface for managing MariaDB through NGINX over HTTPS.

Each service runs in its own dedicated Docker container.

The containers communicate through a dedicated Docker bridge network.

Persistent application data is stored using two Docker named volumes.

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
│   └── create-secrets.sh
│
├── secrets/                  # Local files; excluded from Git
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
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
            └── redis/
                ├── Dockerfile
                └── conf/
                    └── redis.conf
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
srcs/.env
```

Environment variables are used for configuration because these values are not
passwords.

---

# 5. Docker Secrets

Passwords are stored separately from normal configuration.

The project uses the following secret files:

```text
secrets/
├── db_password.txt
├── db_root_password.txt
├── wp_admin_password.txt
└── wp_user_password.txt
```

These files are excluded from Git:

```gitignore
/secrets/
```

Docker Compose makes the secrets available inside the relevant containers
under:

```text
/run/secrets/
```

For example:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

The startup scripts read the required password from these files.

Passwords are therefore not hard-coded into Dockerfiles.

### Generating Secrets

The project provides a script to generate the four required secret files:

```bash
./scripts/create-secrets.sh
```

The script creates a secret only if the corresponding file does not already exist. Each generated secret contains 12 hexadecimal characters. The files are assigned permissions `600`, and the `secrets/` directory is assigned permissions `700`.

Existing secret files are preserved when the script is run again. This prevents accidental password changes for an already initialized database.

**Important:** Generate the secrets before the first MariaDB initialization. If MariaDB has already been initialized, changing the secret files does not automatically update the database users' passwords.

For a fresh installation, prepare the environment and secrets before starting the services:

```bash
./scripts/create-secrets.sh
docker compose -f srcs/docker-compose.yml config -q
```

The script does not print or display the generated passwords.

---

# 6. Docker Compose

The main orchestration file is:

```text
srcs/docker-compose.yml
```

It defines five services:

```text
mariadb
wordpress
nginx
redis
adminer
```

It also defines:

- the Docker network;
- the MariaDB named volume;
- the WordPress named volume;
- Docker Secrets.

Only NGINX publishes a port to the host (`443:443`). WordPress, MariaDB,
Redis and Adminer communicate through the internal Docker network and do not
publish ports directly to the host.

Redis provides WordPress object caching. Adminer is accessed through NGINX
over HTTPS at `https://oshtohri.42.fr/adminer/`.

The services use their own Dockerfiles:

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

NGINX is configured to listen only on:

```text
443
```

TLS protocols are restricted to:

```text
TLSv1.2
TLSv1.3
```

NGINX forwards PHP requests to:

```text
wordpress:9000
```

The WordPress volume is mounted read-only in the NGINX container.

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

# 14. Docker Network

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

Only NGINX publishes a host port:

```text
443:443
```

---

# 15. Persistent Volumes

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

---

# 16. Persistence Model

Container lifecycle and application data lifecycle are separated.

Removing the containers does not remove the persistent volumes.

For example:

```bash
make down
make up
```

removes and recreates the containers while preserving the database and
WordPress files.

The command:

```bash
make clean
```

removes the Docker named volumes but preserves the persistent data stored
under:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

To completely remove the project data, use:

```bash
make fclean
```

This removes the Docker volumes and deletes the contents of the persistent
data directories.

---

# 17. Makefile

The Makefile is located at:

```text
Makefile
```

The Compose command is defined as:

```makefile
COMPOSE = docker compose -f srcs/docker-compose.yml
```

Available targets:

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

Starts the existing containers.

```bash
make up
```

### `make down`

Stops and removes containers.

```bash
make down
```

### `make re`

Stops the project and rebuilds the infrastructure.

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

# 18. Container Restart Policy

Each service uses:

```yaml
restart: always
```

This instructs Docker to restart the container if the main process exits.

All five services use the same restart policy:

```text
mariadb
wordpress
nginx
redis
adminer
```

---

# 19. PID 1 and Container Processes

The project avoids using artificial infinite-loop commands to keep containers
alive.

The containers run their actual services as their main processes.

The main processes are:

```text
MariaDB   → mariadbd
WordPress → php-fpm8.2 -F
NGINX     → nginx -g "daemon off;"
```

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

# 20. Build Process

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
```

The `latest` tag is not used.

---

# 21. Starting the Infrastructure

The normal development workflow is:

```bash
make
```

Then verify:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected services:

```text
mariadb
wordpress
nginx
```

Check the logs if necessary:

```bash
docker compose -f srcs/docker-compose.yml logs
```

---

# 22. Configuration Validation

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

# 23. Debugging

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

# 24. Checking WordPress

WP-CLI can be used inside the WordPress container.

List WordPress users:

```bash
docker compose exec wordpress \
    wp user list \
    --path=/var/www/html \
    --allow-root
```

Check the WordPress database:

```bash
docker compose exec wordpress \
    wp db check \
    --path=/var/www/html \
    --allow-root
```

Check whether WordPress is installed:

```bash
docker compose exec wordpress \
    wp core is-installed \
    --path=/var/www/html \
    --allow-root
```

---

# 25. Checking MariaDB

Enter the MariaDB container:

```bash
docker compose exec mariadb bash
```

Check the MariaDB process:

```bash
ps
```

or inspect the process directly from the host:

```bash
docker inspect mariadb
```

The database data is stored in:

```text
/var/lib/mysql
```

inside the container and persisted through the MariaDB named volume.

---

# 26. Checking NGINX

Validate the NGINX configuration:

```bash
docker compose exec nginx nginx -t
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

# 27. Checking Volumes

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

# 28. Checking the Network

List Docker networks:

```bash
docker network ls
```

Inspect the project network:

```bash
docker network inspect srcs_inception
```

The expected containers are:

```text
mariadb
wordpress
nginx
redis
adminer
```

All five services must be connected to the same project network.

---

# 29. Git and Sensitive Files

Sensitive files must not be committed.

The project uses:

```text
.gitignore
```

with:

```gitignore
secrets/*.txt
srcs/.env
```

Before creating a commit, verify:

```bash
git status
```

The following must not appear as tracked files:

```text
secrets/*.txt
srcs/.env
```

Dockerfiles must also never contain passwords.

---

# 30. Rebuilding After Configuration Changes

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
docker compose -f srcs/docker-compose.yml config
```

Then rebuild the affected infrastructure.

---

# 31. Complete Development Workflow

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

# 32. Important Development Rules

When modifying the project, preserve the following architecture:

- NGINX remains the only public entry point.
- Only port `443` is exposed.
- WordPress remains separated from NGINX.
- MariaDB remains separated from WordPress.
- Services communicate through the Docker network.
- Persistent data remains in Docker named volumes.
- Passwords remain in Docker Secrets.
- Non-sensitive configuration remains in `.env`.
- Passwords must not be placed in Dockerfiles.
- The `latest` tag must not be introduced.
- Containers must run their actual services as their main processes.
- Infinite-loop keep-alive hacks must not be introduced.
- The two persistent volumes must continue storing their data under
  `/home/oshtohri/data`.
