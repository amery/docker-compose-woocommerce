DOCKER ?= docker
DOCKER_COMPOSE ?= $(DOCKER) compose
GIT ?= git

DOCKER_COMPOSE_UP_OPT =
SHELL = /bin/sh

# generated outputs
#
FILES = docker-compose.yml \
	docker/Dockerfile \
	docker/php.ini \
	app.env \
	db.env \
	nginx.conf \
	nginx.env \

CONFIG_MK = config.mk
GEN_MK = gen.mk

# scripts
#
CONFIG_MK_SH = $(CURDIR)/scripts/config_mk.sh
GET_VARS_SH = $(CURDIR)/scripts/get_vars.sh
GEN_MK_SH = $(CURDIR)/scripts/gen_mk.sh

# colours
#
PYGMENTIZE ?= $(shell which pygmentize)

ifneq ($(PYGMENTIZE),)
COLOUR_YAML = $(PYGMENTIZE) -l yaml
COLOUR_JSON = $(PYGMENTIZE) -l json
else
COLOUR_YAML = cat
COLOUR_JSON = cat
endif

# variables
#
TEMPLATES = $(addsuffix .in, $(FILES))
DEPS = $(GET_VARS_SH) $(TEMPLATES) Makefile
GEN_MK_VARS = $(shell $(GET_VARS_SH) $(TEMPLATES))

.PHONY: all files clean files pull build
.PHONY: up start stop restart logs
.PHONY: update config inspect
ifneq ($(SHELL),)
.PHONY: shell
endif

all: pull build

#
#
clean:
	rm -f $(FILES) *~

.gitignore: Makefile
	for x in $(FILES); do \
		grep -q "^/$$x$$" $@ || echo "/$$x" >> $@; \
	done
	touch $@

$(GEN_MK): $(GEN_MK_SH) $(DEPS)
	$< $(GEN_MK_VARS) > $@~
	mv $@~ $@

$(CONFIG_MK): $(CONFIG_MK_SH) $(DEPS)
	$< $@ $(GEN_MK_VARS)
	touch $@

files: $(FILES) $(CONFIG_MK) $(GEN_MK) .gitignore

pull: files
	$(DOCKER_COMPOSE) pull

build: files
	$(DOCKER_COMPOSE) build --pull

include $(GEN_MK)
include $(CONFIG_MK)

export COMPOSE_PROJECT_NAME=$(NAME)

.PHONY: prestart
prestart: files
	mkdir -p overlay .overlay

up: prestart
	$(DOCKER_COMPOSE) up $(DOCKER_COMPOSE_UP_OPT)

start: prestart
	$(DOCKER_COMPOSE) up -d $(DOCKER_COMPOSE_UP_OPT)

stop: files
	$(DOCKER_COMPOSE) down --remove-orphans

restart: prestart
	$(DOCKER_COMPOSE) restart

logs: files
	$(DOCKER_COMPOSE) logs -f

ifneq ($(SHELL),)
shell: files
	$(DOCKER_COMPOSE) exec app $(SHELL)
endif

update:
	$(GIT) remote update --prune
	[ ! -s .gitmodules ] || $(GIT) submodule update --remote --init
	for x in */.gitmodules; do \
		if [ -s "$$x" ]; then \
			cd $$(dirname $$x); \
			pwd; \
			$(GIT) submodule update --init --recursive; \
			cd - > /dev/null; \
		fi; \
	done

config: files
	$(DOCKER_COMPOSE) config | $(COLOUR_YAML)

inspect:
	$(DOCKER_COMPOSE) ps
	for x in $(TRAEFIK_BRIDGE) $(NAME)_default; do \
		if $(DOCKER) network list | grep -q " $$x "; then \
			$(DOCKER) network inspect -v $$x; \
		fi; \
	done | $(COLOUR_JSON)
