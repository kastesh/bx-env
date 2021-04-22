FROM percona:5.7

COPY --chown=mysql:root ./bx.cnf /etc/my.cnf.d/bx.cnf
COPY --chown=mysql:root ./bx.cnf /etc/mysql/conf.d/bx.cnf

USER root

RUN usermod -u 1000 mysql && \
    chown -R mysql:root \
    /var/lib/mysql /var/run/mysqld \
    /etc/sysconfig/mysql /etc/my.cnf.d

USER mysql

RUN chmod 664 /etc/my.cnf.d/bx.cnf

