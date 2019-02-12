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
	# make a self-signed cert

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
#secrets/oauth.env

pull:
	docker pull $(DOCKER_NOTEBOOK_IMAGE)

notebook_image: #pull singleuser/Dockerfile
	docker build -t $(LOCAL_NOTEBOOK_IMAGE) \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=$(DOCKER_NOTEBOOK_IMAGE) \
		singleuser

notebook_images: #pull singleuser/Dockerfile
	docker build -t jupyter-user-base \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=jupyter/minimal-notebook:8ccdfc1da8d5 \
		singleuser

	docker build -t jupyter-user-scipy \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=jupyter/scipy-notebook:8ccdfc1da8d5 \
		singleuser

	docker build -t jupyter-user-datascience \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=jupyter/datascience-notebook:8ccdfc1da8d5 \
		singleuser

	docker build -t jupyter-user-tensorflow \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=jupyter/tensorflow-notebook:8ccdfc1da8d5 \
		singleuser

	docker build -t jupyter-user-r \
		--build-arg JUPYTERHUB_VERSION=$(JUPYTERHUB_VERSION) \
		--build-arg DOCKER_NOTEBOOK_IMAGE=jupyter/r-notebook:8ccdfc1da8d5 \
		singleuser


build: network check-files volumes
	docker-compose build

.PHONY: network volumes check-files pull notebook_images build
