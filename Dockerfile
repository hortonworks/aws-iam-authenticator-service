FROM golang:1.11
LABEL stage=intermediate

COPY config /go/src/github.com/hortonworks/aws-iam-authenticator-service/config
COPY pkg /go/src/github.com/hortonworks/aws-iam-authenticator-service/pkg
COPY vendor /go/src/github.com/hortonworks/aws-iam-authenticator-service/vendor
COPY main.go /go/src/github.com/hortonworks/aws-iam-authenticator-service/main.go
COPY go.* /go/src/github.com/hortonworks/aws-iam-authenticator-service/
COPY Makefile /go/src/github.com/hortonworks/aws-iam-authenticator-service/

WORKDIR /go/src/github.com/hortonworks/aws-iam-authenticator-service

ENV GO111MODULE on

RUN make build-linux

FROM alpine:3.8
LABEL maintainer=Hortonworks

COPY --from=0 /go/src/github.com/hortonworks/aws-iam-authenticator-service/build/Linux/aias /usr/local/bin

EXPOSE 8080

ENTRYPOINT ["aias"]
