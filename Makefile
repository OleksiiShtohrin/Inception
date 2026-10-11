
COMPOSE = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/$(USER)/data

.PHONY: all check-config prepare build up down clean fclean re

all: check-config prepare
	$(COMPOSE) up -d --build

check-config:
	@./scripts/check-config.sh

prepare:
	@mkdir -p $(DATA_DIR)/mariadb
	@mkdir -p $(DATA_DIR)/wordpress

build: check-config prepare
	$(COMPOSE) build

up: check-config prepare
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v

fclean:
	$(COMPOSE) down -v
	sudo find $(DATA_DIR)/mariadb -mindepth 1 -delete
	sudo find $(DATA_DIR)/wordpress -mindepth 1 -delete

re: check-config prepare
	$(COMPOSE) down
	$(COMPOSE) up -d --build
