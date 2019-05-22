FROM alpine:3.9

COPY _files/docker-php-* /usr/local/bin/
COPY src /var/www/html

ENV PHPIZE_DEPS \
	autoconf \
	dpkg-dev dpkg \
	file \
	g++ \
	gcc \
	libc-dev \
	make \
	pkgconf \
	re2c

ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2" PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" PHP_INI_DIR="/usr/local/etc/php"

RUN apk add --no-cache \
	ca-certificates \
	curl \
	tar \
	xz \
	openssl; \
	set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
	# Download PHP 7.4 source code
	set -xe; \
	\
	apk add --no-cache --virtual .fetch-deps \
	gnupg \
	git \
	wget \
	autoconf \
	make \
	; \
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	git clone http://git.php.net/repository/php-src.git php; \
	cd php; \
	git checkout PHP-7.4; \
	./buildconf --force; \
	rm -rf .git; \
	cd /usr/src; \
	tar -cJf php.tar.xz php; \
	rm -rf php; \
	\
	apk del --no-network .fetch-deps; \
	# Compile PHP 7.4
	set -xe; \
	apk add --no-cache --virtual .build-deps \
	$PHPIZE_DEPS \
	coreutils \
	curl-dev \
	libedit-dev \
	openssl-dev \
	libffi-dev \
	libxml2-dev \
	bison \
	oniguruma-dev \
	\
	&& export CFLAGS="$PHP_CFLAGS" \
	CPPFLAGS="$PHP_CFLAGS" \
	LDFLAGS="$PHP_LDFLAGS" \
	&& docker-php-source extract \
	&& cd /usr/src/php \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
	--build="$gnuArch" \
	--with-config-file-path="$PHP_INI_DIR" \
	--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
	--disable-all \
	--enable-option-checking=fatal \
	--without-sqlite3 \
	--with-curl \
	--with-openssl \
	--with-zlib \
	--with-ffi \
	\
	&& make -j "$(nproc)" \
	&& find -type f -name '*.a' -delete \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
	&& make clean \
	&& cp -v php.ini-p* "$PHP_INI_DIR/" \
	\
	&& cd / \
	&& docker-php-source delete \
	\
	&& runDeps="$( \
	scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
	| tr ',' '\n' \
	| sort -u \
	| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache $runDeps \
	&& apk del --no-network .build-deps \
	\
	&& rm -rf /tmp/pear ~/.pearrc; \
	docker-php-ext-install opcache; \
	mv /var/www/html/php.ini-nextphp /usr/local/etc/php/conf.d/php-nextphp.ini && \
	chown root:root /var/www/html && \
	chmod 0755 -R /var/www/html

WORKDIR /var/www/html
EXPOSE 80

ENTRYPOINT ["docker-php-entrypoint"]

CMD ["php", "-S", "0.0.0.0:80"]