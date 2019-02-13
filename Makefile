# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

include .env

.DEFAULT_GOAL=build

network:
	@docker network inspect $(DOCKER_NETWORK_NAME) >/dev/null 2>&1 || docker network create $(DOCKER_NETWORK_NAME)

volumes:
	@docker volume inspect $(DATA_VOLUME_HOST) >/dev/null 2>&1 || docker volume create --name $(DATA_VOLUME_HOST)
	@docker volume inspect $(DB_VOLUME_HOST) >/dev/null 2>&1 || docker volume create --name $(DB_VOLUME_HOST)

self-signed-cert:
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./secrets/jupyterhub.key -out ./secrets/jupyterhub.crt

secrets/postgres.env:
	@echo "Generating postgres password in $@"
	@echo "POSTGRES_PASSWORD=$(shell openssl rand -hex 32)" > $@

secrets/oauth.env:
	@echo "Need oauth.env file in secrets with GitHub parameters"
	@exit 1

secrets/jupyterhub.crt:
	@echo "Need an SSL certificate in secrets/jupyterhub.crt"
	@exit 1

secrets/jupyterhub.key:
	@echo "Need an SSL key in secrets/jupyterhub.key"
	@exit 1

userlist:
	@echo "Add usernames, one per line, to ./userlist, such as:"
	@echo "    zoe admin"
	@echo "    wash"
	@exit 1

# Do not require cert/key files if SECRETS_VOLUME defined
secrets_volume = $(shell echo $(SECRETS_VOLUME))
ifeq ($(secrets_volume),)
	cert_files=secrets/jupyterhub.crt secrets/jupyterhub.key
else
	cert_files=
endif

check-files: userlist secrets/postgres.env $(cert_files)

pull:
	docker pull $(DOCKER_NOTEBOOK_IMAGE)

notebook-image: pull #singleuser/Dockerfile
	docker build -t $(LOCAL_NOTEBOOK_IMAGE) \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=$(DOCKER_NOTEBOOK_IMAGE) \
		singleuser

jupyter-notebook-images: pull #singleuser/Dockerfile
	for IMAGE in ${DOCKER_NOTEBOOK_IMAGES}; do \
		echo jupyter/$$IMAGE-notebook:8ccdfc1da8d5 && \
		docker build -t jupyter-user-base \
			--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
			--build-arg DOCKER_NOTEBOOK_IMAGE=jupyter/${IMAGE}-notebook:8ccdfc1da8d5 \
			singleuser ; \
	done

nvidia-notebook-images: pull
	docker build -t jupyter-user-tf-gpu-py3 \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=nvcr.io/nvidia/tensorflow:19.01-py3 \
		singleuser


hub: network check-files volumes
	docker build -t jupyterhub -f Dockerfile.jupyterhub \
	--build-arg JUPYTERHUB_VERSION=${JUPYTERHUB_VERSION} \
	./

all: network check-files volumes hub pull jupyter-notebook-images

run: all
	docker-compose -f docker-compose.yml -p jupyterhub up

.PHONY: network volumes check-files pull notebook_images build
