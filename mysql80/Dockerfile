FROM percona:8.0

COPY --chown=mysql:root ./bx.cnf /etc/my.cnf.d/bx.cnf
COPY --chown=root:root ./bx.cnf /etc/mysql/conf.d/bx.cnf

RUN chmod 664 /etc/my.cnf.d/bx.cnf
