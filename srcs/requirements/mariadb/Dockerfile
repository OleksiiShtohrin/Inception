FROM debian:12

RUN apt-get update && apt-get install -y mariadb-server

COPY conf/my.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init-db.sh /usr/local/bin/init-db.sh

RUN chmod +x /usr/local/bin/init-db.sh

CMD ["/usr/local/bin/init-db.sh"]