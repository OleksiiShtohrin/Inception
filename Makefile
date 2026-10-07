COMPOSE = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/$(USER)/data

all: prepare
	$(COMPOSE) up -d --build

prepare:
	@mkdir -p $(DATA_DIR)/mariadb
	@mkdir -p $(DATA_DIR)/wordpress

build: prepare
	$(COMPOSE) build

up: prepare
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v

fclean:
	$(COMPOSE) down -v
	sudo find $(DATA_DIR)/mariadb -mindepth 1 -delete
	sudo find $(DATA_DIR)/wordpress -mindepth 1 -delete

re: prepare
	$(COMPOSE) down
	$(COMPOSE) up -d --build