FROM ubuntu:22.04

# Ubuntu 22.04 supported until APR 2032
LABEL org.opencontainers.image.authors="jon@titmus.me"

ENV TZ=Europe/London
ARG DEBIAN_FRONTEND=noninteractive

# Set Timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Update and install dependencies
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y software-properties-common ca-certificates apt-transport-https \
    language-pack-en-base curl zip wget gnupg2 lsb-release

# Add PHP PPA
RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y
RUN apt-get update

# Install Apache and PHP 8.2 with required extensions
RUN apt-get install -y apache2 \
    php8.2 \
    libapache2-mod-php8.2 \
    php8.2-mysql \
    php8.2-curl \
    php8.2-intl \
    php8.2-zip \
    php8.2-imap \
    php8.2-gd \
    php8.2-soap \
    php8.2-ldap \
    php8.2-xml \
    php8.2-mbstring \
    php8.2-bcmath \
    zlib1g-dev libxml2-dev

# Configure Apache Modules
# 1. Disable mpm_event (default). Do not enable mpm_prefork here; it is loaded explicitly from mounted apache2.conf to avoid "No MPM loaded".
# 2. Enable rewrite and ssl
RUN a2dismod mpm_event && \
    a2enmod php8.2 && \
    a2enmod rewrite && \
    a2enmod ssl

# Install Node.js and Tools
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g @angular/cli && \
    npm install --global yarn

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Disable default site
RUN a2dissite 000-default.conf

# Copy config into image (no bind mounts required for Coolify/remote deploy)
COPY docker/config/php/php.ini /etc/php/8.2/apache2/php.ini
COPY docker/config/apache/apache2.conf /etc/apache2/apache2.conf
COPY docker/config/apache/sites.conf /etc/apache2/sites-enabled/sites.conf
# SSL certs are created at runtime by startup.sh if missing

# Set up working directory and permissions
WORKDIR /var/www/html/
RUN chown -R www-data:www-data /var/www/html/ && \
    chmod -R 755 /var/www/html/

# Expose ports
EXPOSE 80 443

# Ensure startup.sh is executable (if it exists in your build context)
# COPY startup.sh /usr/local/bin/startup.sh
# RUN chmod +x /usr/local/bin/startup.sh

# Use the startup script to launch
CMD ["/bin/bash", "startup.sh"]
