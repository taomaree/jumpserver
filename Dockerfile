FROM ubuntu:18.04 AS build

ENV TZ=Asia/Shanghai LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive jumpserver=1.5.4 luna=1.5.4

WORKDIR /tmp

RUN sed -i -e 's@ .*.ubuntu.com@ http://mirrors.163.com@g' -e 's@ .*.debian.org@ http://mirrors.163.com@g' /etc/apt/sources.list; \
    apt-get update ; apt-get install -y wget curl git rsync python3-dev python3-pip ; \
    cd /tmp; git clone https://github.com/jumpserver/jumpserver.git; cd jumpserver; git checkout $jumpserver  ; \
    cd /tmp; git clone https://github.com/jumpserver/luna.git; cd luna; git checkout $luna ;\
    mkdir -p /app ; \
    rsync -Pav --exclude=.git /tmp/jumpserver /app ;\
    rsync -Pav --exclude=.git /tmp/luna /app
   
    
FROM ubuntu:18.04

ENV TZ=Asia/Shanghai LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive

COPY --from=build /app  /app/

RUN sed -i -e 's@ .*.ubuntu.com@ http://mirrors.163.com@g' -e 's@ .*.debian.org@ http://mirrors.163.com@g' /etc/apt/sources.list; \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates libhiredis-dev \
      python3-dev python3-pip python3-setuptools python3-wheel \
      nginx default-mysql-client runit cron ;\
    mkdir -p /etc/service/nginx /etc/service/jumpserver /etc/service/cron ;\
    bash -c 'echo -e "#!/bin/bash\nexec /usr/sbin/nginx -g \"daemon off;\"" > /etc/service/nginx/run' ;\
    bash -c 'echo -e "#!/bin/bash\nexec /app/jumpserver/jms start " > /etc/service/jumpserver/run' ;\
    bash -c 'echo -e "#!/bin/bash\nexec /usr/sbin/cron -f" > /etc/service/cron/run' ;\
    chmod 755 /etc/service/nginx/run /etc/service/jumpserver/run /etc/service/cron/run ;\
    sed -i '/session    required     pam_loginuid.so/c\#session    required   pam_loginuid.so' /etc/pam.d/cron ;\
    bash -c 'echo "0 3 * * * /bin/bash /mysql_backup.sh >> /var/log/mysql_backup.log 2>&1" > /etc/cron.d/mysql_backup' ;\
    apt-get install -y $(cat /app/jumpserver/requirements/deb_requirements.txt) ;\
    pip3 install -r /app/jumpserver/requirements/requirements.txt 
    

ADD default.conf /etc/nginx/sites-enabled/default

ADD mysql_backup.sh /

CMD ["runsvdir", "/etc/service"]
