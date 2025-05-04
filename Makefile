PROJECT            = hello-world-docker-action
LOCAL_DOCKER_IMAGE = $(PROJECT):local
GITHUB_SERVER_URL  = https://github.com
GITHUB_API_URL     = https://api.github.com
GITHUB_GRAPHQL_URL = https://api.github.com/graphql
GITHUB_REPOSITORY  = asaaki/$(PROJECT)
GITHUB_EVENT_PATH  = /tmp/event.json
LOCAL_EVENT_PATH   = $(PWD)/fixtures/event.json
GHCR_REPO          = ghcr.io/$(GITHUB_REPOSITORY)
GHCR_PAT          ?= unset

DOCKER_RUN_ENVS    = -e GITHUB_REPOSITORY=$(GITHUB_REPOSITORY) \
                     -e GITHUB_EVENT_PATH=$(GITHUB_EVENT_PATH) \
                     -e GITHUB_SERVER_URL=$(GITHUB_SERVER_URL) \
                     -e GITHUB_API_URL=$(GITHUB_API_URL) \
                     -e GITHUB_GRAPHQL_URL=$(GITHUB_GRAPHQL_URL)
DOCKER_RUN_VOLS    = -v $(LOCAL_EVENT_PATH):$(GITHUB_EVENT_PATH)

default:
	@echo no default target

build:
	docker build \
		--progress=plain \
		--build-arg RUST_BACKTRACE=1 \
		-t $(LOCAL_DOCKER_IMAGE) .

run:
	docker run --rm $(DOCKER_RUN_ENVS) $(DOCKER_RUN_VOLS) \
		$(LOCAL_DOCKER_IMAGE) \
		--greetee Chris --token $(GHCR_PAT)

shell:
	@docker run --rm -ti $(DOCKER_RUN_ENVS) $(DOCKER_RUN_VOLS) \
		--entrypoint /bin/sh $(LOCAL_DOCKER_IMAGE)

info:
	@docker version
	@docker info
	@docker system df -v

login:
	@echo $(GHCR_PAT) | docker login ghcr.io -u asaaki --password-stdin

push:
	docker tag $(LOCAL_DOCKER_IMAGE) $(GHCR_REPO):unstable
	docker push $(GHCR_REPO):unstable

curl:
	@curl -H "authorization: token $(GHCR_PAT)" $(GITHUB_API_URL)/user
