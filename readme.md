# BXEnv

## Назначение

Сборка предназначена для разработки Битрикс и содержит контейнеры:
- php
- mysql
- nginx
- redis
- memcache
- push&pull сервер

>**Внимание!**  
>Сборка рассчитана исключительно на локальную разработку. Использование в продакшене не безопасно!

## Быстрый старт

1. Клонируйте или скачайте репозиторий
2. Конфигурация локальной установки
3. Настройка сайта

### Конфигурация локальной установки
Для конфигурации используете:
```
./mgmt/configure.sh -h
Usage: configure.sh [-vhblC] [-c /path/to/config]
Options:
-h  - show this help message
-v  - enable verbose mode
-c  - config file (default: mgmt/CONFIG)
-b  - build docker images (default: disable)
-l  - local installation; created html folders
-C  - disable configuration creation
```
По умолчанию, данный скрипт создаст два конфигурационных файла:
| Файл | Описание |
| --- | --- |
| `mgmt/CONFIG` | конфигурационный файл, для работы скриптов |
| `.env` | файл, содержащий переменные окружения для docker-compose |

Пример использования:
```
./mgmt/configure.sh -v -l
2020/12/21T23:26: [29311]> Start configuration of Docker Env
URL to the prepared distribution directory: http://distr.bx/distrs
The path on the Docker server where the site directories will be located: /var/bx/sites
The path on the Docker server where the modules will be located: /var/bx/modules
The directory where the bx-env project is located (/vagrant/bx-env):
Log directory: /vagrant/bx-env/logs
Enter default domain name for sites(example ksh.bx): example.bx
Enter default sitename: (default example.bx):
...
```

### Хранилище архивов сайтов
Веб сервер, который хранит бэкапы баз и файлов для тех иили иных версий Bitrix-окружения.
На сервере distr.bx можно найти следующую структуру и файлы:
```
VERSION
|---- SITE_TYPE.zip
|---- SITE_TYPE.sql
```
Где SITE_TYPE.zip - это архив файлов для сайта, а SITE_TYPE.sql -  это бэкап базы; VERSION -  версия продукта, TYPE - тип (например, shop или b24).

Например,
```
ls distrs/20.200.300/
b24.sql  b24.zip  shopcrm.sql  shopcrm.zip  shop.sql  shop.zip
```

### Создание сайта
Для создания контейнеров под сайт, определенного типа используйте следующий скрипт:
```
./mgmt/run_site.sh -h
Usage: run_site.sh -s site_name -p php_version -m mysql_version -a archive_name
Options:
-h  - show this help message
-v  - enable verbose mode
-s  - site name
-p  - php version (default: php72)
-m  - mysql version (default: mysql57)
-a  - archive name (example: 20.200.300/b24)
-c  - config file (default: ./mgmt/CONFIG)
```
Например,
```
mgmt/run_site.sh -a 20.200.300/shop -p php73 -m mysql57 -s shop73.bx -v
```
Выполнит следующие действия:
1. Скачает файлы архивов 20.200.300/shop в каталог сайта
2. Поднимет все необходимые для работы контейнеры

При последюущих запусках для других сайтов:
1. Перезапустит контейнер, если это требуется (например, контейнер bx-nginx при добавлении нового сайта)
2. Запустит недостающие контейнеры (например, второй сайт создан с другой версией php)

### Удаление усстановки
Для удаления установки используете  скрипт:
```
./mgmt/clean_all.sh
```
Полностью удалит все запущенные контейнеры и почистит каталог сайтов.

## Конфигурационный файл
Для настройки используются переменные окружения, указываемые в файле `.env`. Полный список можно найти в файле `.env.default`.  

**BX_PUBLIC_HTML_PATH**  
путь к директории public_html, в которой содержатся директории хостов, монтируется в php и nginx контейнеры и используется для генерации хостов.  

**BX_MODULES_PATH**  
путь к репозиторию modules, требуется для работы с линкованной установкой, монтируется в php и nginx контейнеры  

**BX_LOGS_PATH**  
путь к директории в которой контейнеры должны хранить логи, монтируется в контейнеры, внутри каждый из контейнеров создаст свою папку  

**BX_MYSQL_ROOT_PASSWORD**  
пароль для root пользователя mysql  

**BX_XDEBUG_IP**  
устанавливает опцию xdebug.remote_host  

### Настройки push&pull сервера  

**BX_PUSH_SUB_HOST**  
хост для чтения сообщений  

**BX_PUSH_SUB_PORT**  
порт для чтения сообщений  

**BX_PUSH_PUB_HOST**  
хост для публикации сообщений  

**BX_PUSH_PUB_PORT**  
порт для публикации сообщений  

**BX_PUSH_SECURITY_KEY**  
ключ для подключения к push серверу  

### Автоматическоое создание хостов  

**BX_HOST_AUTOCREATE**    
включает или отключает автогенерацию хостов nginx

**BX_DEFAULT_HOST**  
хост по умолчанию, получит аттрибут default_server в конфиге nginx, оставьте пустым, если не требуется  

**BX_DEFAULT_LOCAL_DOMAIN**  
доменная зона по умолчанию, будет добавлена через точку к имени директории хоста, если директория хоста в имени не содержит доменную зону, оставьте пустым если не требуется  

>Каких-либо проверок или значений по умолчанию в системе нет. Если вы не укажете один или несколько параметров или вообще не создадите `.env` файл, docker-compose подставит пустые строки и выведет соответствующее уведомление.

## Автоподключение хостов  
При запуске контейнера nginx читается список директорий в public_html и для каждой создается виртуальный хост.  
При запуске контейнера php-fpm, если каталог сайта содержит файлы базы и сайта (sites.zip и db.sql), они будут испльзованы  как файлы сайта и для создания базы. Конфигурационные файлы будут созданы (dbconn.php и .settings.php).
Если в директории sites_enabled уже есть конфиг для какого-либо хоста, то он не будет перезаписан.  
Если указана переменная BX_DEFAULT_LOCAL_DOMAIN и имя директории не содержит точку, то для каждого хоста будет автоматически добавлена доменная зона.  
Если указана переменная BX_DEFAULT_HOST, то в конфигурации nginx этот хост будет отмечен хостом по умолчанию.  
