# Inception — User Documentation

## Overview

This project provides a small WordPress web infrastructure running with Docker.

The infrastructure consists of three services:

- **NGINX** — HTTPS entry point.
- **WordPress + PHP-FPM** — web application.
- **MariaDB** — database server.

Only NGINX is accessible from outside the Docker infrastructure.

The website is available at:

```text
https://oshtohri.42.fr
```

The WordPress administration panel is available at:

```text
https://oshtohri.42.fr/wp-admin/
```

The project uses a self-signed TLS certificate, so the browser may display a
security warning when accessing the website.

---

## Services

### NGINX

NGINX is the public entry point of the infrastructure.

It:

- listens on port `443`;
- provides HTTPS;
- supports TLS 1.2 and TLS 1.3;
- serves WordPress files;
- forwards PHP requests to PHP-FPM.

### WordPress

WordPress runs together with PHP-FPM in its own container.

It provides the website and the WordPress administration interface.

WordPress is not directly exposed to the host.

### MariaDB

MariaDB stores the WordPress database.

It is accessible only through the internal Docker network.

MariaDB is not directly exposed to the host.

---

# Starting the Project

From the project root directory:

```bash
make
```

This builds the Docker images and starts the infrastructure.

Check the status of the services:

```bash
docker compose -f srcs/docker-compose.yml ps
```

The three services should be running:

```text
mariadb
wordpress
nginx
```

---

# Accessing the Website

Open the following address in a browser:

```text
https://oshtohri.42.fr
```

The website should display the WordPress installation.

Because the TLS certificate is self-signed, the browser may display a
certificate warning.

This is expected for the local development environment.

---

# Accessing WordPress Administration

The WordPress administration panel is available at:

```text
https://oshtohri.42.fr/wp-admin/
```

The project contains two WordPress users:

| Username | Role |
|---|---|
| `oshtohri` | Administrator |
| `student` | Subscriber |

The administrator username does not contain `admin` or `administrator`.

Passwords are stored locally in Docker Secret files and are not stored in the
Git repository.

---

# Credentials

The project uses Docker Secrets for passwords.

The secret files are located in:

```text
secrets/
├── db_password.txt
├── db_root_password.txt
├── wp_admin_password.txt
└── wp_user_password.txt
```

These files must remain private.

They are excluded from Git using `.gitignore`.

The passwords should never be published in the repository or documentation.

---

# Stopping the Project

To stop the project:

```bash
make down
```

This stops and removes the containers.

The persistent Docker volumes are preserved.

Therefore, WordPress files and the MariaDB database remain available when the
containers are started again.

---

# Restarting the Project

To start the project again:

```bash
make up
```

To rebuild the images and restart the complete infrastructure:

```bash
make re
```

---

# Checking the Services

## Check container status

```bash
docker compose -f srcs/docker-compose.yml ps
```

All three services should have a running status.

## Check all logs

```bash
docker compose -f srcs/docker-compose.yml logs
```

## Check one service

For NGINX:

```bash
docker compose -f srcs/docker-compose.yml logs nginx
```

For WordPress:

```bash
docker compose -f srcs/docker-compose.yml logs wordpress
```

For MariaDB:

```bash
docker compose -f srcs/docker-compose.yml logs mariadb
```

## Follow logs

```bash
docker compose -f srcs/docker-compose.yml logs -f
```

Press `Ctrl+C` to stop following the logs.

---

# Checking the Website from the Terminal

The HTTPS connection can be tested with:

```bash
curl -k -I https://oshtohri.42.fr
```

A successful response should contain:

```text
HTTP/1.1 200 OK
```

The `-k` option allows `curl` to connect to the self-signed certificate.

---

# Checking Docker Volumes

The project uses two persistent named volumes.

List Docker volumes:

```bash
docker volume ls
```

Inspect the WordPress volume:

```bash
docker volume inspect srcs_wordpress_data
```

Inspect the MariaDB volume:

```bash
docker volume inspect srcs_mariadb_data
```

The persistent data is stored on the host under:

```text
/home/oshtohri/data/
├── mariadb/
└── wordpress/
```

---

# Data Persistence

The containers can be removed and recreated without losing the persistent
WordPress and MariaDB data, as long as the Docker volumes are preserved.

For example:

```bash
make down
make up
```

After restarting, the existing WordPress installation and database should
still be available.

---

# Removing the Project Data

The command:

```bash
make clean
```

removes the containers and Docker volumes.

This also removes the persistent application data stored in those volumes.

Therefore:

> **Do not use `make clean` if you need to preserve the WordPress website
> and database.**

---

# Troubleshooting

## Containers are not running

Check their status:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Then inspect the logs:

```bash
docker compose -f srcs/docker-compose.yml logs
```

---

## NGINX is not accessible

Check that the NGINX container is running:

```bash
docker compose -f srcs/docker-compose.yml ps nginx
```

Check the NGINX logs:

```bash
docker compose -f srcs/docker-compose.yml logs nginx
```

Check that port `443` is published:

```bash
docker compose -f srcs/docker-compose.yml ps
```

---

## WordPress is not loading

Check the WordPress logs:

```bash
docker compose -f srcs/docker-compose.yml logs wordpress
```

Then check MariaDB:

```bash
docker compose -f srcs/docker-compose.yml logs mariadb
```

WordPress depends on MariaDB being available through the Docker network.

---

## Check the Docker Network

List networks:

```bash
docker network ls
```

Inspect the project network:

```bash
docker network inspect srcs_inception
```

The three project containers should be connected to the same Docker network.

---

# Useful Makefile Commands

| Command | Description |
|---|---|
| `make` | Build and start the complete infrastructure |
| `make build` | Build Docker images |
| `make up` | Start existing containers |
| `make down` | Stop and remove containers |
| `make re` | Rebuild and restart the infrastructure |
| `make clean` | Remove containers and persistent Docker volumes |

---

# Security Notes

- Do not commit files from `secrets/`.
- Do not put passwords in Dockerfiles.
- Do not publish passwords in documentation.
- Do not share the contents of the secret files.
- Only NGINX is exposed to the host.
- WordPress and MariaDB communicate through the internal Docker network.
