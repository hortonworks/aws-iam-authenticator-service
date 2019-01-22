BINARY=aias
NAME=aws-iam-authenticator-service
DOCKER_IMAGE_NAME ?= hortonworks/aws-iam-authenticator-service
PROJECT=github.com/hortonworks/aws-iam-authenticator-service
VERSION ?=$(shell git describe --tags --abbrev=0)-snapshot
BUILD_TIME=$(shell date +%FT%T)
GOFILES_NOVENDOR = $(shell find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./.git/*")
DEBUG ?=false
PORT ?= 8080
LOCAL_FWD_PORT ?= 8082
LDFLAGS=-ldflags "-X ${PROJECT}/config.Version=${VERSION} -X ${PROJECT}/config.BuildTime=${BUILD_TIME} -X ${PROJECT}/config.Debug=${DEBUG} -X ${PROJECT}/config.Port=${PORT}"

deps: deps-errcheck

deps-errcheck:
	GO111MODULE=off go get -u github.com/kisielk/errcheck

formatcheck:
	([ -z "$(shell gofmt -d $(GOFILES_NOVENDOR))" ]) || (echo "Source is unformatted"; exit 1)

format:
	@gofmt -w ${GOFILES_NOVENDOR}

vet:
	go vet -shadow ./...

test:
	go test -timeout 30s -race ./...

errcheck:
	GO111MODULE=off ${GOPATH}/bin/errcheck -ignoretests -exclude errcheck_excludes.txt ./...

coverage:
	go test ${PROJECT}/cloudbreak -cover

coverage-html:
	go test ${PROJECT}/cloudbreak -coverprofile fmt
	@go tool cover -html=fmt
	@rm -f fmt

build: formatcheck vet test build-darwin build-linux

build-docker:
	@#USER_NS='-u $(shell id -u $(whoami)):$(shell id -g $(whoami))'
	docker run --rm ${USER_NS} -v "${PWD}":/go/src/${PROJECT} -w /go/src/${PROJECT} -e VERSION=${VERSION} -e GO111MODULE=on golang:1.11 make build

build-darwin:
	GOOS=darwin CGO_ENABLED=0 go build -a ${LDFLAGS} -o build/Darwin/${BINARY} -mod=vendor main.go

build-linux:
	GOOS=linux CGO_ENABLED=0 go build -a ${LDFLAGS} -o build/Linux/${BINARY} -mod=vendor main.go

release-docker:
	@USER_NS='-u $(shell id -u $(whoami)):$(shell id -g $(whoami))'
	docker run --rm ${USER_NS} -v "${PWD}":/go/src/${PROJECT} -w /go/src/${PROJECT} -e VERSION=${VERSION} -e GITHUB_ACCESS_TOKEN=${GITHUB_TOKEN} golang:1.11 bash -c "make deps && make release"

release: build
	rm -rf release
	mkdir release
	git tag v${VERSION}
	git push https://${GITHUB_ACCESS_TOKEN}@${PROJECT}.git v${VERSION}
	tar -zcvf release/cb-cli_${VERSION}_Darwin_x86_64.tgz -C build/Darwin "${BINARY}"
	tar -zcvf release/cb-cli_${VERSION}_Linux_x86_64.tgz -C build/Linux "${BINARY}"

check-minikube-context:
	kubectl config use-context minikube

docker-image-build:
	docker build -t ${DOCKER_IMAGE_NAME}:${VERSION} .

docker-build-minikube:
	$(shell eval $(minikube docker-env))
	docker build -t ${NAME}:local .

helm-install-minikube: check-minikube-context docker-build-minikube
	go mod vendor
	helm upgrade --install ${NAME} helm/${NAME} -f helm/config-minikube.yml --namespace ${NAME} --timeout 60; \

helm-install-minikube-portforward: helm-install-minikube
	kubectl port-forward -n ${NAME} svc/${NAME} ${LOCAL_FWD_PORT}:8080
