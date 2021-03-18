default:
	@echo no default target

local:
	docker build . -t hello-world-action:local --progress=plain
	docker run --rm -ti hello-world-action:local Chris

info:
	@docker version
	@docker info
	@docker system df -v

login:
	@echo $(GHCR_PAT) | docker login ghcr.io -u asaaki --password-stdin

push:
	docker tag hello-world-action:local ghcr.io/asaaki/hello-world-action:unstable
	docker push ghcr.io/asaaki/hello-world-action:unstable
