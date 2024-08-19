FROM --platform=${TARGETPLATFORM} alpine:3.20.2 AS base

FROM golang:1.21-alpine AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" > /log

FROM builder AS build
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG WEB_PORT
RUN --mount=type=cache,target=/root/.cache/go-build \
  GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
  CGO_ENABLED=0 go build \
  -ldflags="-w -s \
  -X 'main.WebPort=${WEB_PORT}' \
  " \
  -o go-debugger main.go

FROM base AS pack
COPY --from=build /app/go-debugger /
ARG WEB_PORT
EXPOSE ${WEB_PORT}

CMD ["/go-debugger"]
