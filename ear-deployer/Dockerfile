FROM alpine:3.6

RUN mkdir -p /root
ENV HOME /root
COPY cpanfile /

RUN apk add --no-cache build-base openssl perl \
	wget curl gnupg perl-dev openssh gmp-dev redis py-pip perl-net-ssleay perl-io-socket-ssl perl-libwww perl-lwp-protocol-https perl-xml-simple && \
	pip install --no-cache-dir s3cmd && \
	rm -rf /var/cache/apk/* 

COPY cpanfile /

RUN curl -L https://cpanmin.us | perl - App::cpanminus && \
	cpanm -f --installdeps . -M https://cpan.metacpan.org && \
	rm -rf /root/.cpanm && \
	apk del build-base gnupg gmp-dev perl-dev gcc

COPY app /app

RUN cd /app && pp -a template -M Crypt::Blowfish -M JSON --lib=lib  \
	--clean -o /docker-deploy-ear deploy-ear.pl && \
	rm -rf /app

CMD /docker-deploy-ear -e ${ENV} -b ${BUILDNUMBER} -c ${ENV_CONFIG_FILE}
