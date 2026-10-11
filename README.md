*This project has been created as part of the 42 curriculum by oshtohri.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum.

The goal of this project is to build a small and secure web infrastructure using
Docker and Docker Compose inside a Virtual Machine.

The infrastructure consists of seven long-running services and one on-demand backup job:

- **NGINX** — the public HTTPS entry point, providing TLS 1.2/1.3 and routing requests to the application and static website.
- **WordPress + PHP-FPM** — the application layer responsible for serving the WordPress website.
- **MariaDB** — the database server used by WordPress.
- **Redis** — an object cache that improves WordPress performance through the Redis Object Cache plugin.
- **Adminer** — a web-based database management interface accessible through NGINX over HTTPS.
- **FTP** — a file transfer service that allows authenticated access to the shared WordPress files.
- **Static Website** — a separate NGINX container serving static HTML and CSS files through the main NGINX reverse proxy.
- **Backup** — an on-demand job that creates SQL dumps of the MariaDB database and stores them in a host directory.

Each long-running service runs in its own container. The images are built from service-specific Dockerfiles based on Debian 12.

The containers communicate through a dedicated Docker bridge network.

Persistent application data is stored using two Docker named volumes:

- a volume for the MariaDB database;
- a volume for the WordPress website files.

The volumes use host directories under:

```text
/home/oshtohri/data/
├── mariadb/
└── wordpress/
```

Database backups are stored separately on the host under:

```text
/home/oshtohri/data/backups/
```

The project uses Docker Secrets for passwords and a `.env` file for non-sensitive configuration values.

The website is available through:

```text
https://oshtohri.42.fr
```

The WordPress administration panel is available at:

```text
https://oshtohri.42.fr/wp-admin/
```

The Adminer database management interface is available at:

```text
https://oshtohri.42.fr/adminer/
```

The static website is available through:

```text
https://oshtohri.42.fr/static/
```

FTP is accessible through the host's FTP ports and uses the shared WordPress files directory. Adminer, Redis, and the static website are accessible internally through the Docker network rather than through separately published host ports.

The backup job runs on demand and is not scheduled automatically.

The TLS certificate used by NGINX is self-signed, so a browser may display a certificate warning.

---

## Architecture

The infrastructure can be represented as follows:

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

The host publishes HTTPS on port 443 and FTP on port 21, with passive FTP ports 21100-21110. The static website, Adminer, Redis, WordPress, and MariaDB do not expose their own ports directly to the host.

WordPress, MariaDB, Redis, Adminer, FTP and the static website are connected to the internal Docker network. Only NGINX and FTP publish ports on the host. Adminer and the static website are accessed through NGINX over HTTPS, while the backup job connects to MariaDB through the internal network.

---

## Project Structure

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

The `secrets/` directory contains local credentials and is excluded from Git.

The `srcs/.env` file contains non-sensitive configuration values and is also excluded from Git.

The `srcs/.env.example` file provides a template for the required
non-sensitive environment variables and does not contain passwords.

---

# Main Design Choices

## Docker Images

Each service has its own Dockerfile, which defines the packages, configuration files and startup command required by that service.

The project uses Debian 12 as the base image for the custom service images. Each image contains only the software and configuration needed for its role.

The project builds the following custom images:

- **mariadb:1.0** — MariaDB database server.
- **wordpress:1.0** — WordPress application with PHP-FPM.
- **nginx:1.0** — HTTPS reverse proxy and web server.
- **redis:1.0** — Redis object cache.
- **adminer:1.0** — database management interface.
- **ftp:1.0** — FTP server using vsftpd.
- **static-site:1.0** — NGINX server for static HTML and CSS.
- **backup:1.0** — on-demand database backup job using `mariadb-client`.

The `latest` tag is intentionally not used.

---

## NGINX

NGINX is the public entry point for web traffic. It exposes HTTPS on port `443` and routes requests to the appropriate service through the internal Docker network.

It:

- listens on port `443`;
- provides HTTPS;
- allows only TLS 1.2 and TLS 1.3;
- serves WordPress static files;
- forwards WordPress PHP requests to the WordPress PHP-FPM container;
- routes Adminer PHP requests to the dedicated Adminer PHP-FPM container;
- serves Adminer static CSS and JavaScript files;
- forwards requests under `/static/` to the static website container;
- communicates with the application containers through the Docker network.

HTTP port `80` is not exposed on the host. FTP publishes its own ports separately and does not pass through the NGINX reverse proxy.

---

## WordPress and PHP-FPM

The WordPress container contains:

- WordPress;
- PHP 8.2;
- PHP-FPM;
- required PHP extensions;
- WP-CLI;
- MariaDB client utilities.

NGINX is not installed in the WordPress container.

PHP-FPM listens internally on:

```text
9000
```

The WordPress container is therefore responsible only for the application
layer.

---

## MariaDB

MariaDB runs in its own dedicated container.

It is not exposed directly to the host.

MariaDB listens on the internal Docker network and accepts connections from the WordPress and Adminer containers.

The database is persisted using the MariaDB named volume.

---

# Bonus Services

## Redis

Redis is used as an object cache for WordPress through the Redis Object Cache
plugin.

It helps reduce repeated database queries by caching supported WordPress data.

Redis is available only through the internal Docker network and does not
expose a port to the host.

---

## Adminer

Adminer provides a web-based interface for managing the MariaDB database.

It is accessible through NGINX over HTTPS at:

```text
https://oshtohri.42.fr/adminer/
```

Adminer runs in its own container with PHP-FPM. NGINX forwards Adminer PHP
requests to that container and serves its static CSS and JavaScript files.

Adminer is not exposed directly to the host. It connects to MariaDB through
the internal Docker network.

Use the MariaDB credentials configured for the project to log in. Do not store
database passwords in this documentation.

---

## FTP

The FTP service uses vsftpd to provide authenticated access to the shared WordPress files.

It:

- runs in its own container;
- uses the `ftp_password` Docker Secret for the FTP user's password;
- shares the `wordpress_data` volume with WordPress;
- allows authenticated file transfers;
- uses port `21` for FTP control connections and ports `21100-21110` for passive data connections.

The FTP service publishes these ports on the host:

```text
21
21100-21110
```

Anonymous FTP access is disabled. The FTP user is restricted to the shared WordPress files directory.

---

## Static Website

The static website runs in its own NGINX container and serves HTML and CSS files.

It is accessible through the main NGINX reverse proxy at:

```text
https://oshtohri.42.fr/static/
```

The main NGINX forwards requests under `/static/` to the static website container through the internal Docker network.

The static website does not publish a port directly to the host.

---

## Database Backup

The backup service creates SQL dumps of the MariaDB database using `mariadb-dump`.

To run a backup manually, execute:

```bash
docker compose -f srcs/docker-compose.yml run --rm backup
```

The service waits for MariaDB to become available before creating the dump. Backup files are stored on the host in:

```text
/home/oshtohri/data/backups/
```

Each backup filename includes a timestamp. The backup service runs on demand and is not scheduled automatically.

The backup job uses the `db_password` Docker Secret to authenticate with MariaDB. Removing the temporary backup container does not remove the SQL files stored on the host.

---

# Persistent Storage

The project uses two Docker named volumes:

```text
mariadb_data
wordpress_data
```

Their persistent data is stored on the host under:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

The volumes are declared as Docker named volumes in `docker-compose.yml` and configured with Docker's local volume driver so that their data is stored in the required host directories.

This allows containers to be removed and recreated without losing the WordPress database or website files.

For database backup instructions, see the [Database Backup](#database-backup) section above.

---

# Virtual Machines vs Docker

## Virtual Machine

A Virtual Machine emulates a complete computer environment.

It normally contains:

- a virtual CPU;
- virtual memory;
- virtual storage;
- a complete operating system;
- applications running on that operating system.

A VM therefore has more overhead because each VM requires its own operating
system.

## Docker

Docker containers share the host operating system kernel while isolating
applications and their dependencies.

A Docker container contains the application, libraries and configuration
needed to run the service without requiring a complete guest operating
system.

### Comparison

| Virtual Machine | Docker |
|---|---|
| Contains a complete guest OS | Shares the host kernel |
| Higher resource overhead | Lower overhead |
| Usually slower to start | Usually starts quickly |
| Strong OS-level isolation | Process/container isolation |
| Useful for running different OS environments | Useful for packaging and deploying services |

For Inception, the Virtual Machine provides the required isolated environment,
while Docker is used inside it to run the individual services.

---

# Secrets vs Environment Variables

Environment variables are useful for configuration values such as:

```text
DOMAIN_NAME
MYSQL_DATABASE
MYSQL_USER
MYSQL_HOST
MYSQL_PORT
WP_ADMIN_USER
```

However, passwords and other confidential information should not be stored
directly in environment variables or committed to the repository.

This project uses Docker Secrets for passwords:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
/run/secrets/ftp_password
```

The initialization scripts read the secrets when the containers start.

### Comparison

| Environment Variables | Docker Secrets |
|---|---|
| Good for configuration | Designed for sensitive data |
| Easy to use | Better suited for passwords |
| Values may be visible in process/container configuration | Mounted as secret files |
| Not ideal for confidential credentials | Used for project credentials |

The project therefore separates configuration from sensitive information.

---

# Docker Network vs Host Network

## Docker Network

This project uses a dedicated Docker bridge network:

```text
inception
```

The containers communicate using Docker's internal networking and service
names.

For example:

```text
wordpress → mariadb:3306
nginx     → wordpress:9000
```

NGINX publishes port `443` for HTTPS. FTP separately publishes port `21` and the passive port range `21100-21110`. The other services do not publish ports directly to the host.

## Host Network

With host networking, a container uses the host's network namespace directly.

This would reduce network isolation and would make the container much more
closely coupled to the host network.

The Inception project explicitly requires a Docker network and forbids
`network: host`.

### Comparison

| Docker Network | Host Network |
|---|---|
| Provides network isolation | Shares host network |
| Containers communicate internally | Services use host networking |
| Service names can be used for discovery | Less network isolation |
| Better suited to multi-container applications | Useful for specific performance/network cases |

The project therefore uses a dedicated Docker bridge network.

---

# Docker Volumes vs Bind Mounts

## Docker Named Volumes

A Docker named volume is managed by Docker.

This project declares:

```text
mariadb_data
wordpress_data
```

as named volumes.

Their data is configured to reside under:

```text
/home/oshtohri/data/
```

Named volumes are useful for persistent application data because the data
lifecycle is separated from the lifecycle of individual containers.

## Bind Mounts

A bind mount directly maps a specific host filesystem path into a container.

For example, a Compose bind mount would look like:

```yaml
volumes:
  - /host/path:/container/path
```

The Inception subject explicitly forbids bind mounts for the two persistent
WordPress/MariaDB storages. The backup service uses a bind mount for its
output directory, `/home/oshtohri/data/backups`, so that SQL backup files
remain available on the host after the backup container exits.

### Comparison

| Docker Named Volume | Bind Mount |
|---|---|
| Managed by Docker | Direct host path mapping |
| Identified by a volume name | Identified by a filesystem path |
| Designed for persistent container data | Useful when direct host-file access is required |
| Docker controls the volume lifecycle | Host filesystem controls the path |

This project therefore uses Docker named volumes, while configuring the local
volume driver so the persistent data is stored in the required
`/home/oshtohri/data` directories.

---

# Security

The project follows several security-related requirements:

- NGINX exposes HTTPS on port `443`.
- FTP publishes port `21` and passive ports `21100-21110` on the host.
- The other services do not publish ports directly to the host.
- TLS 1.2 and TLS 1.3 are enabled.
- Older TLS protocols are disabled.
- WordPress, MariaDB, Redis, Adminer and the static website communicate through the internal Docker network.
- Passwords are stored using Docker Secrets.
- `.env` is used for non-sensitive configuration.
- `.env` and secret files are excluded from Git.
- Passwords are not hard-coded in Dockerfiles.
- The `latest` Docker tag is not used.
- Database backups are stored separately from the application volumes in a host directory.

---

# WordPress Users

The WordPress installation contains two users:

| Username | Role |
|---|---|
| `oshtohri` | Administrator |
| `student` | Subscriber |

The administrator username intentionally does not contain `admin` or
`administrator`, as required by the project specification.

Passwords are stored locally in Docker Secret files and are not included in
this repository.

---

# Instructions

## Prerequisites

The project should be run inside the required Virtual Machine environment.

The following software is required:

- Debian 12
- Docker Engine
- Docker Compose
- Make

Check the Docker installation:

```bash
docker --version
docker compose version
make --version
```

---

## Domain Configuration

The project uses:

```text
oshtohri.42.fr
```

The domain must resolve to the local machine.

For a local setup, `/etc/hosts` can contain:

```text
127.0.0.1 oshtohri.42.fr
```

Verify the configuration with:

```bash
getent hosts oshtohri.42.fr
```

---

## Configure Environment Variables

The environment file is:

```text
srcs/.env
```

It contains non-sensitive configuration such as:

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

Passwords must not be placed in this file.

`MYSQL_PORT` defines the internal MariaDB port used by WordPress. The
default value is `3306`, but the port can be changed through `.env` without
manually editing `wp-config.php`.

---

## Configure Docker Secrets

The following local secret files are required:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
secrets/ftp_password.txt
```

Each file contains the corresponding password.

These files must remain local and must never be committed to Git.

---

# Build and Start the Project

From the project root:

```bash
make
```

This executes Docker Compose and:

1. validates the required configuration and local secrets;
2. prepares the host directories for MariaDB and WordPress data;
3. builds the service images;
4. creates the Docker network and named volumes;
5. creates and starts the containers in detached mode.

Check the running containers:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected services:

```text
mariadb
wordpress
nginx
redis
adminer
ftp
static-site
```

---

# Access the Website

Open:

```text
https://oshtohri.42.fr
```

Because the project uses a self-signed TLS certificate, the browser may show
a certificate warning.

The WordPress administration panel is available at:

```text
https://oshtohri.42.fr/wp-admin/
```

The Adminer database management interface is available at:

```text
https://oshtohri.42.fr/adminer/
```

The static website is available at:

```text
https://oshtohri.42.fr/static/
```

FTP connections use the following host ports:

```text
21
21100-21110
```

Use an FTP client with the configured FTP credentials. The FTP service provides access to the shared WordPress files directory.

---

# Makefile Commands

## Start and build

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

or

```bash
make
```

This target validates the configuration, prepares the host directories, and then runs Docker Compose with `up -d --build`.

## Validate configuration

```bash
make check-config
```

Runs `scripts/check-config.sh` to validate the required environment configuration and local Docker Secret files before starting the project.

## Prepare host directories

```bash
make prepare
```

Creates the host directories used by the MariaDB and WordPress persistent volumes:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

These directories provide the host paths used by the project's named volumes.

## Build images

```bash
make build
```

## Start existing containers

```bash
make up
```

## Stop the project

```bash
make down
```

This stops and removes the containers and network without removing the
persistent named volumes.

## Create a database backup

```bash
docker compose -f srcs/docker-compose.yml run --rm backup
```

This runs the backup job once and removes its container after completion.
The SQL dump is stored in `/home/oshtohri/data/backups/` on the host.
The backup job is not scheduled automatically.

## Rebuild the project

```bash
make re
```

This stops the containers and rebuilds the images before starting the
infrastructure again.

## Remove containers and volumes

```bash
make clean
```

This executes:

```bash
docker compose -f srcs/docker-compose.yml down -v
```

This removes the Docker volumes as well.

## Remove persistent application data

```bash
make fclean
```

This performs the clean operation and also removes the contents of the
persistent data directories:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

This is a destructive operation and should only be used when a complete
reset of the project data is intended.

---

# Useful Commands

## Check containers

```bash
docker compose -f srcs/docker-compose.yml ps
```

## View logs

```bash
docker compose -f srcs/docker-compose.yml logs
```

View logs for a specific service:

```bash
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs redis
docker compose -f srcs/docker-compose.yml logs adminer
docker compose -f srcs/docker-compose.yml logs ftp
docker compose -f srcs/docker-compose.yml logs static-site
```

Follow logs in real time:

```bash
docker compose -f srcs/docker-compose.yml logs -f
```

## Check Docker volumes

```bash
docker volume ls
```

Inspect a volume:

```bash
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
```

## Check the Docker network

```bash
docker network ls
```

Inspect the project network:

```bash
docker network inspect srcs_inception
```

## Validate the Compose configuration

```bash
docker compose -f srcs/docker-compose.yml config
```

---

# Data Persistence

The containers themselves are disposable.

The persistent application data is stored in the named volumes. Database backup files are stored separately in the host directory `/home/oshtohri/data/backups/` using a bind mount.

The host directories are:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

Therefore, removing and recreating the containers does not remove the
WordPress website or database as long as the volumes are preserved.

For example:

```bash
make down
make up
```

will recreate the containers while preserving the persistent data.

---

# Container Process Model

The containers run their actual services as the main process.

The project does not use artificial infinite-loop commands such as:

```text
tail -f
sleep infinity
while true
```

The main processes are:

- MariaDB → `mariadbd`
- WordPress → PHP-FPM
- NGINX → NGINX master process
- Redis → Redis server
- Adminer → PHP-FPM
- FTP → vsftpd
- Static Website → NGINX master process

The backup container runs the backup script as its main process and exits
after the backup job finishes.

This follows the container process model required by the project.

---

# Resources

## Official Documentation

- Docker documentation:
  https://docs.docker.com/

- Docker Compose documentation:
  https://docs.docker.com/compose/

- Docker volumes:
  https://docs.docker.com/engine/storage/volumes/

- Docker networking:
  https://docs.docker.com/engine/network/

- Docker Compose secrets:
  https://docs.docker.com/compose/how-tos/use-secrets/

- Docker secrets:
  https://docs.docker.com/engine/swarm/secrets/

- NGINX documentation:
  https://nginx.org/en/docs/

- PHP documentation:
  https://www.php.net/docs.php

- PHP-FPM documentation:
  https://www.php.net/manual/en/install.fpm.php

- WordPress documentation:
  https://wordpress.org/documentation/

- WP-CLI documentation:
  https://make.wordpress.org/cli/handbook/

- MariaDB documentation:
  https://mariadb.com/docs/

- OpenSSL documentation:
  https://docs.openssl.org/

- vsftpd documentation:
  https://security.appspot.com/vsftpd.html

- NGINX reverse proxy documentation:
  https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/

- MariaDB backup guide (`mariadb-dump`):
  https://mariadb.com/docs/server/mariadb-quickstart-guides/mariadb-backup-guide

- Docker bind mounts:
  https://docs.docker.com/engine/storage/bind-mounts/

- Adminer documentation:
  https://www.adminer.org/

- Redis documentation:
  https://redis.io/docs/latest/

## Learning Topics

The main topics studied during this project include:

- Docker images and containers
- Dockerfiles
- Docker Compose
- Docker networks
- Docker named volumes
- Container persistence
- Environment variables
- Docker Secrets
- TLS and HTTPS
- NGINX reverse proxying
- PHP-FPM
- MariaDB
- Container processes and PID 1
- Service isolation
- Container lifecycle and restart policies

---

# AI Usage

AI tools were used as a learning and development assistant during this project.

The AI was used for:

- explaining Docker and Docker Compose concepts;
- understanding the Inception requirements;
- planning the infrastructure architecture;
- discussing the separation between NGINX, WordPress/PHP-FPM and MariaDB;
- explaining Docker networks and named volumes;
- explaining Docker Secrets and environment variables;
- reviewing Dockerfiles and shell scripts;
- identifying configuration and runtime errors;
- suggesting debugging commands;
- explaining container startup and persistence behaviour;
- helping structure the project documentation;
- preparing explanations and questions for the project defense.

AI-generated suggestions were not treated as automatically correct.

Commands, configurations and project behaviour were tested manually in the
Virtual Machine and reviewed to ensure that the implementation was understood.

The final implementation was built, tested and verified in the project
environment.

---

# Project Status

Mandatory infrastructure:

- [x] Virtual Machine environment
- [x] Docker Compose
- [x] NGINX container
- [x] WordPress + PHP-FPM container
- [x] MariaDB container
- [x] Individual Dockerfiles
- [x] Dedicated Docker network
- [x] Two persistent named volumes
- [x] Persistent host data under `/home/oshtohri/data`
- [x] Docker Secrets
- [x] `.env` configuration
- [x] HTTPS on port 443
- [x] TLS 1.2
- [x] TLS 1.3
- [x] WordPress administrator
- [x] Second WordPress user
- [x] Container restart policy
- [x] Makefile
- [x] Persistent WordPress data
- [x] Persistent MariaDB data
- [x] Redis bonus service
- [x] Adminer bonus service
- [x] FTP bonus service
- [x] Static website bonus service
- [x] Database backup service
- [x] Manual database backup verified
