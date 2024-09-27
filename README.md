
# 💾 Docker 기반 MySQL 백업 및 복원 자동화

## 📘 개요

Docker 기반의 MySQL 데이터베이스에서 주기적인 백업을 통해 **장애 복구, 데이터 마이그레이션, 안정성, 버전 관리**에 대한 이점을 얻을 수 있습니다. 이는 안정적이고 복구 가능한 시스템 운영에 중요한 부분입니다.

이 문서에서는 Docker 환경에서 실행 중인 MySQL 데이터베이스의 백업과 복원 과정을 자동화하는 방법을 다루고 있습니다. **백업 파일을 생성하는 과정**, **새로운 컨테이너에서 복원하는 절차**, 그리고 **자동화된 백업 및 복원**을 위해 **crontab**을 설정하는 과정을 단계별로 설명합니다.

## 🔧 과정

### 1. MySQL 컨테이너에서 Database를 백업

`docker ps` 명령어를 통해 MySQL 컨테이너가 정상적으로 동작하고 있는지 확인합니다.

```bash
$ docker ps
CONTAINER ID   IMAGE                       COMMAND                  CREATED          STATUS                      PORTS                                                           NAMES
85e1b6147565   mysql:latest                "docker-entrypoint.s…"   14 minutes ago   Up 14 minutes (healthy)     0.0.0.0:3306->3306/tcp, :::3306->3306/tcp, 33060/tcp            mysqldb
```

`mysqldump` 명령어를 통해 MySQL 컨테이너에서 원하는 데이터베이스를 백업합니다.

`fisa`라는 데이터베이스를 `mysqldump`로 백업하겠습니다.

⚠️ **트러블슈팅**

```bash
$ docker exec mysqldb mysqldump -u root -p fisa > /home/username/step06Compose/dump.sql
```

원래 의도라면 Enter password: 이후 계정의 비밀번호를 입력해야 하지만, Access Denied 오류가 발생하였습니다.

보안상의 이슈가 발생하긴 하지만, `-p` 옵션 뒤에 명시적으로 비밀번호를 추가하여 접속이 가능합니다. 

주의할 점은 p 뒤에 띄어쓰기 없이 바로 비밀번호를 작은따옴표(`’`) 으로 감싸야 한다는 점입니다.

```bash
$ docker exec mysqldb mysqldump -u root -p'root' fisa > /home/username/step06Compose/dump.sql
mysqldump: [Warning] Using a password on the command line interface can be insecure.
```

백업 파일이 생성된 것을 확인할 수 있습니다.

```bash
~step06Compose$ ls
docker-compose.yml  Dockerfile  dump.sql  step18_empApp-0.0.1-SNAPSHOT.jar
```

**dump.sql**
```SQL
-- MySQL dump 10.13  Distrib 9.0.1, for Linux (aarch64)
--
-- Host: localhost    Database: fisa
-- ------------------------------------------------------
-- Server version	9.0.1

/* 이하 내용 생략 */
```

### 2. Volume 생성 및 새로운 MySQL Docker Container 생성

```bash
# 볼륨 생성
$ docker volume create mysql_data_volume

# 새로운 MySQL 컨테이너 실행
$ docker run --name newmysqldb \
-e MYSQL_ROOT_PASSWORD=root \
-v mysql_data_volume:/var/lib/mysql \
-d -p 3307:3306 mysql:latest
```

- `-e` : MySQL root 계정의 비밀번호 설정
- `-v` : Docker 볼륨을 MySQL 데이터 디렉토리에 마운트
- 포트는 기존 컨테이너와 겹치지 않도록 `3307`로 설정

```bash
$ docker exec -it newmysqldb bash

bash-5.1# mysql -u root -p

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
4 rows in set (0.02 sec)
```

MySQL 컨테이너가 정상적으로 동작하는 것을 확인했습니다.

### 3. 데이터베이스 생성 후 import

![image](https://github.com/user-attachments/assets/6c18cde2-a0fc-4d13-9a80-3868714711b0)

컨테이너 내부에서 `mysql`에 접속한 뒤, `fisa`라는 데이터베이스를 생성합니다.

**Docker 외부에서 MySQL 파일 import**

```bash
$ docker exec -i newmysqldb \
mysql -u root -p'root' fisa < /home/username/step06Compose/dump.sql
```

백업 파일을 import한 후, 데이터를 성공적으로 복원한 것을 확인할 수 있습니다.

![image](https://github.com/user-attachments/assets/422d63ac-5187-421f-b486-6f35eac49fca)

## 🕒 Crontab으로 Dump 자동화

`crontab`을 사용하여 주기적으로 MySQL dump 파일을 생성하고 import하는 방법을 자동화할 수 있습니다.

### 1. Shell Script 작성

Dump 파일을 생성하는 Shell Script를 작성합니다.

**mysql_dump.sh**

```bash
#!/bin/bash

# MySQL 컨테이너 이름 설정
CONTAINER_NAME="newmysqldb"

# 날짜와 시간 형식 설정
DATE=$(date +"%Y%m%d_%H%M%S")

# 백업 파일 이름에 날짜와 시간을 포함
DUMP_FILE="/home/username/step06Compose/dump_${DATE}.sql"

# MySQL 데이터베이스 백업(dump 생성)
docker exec $CONTAINER_NAME mysqldump -u root -p'root' fisa > $DUMP_FILE

echo "Backup created: $DUMP_FILE"
```

**백업 파일 생성 확인**

```bash
$ chmod u+x ./mysql_dump.sh
$ ./mysql_dump.sh
$ ll
total 54212
-rw-rw-r--  1 username username     2631 Sep 27 15:42 dump_20240927_154231.sql
-rwxrw-r--  1 username username      409 Sep 27 15:42 mysql_dump.sh*
```

### 2. Crontab 자동화

Dump 파일을 주기적으로 생성하기 위해 `crontab`에 작업을 추가합니다.

빠른 테스트를 위해 **1분마다 dump 파일을 생성**하는 방식으로 설정하겠습니다.

**Crontab 편집 및 작업 추가**

```bash
$ crontab -e
```

```bash
* * * * * /home/username/step06Compose/mysql_dump.sh
```

**결과**

1분마다 `dump.sql` 파일이 생성되는 것을 확인할 수 있습니다.

![image](https://github.com/user-attachments/assets/bbf98512-4506-46f5-a703-97a3942dafc1)

## 🏁 결론
MySQL 데이터를 다른 MySQL 인스턴스로 옮겨야 할 때 해당 방법을 통해 간편하게 옮길 수 있습니다. 

- 운영 환경 DB를 개발 환경 DB로 마이그레이션
- MySQL 재설치
- 데이터 백업, 아카이빙

Docker 기반의 MySQL 환경에서 백업과 복원하는 방법과 Dump 파일을 주기적으로 백업하는 과정을 자동화하는 방법에 대해 알아보았습니다.

## 🗒️ 참고자료

- [MySQL 데이터를 Dump(Export)하고 Import 하기](https://musma.github.io/2019/02/12/mysql-dump-and-import.html)

