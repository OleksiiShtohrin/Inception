# Inception — User Documentation

## Overview

Inception provides a WordPress website using Docker Compose. The project includes seven long-running services and one on-demand backup job.

The public HTTPS entry point is NGINX. The website is available at:

```text
https://oshtohri.42.fr
```

The WordPress administration panel is available at:

```text
https://oshtohri.42.fr/wp-admin/
```

The project uses a self-signed TLS certificate. A browser warning is expected in this local development environment.

## Services

The project contains seven long-running services:

- **NGINX** — public HTTPS entry point and reverse proxy.
- **WordPress + PHP-FPM** — runs the WordPress application.
- **MariaDB** — stores the WordPress database.
- **Redis** — provides the configured cache service.
- **Adminer** — web interface for database administration.
- **FTP** — authenticated file access to the shared WordPress files.
- **Static site** — serves the separate static website through NGINX.

The **Backup** service is an on-demand job, not a continuously running service. It creates an SQL dump of the configured MariaDB database.

Only NGINX publishes the main website's HTTPS port. FTP publishes its configured control and passive-mode ports. Other application services are reached through the internal Docker network unless otherwise configured.

## Starting the Project

Run commands from the project root directory.

Build the images and start the infrastructure:

```bash
make
```

Check the service status:

```bash
docker compose -f srcs/docker-compose.yml ps
```

The seven long-running services should normally be running. The backup service may be stopped because it is started only when a backup is requested.

## Accessing the Services

### WordPress

Open:

```text
https://oshtohri.42.fr
```

### WordPress Administration

Open:

```text
https://oshtohri.42.fr/wp-admin/
```

The project has the following WordPress users:

| Username | Role |
|---|---|
| `oshtohri` | Administrator |
| `student` | Subscriber |

Passwords are stored in local secret files. Do not publish them or commit them to Git.

### Adminer

Open:

```text
https://oshtohri.42.fr/adminer/
```

Adminer is served through the main NGINX service and is intended for database administration. Use the database connection settings configured for the project and the appropriate database credentials.

### Static Website

Open:

```text
https://oshtohri.42.fr/static/
```

The main NGINX service forwards requests under `/static/` to the separate `static-site` container. The static-site container does not publish its own port on the host.

### FTP

The FTP service provides authenticated access to the shared WordPress files. Its configured host ports are:

- `21` — FTP control connection.
- `21100-21110` — passive-mode data connections.

Use the configured FTP account (`ftpuser`) and the password stored in the local `ftp_password` Docker secret. Do not put the password in this document, a command committed to Git, or a public message.

**Security warning:** FTP over TLS is not enabled in the current configuration. Standard FTP does not encrypt credentials or transferred files. Use it only in a trusted development environment and do not send sensitive data over an untrusted network.

## Credentials and Docker Secrets

The project uses Docker Secrets for passwords. The local `secrets/` directory contains these files:

```text
secrets/
├── db_password.txt
├── db_root_password.txt
├── wp_admin_password.txt
├── wp_user_password.txt
└── ftp_password.txt
```

Keep these files private. They should be excluded from Git and must never be copied into documentation, Dockerfiles, or public repositories. Use the project's secret-generation and configuration-checking scripts when preparing the environment.

## Starting, Stopping, and Restarting

Start the project or create missing containers:

```bash
make up
```

Stop and remove the containers while preserving application data:

```bash
make down
```

Rebuild images and start the infrastructure again:

```bash
make re
```

The `make re` target is not a full data reset. It does not intentionally delete the persistent application data.

## Checking Services and Logs

List the services and their current status:

```bash
docker compose -f srcs/docker-compose.yml ps
```

View logs for all services:

```bash
docker compose -f srcs/docker-compose.yml logs
```

Follow logs until interrupted with `Ctrl+C`:

```bash
docker compose -f srcs/docker-compose.yml logs -f
```

View logs for one service, for example:

```bash
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs redis
docker compose -f srcs/docker-compose.yml logs adminer
docker compose -f srcs/docker-compose.yml logs ftp
docker compose -f srcs/docker-compose.yml logs static-site
```

The backup job can be run manually as described in the Backup section below. Since it is an on-demand job, it is expected to exit after finishing.

## Creating a Database Backup

Run the backup job from the project root:

```bash
docker compose -f srcs/docker-compose.yml run --rm backup
```

The script waits for MariaDB to become available and then creates an SQL dump of the configured database. The database password is read from the `db_password` Docker secret.

The host backup directory is:

```text
/home/oshtohri/data/backups/
```

Inside the container, this directory is mounted at `/backups`. A successful backup uses a timestamped filename, for example:

```text
wordpress_YYYYMMDD_HHMMSS.sql
```

The backup container is removed after the command finishes, but the SQL file remains in the host backup directory. The current setup does not schedule backups automatically or automatically remove older backup files.

**Recovery warning:** creating a dump does not prove that it can be restored successfully. Keep important backups protected and test the restoration procedure separately before relying on a backup for recovery.

## Data Persistence

The project uses two Docker named volumes configured to store their data in host directories:

```text
/home/oshtohri/data/
├── mariadb/
├── wordpress/
└── backups/
```

- `mariadb/` stores MariaDB data.
- `wordpress/` stores WordPress files.
- `backups/` stores SQL dump files and is separate from the application data directories.

The following sequence stops and recreates the containers without intentionally deleting persistent application data:

```bash
make down
make up
```

### `make clean`

```bash
make clean
```

This runs `docker compose down -v`, removing containers and requesting removal of the Compose named volumes. The project configures those volumes with the local driver and host-directory bind options. Because volume removal behavior depends on the exact configuration and Docker implementation, back up important data before cleanup operations.

### `make fclean`

```bash
make fclean
```

**Warning: this is destructive.** It removes containers and volumes, then deletes the contents of the host directories for MariaDB and WordPress:

```text
/home/oshtohri/data/mariadb
/home/oshtohri/data/wordpress
```

Do not run `make fclean` unless you intentionally want to erase the persistent database and WordPress files. The current Makefile does not delete `/home/oshtohri/data/backups/`, but do not treat a backup as valid until its contents and restoration process have been checked.

## Checking HTTPS from the Terminal

Because the project uses a self-signed certificate, `curl` can be used with `-k` for a local connectivity check:

```bash
curl -k -I https://oshtohri.42.fr
```

A successful response should include an HTTP success status, such as `200 OK`. The `-k` option disables certificate verification for this request; use it only for this local development check.

## Checking Docker Volumes and Network

List Docker volumes:

```bash
docker volume ls
```

Inspect the project's volumes (the Compose project prefix may differ if the project was started with a different project name):

```bash
docker volume inspect srcs_wordpress_data
docker volume inspect srcs_mariadb_data
```

List Docker networks:

```bash
docker network ls
```

Inspect the project network (the actual name depends on the Compose project name):

```bash
docker network inspect srcs_inception
```

## Troubleshooting

### Containers are not running

Check their status and inspect the logs:

```bash
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs
```

### The website or NGINX is not accessible

Check NGINX status and logs, then test HTTPS locally:

```bash
docker compose -f srcs/docker-compose.yml ps nginx
docker compose -f srcs/docker-compose.yml logs nginx
curl -k -I https://oshtohri.42.fr
```

### WordPress is not loading

Inspect WordPress and MariaDB logs:

```bash
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

### A bonus service is not working

Check the relevant service status and logs:

```bash
docker compose -f srcs/docker-compose.yml ps redis adminer ftp static-site

docker compose -f srcs/docker-compose.yml logs redis
docker compose -f srcs/docker-compose.yml logs adminer
docker compose -f srcs/docker-compose.yml logs ftp
docker compose -f srcs/docker-compose.yml logs static-site
```

For a failed backup job, run it manually and read its output:

```bash
docker compose -f srcs/docker-compose.yml run --rm backup
```

Check that the required environment variables and Docker secrets are present. Do not print secret contents into shared logs or messages.

## Useful Makefile Commands

| Command | Description |
|---|---|
| `make` | Validate configuration, prepare data directories, build images, and start the infrastructure |
| `make check-config` | Validate required environment variables and secrets |
| `make prepare` | Create the MariaDB and WordPress host data directories |
| `make build` | Build Docker images without starting the services |
| `make up` | Start services, creating containers when necessary |
| `make down` | Stop and remove containers |
| `make re` | Stop containers and start the infrastructure again with rebuilt images |
| `make clean` | Remove containers and request removal of Docker named volumes |
| `make fclean` | Remove containers and volumes and delete MariaDB and WordPress data; destructive |

## Security Notes

- Keep all files in `secrets/` private and excluded from Git.
- Never put passwords in Dockerfiles or publish them in documentation.
- The website uses a self-signed TLS certificate, so browsers may show a warning.
- FTP is not configured with TLS and does not encrypt credentials or transferred files.
- MariaDB, Redis, and other internal services should be accessed through the intended Docker network and not exposed unnecessarily.
- Protect SQL backups because they may contain sensitive application data.
- Do not run `make fclean` unless deleting persistent WordPress and MariaDB data is intentional.
