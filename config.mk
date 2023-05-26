TRAEFIK_BRIDGE ?= traefiknet
USER_GID ?= $(shell id -ur)
USER_UID ?= $(shell id -gr)
NAME ?= whoami
HOSTNAME ?= $(NAME).docker.localhost
MYSQL_IMAGE ?= amery/docker-alpine-mariadb
MYSQL_SERVER ?= db
MYSQL_DATABASE ?= $(NAME)
MYSQL_USER ?= $(MYSQL_DATABASE)
MYSQL_PASSWORD ?= secret1
MYSQL_ROOT_PASSWORD ?= secret2
NGINX_IMAGE ?= amery/docker-alpine-nginx
