DOCKER_ACCOUNT="egovio"
REPOS := ear-deployer
TAG=latest

.PHONY: build push release

default: build

build:
	@$(foreach REPO,$(REPOS), echo "BUILD : $(REPO)" && docker build -t $(DOCKER_ACCOUNT)/$(REPO):$(TAG) -f Dockerfile . ;)
	
push:
	@$(foreach REPO,${REPOS}, docker tag $(DOCKER_ACCOUNT)/$(REPO):$(TAG) $(DOCKER_ACCOUNT)/$(REPO):$(TAG) && \
	docker push $(DOCKER_ACCOUNT)/$(REPO):$(TAG) ;)

release: build push
