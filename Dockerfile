FROM node:18-alpine as frontend-builder

RUN mkdir /frontend
COPY frontend /frontend
WORKDIR /frontend
RUN npm ci && npm run build


FROM golang:1.23.2-alpine3.19 as backend-builder

RUN mkdir /filebrowser
RUN mkdir /filebrowser/frontend
COPY --from=frontend-builder /frontend /filebrowser/frontend
WORKDIR /filebrowser
COPY go.sum ./
COPY go.mod ./
RUN go mod download
ADD . .
RUN go build -o filebrowser


FROM alpine:latest

RUN apk --update add ca-certificates \
                     mailcap \
                     curl \
                     jq \
                     nano \
                     vim

COPY --from=backend-builder /filebrowser/filebrowser /
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh  # Make the script executable
HEALTHCHECK --start-period=2s --interval=5s --timeout=3s \
    CMD /healthcheck.sh || exit 1
COPY filebrowser.db /
RUN cp filebrowser.db database.db
VOLUME /srv
EXPOSE 80
COPY docker_config.json /.filebrowser.json
ENTRYPOINT [ "/filebrowser" ]
