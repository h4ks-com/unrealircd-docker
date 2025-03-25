FROM ubuntu:24.04 as base
ENV UNREAL_VERSION="6.1.10" \
    TERM="vt100" \
    LC_ALL=C

RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
   ca-certificates build-essential pkg-config gdb libssl-dev libpcre2-dev libargon2-dev libsodium-dev libc-ares-dev \
   libcurl4-openssl-dev wget git nginx composer php php-fpm php-zip php-curl php-mbstring supervisor \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/log/supervisor \
 && groupadd -r ircd && useradd -r -m -g ircd ircd

FROM base as build
USER ircd

# Build UnrealIRCd
WORKDIR /home/ircd
RUN wget --trust-server-names https://www.unrealircd.org/downloads/unrealircd-${UNREAL_VERSION}.tar.gz \
 && tar -xzf unrealircd-${UNREAL_VERSION}.tar.gz \
 && cd unrealircd-${UNREAL_VERSION} \
 && ./Config \
 && make \
 && make install

# Install valware module
WORKDIR /home/ircd/unrealircd-${UNREAL_VERSION}/src/modules/third/
RUN wget https://raw.githubusercontent.com/ValwareIRC/valware-unrealircd-mods/refs/heads/main/valware \
  && chmod +x valware \
  && ./valware install cmdlist

# Install unreal webpanel
WORKDIR /home/ircd/webpanel
RUN git clone https://github.com/unrealircd/unrealircd-webpanel.git . \
  && composer install


FROM base as deploy
USER root
WORKDIR /home/ircd
ENV HOME /home/ircd
COPY --chown=ircd:ircd --from=build /home/ircd/unrealircd /home/ircd/unrealircd
COPY --chown=ircd:ircd --from=build /home/ircd/webpanel /home/ircd/webpanel
# COPY --chown=ircd:ircd conf/* /home/ircd/unrealircd/conf/
COPY --chown=ircd:ircd nginx/* /home/ircd/nginx/
COPY --chown=ircd:ircd supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# CMD ["/home/ircd/unrealircd/bin/unrealircd", "-F"]
# CMD ["nginx", "-c", "/home/ircd/nginx/nginx.conf", "-g", "daemon off;"]
CMD ["sleep", "infinity"]

# CMD ["/usr/bin/supervisord", "-n"]
