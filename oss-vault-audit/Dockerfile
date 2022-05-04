FROM alpine:latest

USER root

RUN set -x && apk update && apk upgrade \
  && apk add --no-cache bash logrotate tzdata gettext moreutils \
  && apk add --update --no-cache dcron libcap \
  && rm /etc/logrotate.conf && rm -r /etc/logrotate.d \
  && mkdir -p /etc/logrotate.d


ADD logrotate.conf /etc/logrotate.conf
COPY entrypoint.sh /usr/sbin/entrypoint.sh

ARG UID
ARG GID

ENV USR=vault
ENV GRP=vault

RUN set -x ; addgroup -g "$GID" -S "$GRP" && \
  adduser \
  --disabled-password \
  -g "$GID" \
  -D \
  -s "/bin/bash" \
  -h "/home/$USR" \
  -u "$UID" \
  -G "$GRP" "$USR" && exit 0 ; exit 1

RUN chown vault:vault /usr/sbin/crond \
    && setcap cap_setgid=ep /usr/sbin/crond \
    && chmod +x /usr/sbin/entrypoint.sh

USER vault
ENTRYPOINT ["entrypoint.sh"]