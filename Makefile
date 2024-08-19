BUILD_TAG = $(shell echo `git branch --show-current`__`git rev-parse --short HEAD`__`date +%d-%m-%y_%H-%M-%S`)

DEBUG_PORT?=4123
WEB_PORT?=3123
# CONTEXT?=


CONTAINER_REGISTRY?=${PRIVATE_REGISTRY_HUB}
REPOSITORY?=${PROVATE_REPO}
IMAGE_TAG?=go-remote-debugger-${BUILD_TAG}

ifneq (,$(and $(CONTAINER_REGISTRY),$(REPOSITORY),$(IMAGE_TAG)),true)
REMOTE_TAG:=$(CONTAINER_REGISTRY)/$(REPOSITORY):$(IMAGE_TAG)
endif


echo: _check_context2
	@echo "BUILD_TAG: ${BUILD_TAG}"
	@echo "DEBUG_PORT: ${DEBUG_PORT}"
	@echo "WEB_PORT: ${WEB_PORT}"
	@echo "CONTAINER_REGISTRY: ${CONTAINER_REGISTRY}"
	@echo "REPOSITORY: ${REPOSITORY}"
	@echo "IMAGE_TAG: ${IMAGE_TAG}"
	@echo "REMOTE_TAG: ${REMOTE_TAG}"
	@echo "CONTEXT: ${CONTEXT}"

_build-ext: ADDITIONAL_TAG=--tag ${REMOTE_TAG}
build _build-ext:
	docker build --platform ${PLATFORM} ${ADDITIONAL_TAG} --tag go-debugger-image --tag n:bug --build-arg WEB_PORT=${WEB_PORT} --target pack .
	docker images --filter "reference=go-debugger-image"

build-app:
	CGO_ENABLED=0 go build \
	-gcflags="all=-N -l" \
	-ldflags=" \
	-X 'main.WebPort=${WEB_PORT}' \
	" \
	-o go-debugger main.go

run-app: build-app
	./go-debugger

push: _build-ext
ifdef REMOTE_TAG
	docker push ${REMOTE_TAG}
	${MAKE} echo
else
	echo remote tag not set
endif

run: build
	docker run -d -p ${WEB_PORT}:${WEB_PORT} --name go-debugger-container go-debugger-image
	docker ps --filter "name=go-debugger-container"

run-check: run
	curl http://localhost:${WEB_PORT}/

stop:
	docker container rm -f -v go-debugger-container

build-debug _build-debug-ext: $(eval REMOTE_TAG:=${REMOTE_TAG}-debug)
_build-debug-ext: ADDITIONAL_TAG=--tag ${REMOTE_TAG}
build-debug _build-debug-ext:
	docker build --platform ${PLATFORM} --file Dockerfile.debug ${ADDITIONAL_TAG} --tag go-debugger-image --tag de:bug --build-arg WEB_PORT=${WEB_PORT} --build-arg DEBUG_PORT=${DEBUG_PORT} --target pack-debug . 
	docker images --filter "reference=go-debugger-image"

run-debug-attach: build-debug
	docker run -it --rm -p ${WEB_PORT}:${WEB_PORT} -p ${DEBUG_PORT}:${DEBUG_PORT}  --name  go-debugger-container go-debugger-image:latest  /bin/sh

run-debug: build-debug
	docker run -d -p ${WEB_PORT}:${WEB_PORT} -p ${DEBUG_PORT}:${DEBUG_PORT}  --name  go-debugger-container go-debugger-image

stop-debug:
	docker container rm -f -v go-debugger-container

run-debug-check: run-debug
run-debug-check run-debug-check-remote:
	@until curl -o /dev/null -s -w "%{http_code}" http://localhost:${WEB_PORT}/ | grep -q 200; do \
		echo '.'; \
		sleep 1; \
	done
	curl http://localhost:${WEB_PORT}/
	echo

# run the whole debug image with no breakpoint
run-debug-check-and-stop: stop-debug run-debug-check stop-debug

run-debug-break: #run-debug
	curl http://localhost:${WEB_PORT}/test
	echo

push-debug: _build-debug-ext echo
ifdef REMOTE_TAG
	docker push ${REMOTE_TAG}
	echo "==== debug push ${REMOTE_TAG} to remote registry ===="
else
	echo remote tag not set
endif

deploy-debug: _check_context2 push-debug
ifdef REMOTE_TAG
	kubectl --context ${CONTEXT} run remote-go-debugger -it --rm  --image=${REMOTE_TAG} \
	--env="WEB_PORT=${WEB_PORT}" --port=${WEB_PORT} --port=${DEBUG_PORT} --expose
	echo "==== debug deploy image ${REMOTE_TAG} ===="
else
	echo remote tag not set
endif

deploy-debug-attached: _check_context2 push-debug
ifdef REMOTE_TAG
	kubectl --context ${CONTEXT} run remote-go-debugger -it --rm  --image=${REMOTE_TAG} \
	--env="WEB_PORT=${WEB_PORT}" --port=${WEB_PORT} --port=${DEBUG_PORT} --expose -- /bin/sh
	echo "==== debug deploy image ${REMOTE_TAG} ===="
else
	echo remote tag not set
endif

deploy-debug-port-forward: _check_context2
	kubectl --context ${CONTEXT} port-forward pods/remote-go-debugger ${WEB_PORT}:${WEB_PORT} ${DEBUG_PORT}:${DEBUG_PORT}

deploy-cleanup: _check_context2
	kubectl --context ${CONTEXT} delete pod remote-go-debugger --ignore-not-found=true

.PHONY: _check_context2
_check_context2:
ifndef CONTEXT
	$(eval CONTEXT=`kubectl config current-context`)
	@echo
	@echo are you sure to use context ${CONTEXT}
	@read -p "CTRL-C to abort, any other key to continue"
	@echo
else
	$(info using context ${CONTEXT} )
endif
