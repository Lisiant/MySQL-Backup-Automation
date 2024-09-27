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
