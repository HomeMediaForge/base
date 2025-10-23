FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git
WORKDIR /src
RUN go install github.com/openshift/mdns-publisher@latest

FROM alpine:3.20

RUN apk add --no-cache bash inotify-tools procps ca-certificates && update-ca-certificates

COPY --from=builder /go/bin/mdns-publisher /usr/local/bin/mdns-publisher
COPY mdns-entrypoint.sh /usr/local/bin/mdns-entrypoint.sh

RUN chmod +x /usr/local/bin/mdns-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/mdns-entrypoint.sh"]
