ARG filebeatVersion=8.5.1
ARG goVersion=1.18.7
FROM docker.elastic.co/beats/filebeat:$filebeatVersion
USER root
ARG filebeatVersion
ARG goVersion

RUN apt-get update && \
    apt-get install -y curl wget tar gcc git

RUN wget https://go.dev/dl/go$goVersion.linux-amd64.tar.gz -O - | tar -C /usr/local -xzf -

RUN curl -L --output /tmp/filebeat.tar.gz https://github.com/elastic/beats/archive/v$filebeatVersion.tar.gz

RUN mkdir -p /go/src/github.com/elastic/beats && tar -xvzf /tmp/filebeat.tar.gz --strip-components=1 -C /go/src/github.com/elastic/beats

COPY . /go/src/github.com/ozonru/filebeat-throttle-plugin
COPY register/plugin/plugin.go /go/src/github.com/elastic/beats/libbeat/processors/throttle/plugin.go

ENV GOPATH=/go
ENV PATH=$PATH:/usr/local/go/bin

RUN cd /go/src/github.com/ozonru/filebeat-throttle-plugin && \
    go mod vendor -v
RUN cd /go/src/github.com/elastic/beats/libbeat/processors/throttle && \
    go get github.com/elastic/beats/libbeat/processors && \
    go get github.com/ozonru/filebeat-throttle-plugin

ENV CGO_ENABLED=1
RUN cd /go/src/github.com/ozonru/filebeat-throttle-plugin/throttle && \
    GOOS=linux go build -v -o /go/src/github.com/ozonru/filebeat-throttle-plugin/output/filebeat_throttle_linux.so -buildmode=plugin


FROM docker.elastic.co/beats/filebeat:$filebeatVersion
COPY  --from=0 /go/src/github.com/ozonru/filebeat-throttle-plugin/output/filebeat_throttle_linux.so /filebeat_throttle_linux.so

CMD ["-e", "--plugin", "/filebeat_throttle_linux.so"]
