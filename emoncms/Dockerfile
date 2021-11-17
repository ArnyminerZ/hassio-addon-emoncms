ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:10.0.1
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base
# Install dependencies
RUN apk add --no-cache \
        mariadb-client \
        nginx=1.20.2-r0 \
        redis=6.2.6-r0 \
        openrc \
        python3 \
    && apk add --no-cache \
        php7-ctype=7.4.25-r1 \
        php7-curl=7.4.25-r1 \
        php7-fpm=7.4.25-r1 \
        php7-gettext=7.4.25-r1 \
        php7-json=7.4.25-r1 \
        php7-mbstring=7.4.25-r1 \
        php7-mysqli=7.4.25-r1 \
        php7-opcache=7.4.25-r1 \
        php7-session=7.4.25-r1 \
        php7-zip=7.4.25-r1 \
        php7-pecl-redis=5.3.4-r0 \
        php7=7.4.25-r1 \
        py3-pip \
        --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
    && apk add --no-cache --virtual .build-dependencies \
        git=2.32.0-r0

# Download EmonCMS and modules
RUN git clone --branch 10.8.5 --depth=1 \
        https://github.com/emoncms/emoncms.git /var/www/emoncms ; cd /var/www/emoncms \
    && git clone --branch 2.1.5 --depth=1 \
        https://github.com/emoncms/dashboard.git /var/www/emoncms/Modules/dashboard \
    && git clone --branch 2.1.1 --depth=1 \
        https://github.com/emoncms/graph.git /var/www/emoncms/Modules/graph \
    && git clone --branch 2.3.2 --depth=1 \
        https://github.com/emoncms/app.git /var/www/emoncms/Modules/app \
    && git clone --branch 2.1.2 --depth=1 \
        https://github.com/emoncms/device.git /var/www/emoncms/Modules/device \
    && git clone --branch 2.3.2 --depth=1 \
        https://github.com/emoncms/backup.git /var/www/emoncms/Modules/backup \
    && git clone --branch 1.3.9 --depth=1 \
        https://github.com/openenergymonitor/EmonScripts.git /opt/openenergymonitor \
    \
    && apk del --no-cache --purge .build-dependencies \
    \
    && rm -f -r /var/www/emoncms/.git \
    && rm -f -r /var/www/emoncms/Modules/dashboard/.git \
    && rm -f -r /var/www/emoncms/Modules/graph/.git \
    && rm -f -r /var/www/emoncms/Modules/app/.git \
    && rm -f -r /var/www/emoncms/Modules/device/.git \
    && rm -f -r /var/www/emoncms/Modules/backup/.git \
    && find /var/www/emoncms -type f -name ".htaccess" -depth -exec rm -f {} \; \
    && find /var/www/emoncms -type f -name "*.md" -depth -exec rm -f {} \; \
    && find /var/www/emoncms -type f -name ".gitignore" -depth -exec rm -f {} \; \
    && find /var/www/emoncms -type f -name ".empty" -depth -exec rm -f {} \;

# Install the backup module
# Install redis for Python
RUN python3 -m pip install redis
# Copy the service to init.d
COPY service-runner /etc/init.d/service-runner
# Make the service runner executable
RUN chmod +x /etc/init.d/service-runner \
    && chown root:root /etc/init.d/service-runner \
    # Add the service-runner service to RC
    && rc-update add service-runner \
    # Install the backup module
    && chmod +x /var/www/emoncms/Modules/backup/install.sh \
    && chown root:root /var/www/emoncms/Modules/backup/install.sh
# Run the install script
RUN /var/www/emoncms/Modules/backup/install.sh

# Copy root filesystem
COPY rootfs /

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="Emoncms" \
    io.hass.description="Emoncms is a powerful open-source web-app for processing, logging and visualising energy, temperature and other environmental data." \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Malachi Soord" \
    org.opencontainers.image.title="Emoncms" \
    org.opencontainers.image.description="Emoncms is a powerful open-source web-app for processing, logging and visualising energy, temperature and other environmental data." \
    org.opencontainers.image.vendor="Home Assistant Community Add-ons" \
    org.opencontainers.image.authors="Malachi Soord & ArnyminerZ" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://addons.community" \
    org.opencontainers.image.source="https://github.com/ArnyminerZ/hassio-addon-emoncms" \
    org.opencontainers.image.documentation="https://github.com/ArnyminerZ/hassio-addon-emoncms/blob/master/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
