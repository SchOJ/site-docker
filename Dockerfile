FROM debian:jessie

# DMOJ Site Dockerfile
# If you are using external judgers, UNCOMMENT last two lines.

RUN mkdir /site /uwsgi

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
    apt-get update && \
    debconf-set-selections <<< 'mysql-server mysql-server/root_password password Your-passwORD' && \
    apt-get install -y nano debconf-utils mysql-client mysql-server libmysqlclient-dev gnupg wget git gcc g++ make python-dev libxml2-dev libxslt1-dev zlib1g-dev gettext curl wget openssl ruby-sass vim supervisor uwsgi uwsgi-plugin-python nginx
RUN echo 'deb http://mirrors.ustc.edu.cn/nodesource/deb/node_8.x stretch main' >> /etc/apt/sources.list && \
    gpg --keyserver keyserver.ubuntu.com --recv-keys 68576280 && \
    gpg --armor --export 68576280 | apt-key add - && \
    apt-get update && apt-get install -y nodejs 
RUN wget -q --no-check-certificate -O- https://bootstrap.pypa.io/get-pip.py | python
RUN npm install -g pleeease-cli --registry=https://registry.npm.taobao.org --unsafe-perm && \
    apt-get clean

RUN git clone https://gitee.com/crlf/site.git /site

WORKDIR /site
RUN git submodule init && \
    git submodule update
RUN pip install -r requirements.txt && \
    pip install mysqlclient django_select2 websocket-client && \
    npm install qu ws simplesets

COPY local_settings.py /site/dmoj

WORKDIR /site
RUN sh make_style.sh && \
    echo yes | python manage.py collectstatic && \
    python manage.py compilemessages && \
    python manage.py compilejsi18n

RUN service mysql start && \
    mysql -uroot -pdmoj --execute="CREATE DATABASE dmoj DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" && \
    python manage.py migrate && \
    python manage.py loaddata navbar && \
    python manage.py loaddata language_small && \
# The next line is optional
    python manage.py loaddata demo

COPY uwsgi.ini /uwsgi
COPY site.conf bridged.conf wsevent.conf /etc/supervisor/conf.d/
COPY config.js /site/websocket

RUN rm /etc/nginx/sites-enabled/*
ADD nginx.conf /etc/nginx/sites-enabled

CMD sh /start.sh

EXPOSE 80
# Comment next line if you do not use SSL/TLS.
EXPOSE 443 
EXPOSE 15100
EXPOSE 15101
EXPOSE 15102
# Uncomment below if you need judge from external judgers.
#EXPOSE 9998
#EXPOSE 9999