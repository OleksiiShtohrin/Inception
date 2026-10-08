*This project has been created as part of the 42 curriculum by oshtohri.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum.

The goal of this project is to build a small and secure web infrastructure using
Docker and Docker Compose inside a Virtual Machine.

The infrastructure consists of three independent services:

- **NGINX** — the only public entry point, providing HTTPS with TLS 1.2/1.3.
- **WordPress + PHP-FPM** — the application layer responsible for serving the
  WordPress website.
- **MariaDB** — the database server used by WordPress.

Each service runs in its own dedicated container and is built from its own
Dockerfile based on Debian.

The containers communicate through a dedicated Docker bridge network.

Persistent data is stored using two Docker named volumes:

- a volume for the MariaDB database;
- a volume for the WordPress website files.

The persistent data is stored on the host under:

```text
/home/oshtohri/data/
├── mariadb/
└── wordpress/
```

The project uses Docker Secrets for passwords and a `.env` file for
non-sensitive configuration values.

The website is available through:

```text
https://oshtohri.42.fr
```

The WordPress administration panel is available at:

```text
https://oshtohri.42.fr/wp-admin/
```

The TLS certificate used by NGINX is self-signed, so a browser may display a
certificate warning.

---

## Architecture

The infrastructure can be represented as follows:

```text
                         HTTPS :443
                             │
                             ▼
                    ┌─────────────────┐
                    │      NGINX      │
                    │   TLS 1.2/1.3   │
                    └────────┬────────┘
                             │
                      FastCGI :9000
                             │
                             ▼
                    ┌─────────────────┐
                    │    WordPress    │
                    │    PHP-FPM      │
                    └────────┬────────┘
                             │
                         MySQL :3306
                             │
                             ▼
                    ┌─────────────────┐
                    │     MariaDB     │
                    └─────────────────┘

                         Docker Network
                         "inception"
```

Only NGINX exposes a port to the host:

```text
Host :443 → NGINX :443
```

WordPress and MariaDB communicate internally through the Docker network and
are not exposed directly to the host.

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
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
│
└── srcs/
    ├── .env
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
        └── wordpress/
            ├── Dockerfile
            ├── conf/
            │   └── www.conf
            └── tools/
                └── init-wp.sh
```

The `secrets/` directory contains local credentials and is excluded from Git.

The `srcs/.env` file contains non-sensitive configuration values and is also excluded from Git.

The `srcs/.env.example` file provides a template for the required
non-sensitive environment variables and does not contain passwords.

---

# Main Design Choices

## Docker Images

Each service has its own Dockerfile.

The project uses Debian 12 as the base image for all three services.

The images are built locally by Docker Compose rather than using ready-made
service images.

The resulting images are:

```text
mariadb:1.0
wordpress:1.0
nginx:1.0
```

The `latest` tag is intentionally not used.

---

## NGINX

NGINX is the only service accessible from outside the Docker infrastructure.

It:

- listens on port `443`;
- provides HTTPS;
- allows only TLS 1.2 and TLS 1.3;
- serves WordPress static files;
- forwards PHP requests to PHP-FPM;
- communicates with the WordPress container through the Docker network.

HTTP port 80 is not exposed.

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

MariaDB listens on the internal Docker network and accepts connections from
the WordPress container.

The database is persisted using the MariaDB named volume.

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

The volumes are declared as Docker named volumes in `docker-compose.yml` and
configured with Docker's local volume driver so that their data is stored in
the required host directories.

This allows containers to be removed and recreated without losing the
WordPress database or website files.

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

Only NGINX publishes a port to the host.

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
WordPress/MariaDB storages.

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

- NGINX is the only externally exposed service.
- Only port `443` is published.
- TLS 1.2 and TLS 1.3 are enabled.
- Older TLS protocols are disabled.
- WordPress and MariaDB are accessible only through the Docker network.
- Passwords are stored using Docker Secrets.
- `.env` is used for non-sensitive configuration.
- `.env` and secret files are excluded from Git.
- Passwords are not hard-coded in Dockerfiles.
- The `latest` Docker tag is not used.

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

1. builds the three Docker images;
2. creates the Docker network;
3. creates the named volumes;
4. creates the containers;
5. starts the infrastructure in detached mode.

Check the running containers:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected services:

```text
mariadb
wordpress
nginx
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

---

# Makefile Commands

## Start and build

```bash
make
```

Equivalent to:

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

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

## Remove all project data

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

The persistent application data is stored in the named volumes.

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
