#!/bin/bash
#
# Have you got a lot of projects that use Docker, and want nightly
# dumps of your dev MySQL databases?
# You're in luck... in a disturbingly crufty sort of way.
# This script can be called from your crontab to do the nightly dumps,
# keeping your project databases for a selected timeframe
#
# SjG <github@fogbound.net> 2022-03-15

# Target directory. Directories (named for the date) will be created under this to store the db dumps.
DB_BACKUPDIR="/mnt/tmp_backups/dev/docker"
# How many day's worth do you want to keep?
DAYS_TO_KEEP=30
# A MySQL database user with permissions to query the database list from MySQL and dump databases
DB_USER="rooty"
# The MySQL Password for that user. Yeah, this is insecure. It's for your dev box, not production!!
DB_PASSWD="töötT00t"
# Where will we see these dockerized database servers?
HOSTNAME="localhost"
# Path to all of the docker directories (where your compose.yaml lives for the instance)
DOCKER_INSTS=("/home/samuelg/project/get-rich-quick/docker" "/home/samuelg/project/twin-primes-conjecture-proof/docker" "/home/samuelg/project/all-my-passwords-in-plain-text/docker")

# How many two-second periods to wait for MySQL to be ready when you bring up the docker instance
MAX_MYSQL_WAIT_CYCLES=5
# Where do mysql, mysqladmin, and mysqldump binaries live?
MYSQL_PATH="/opt/local/bin"
# Docker Path... where do the dockers park?
DOCKER_PATH="/usr/local/bin"

#
# OK, you can stop reading at this point unless you wanna feel queasy (queasier?)
#

is_mysql_alive() {
  $MYSQL_PATH/mysqladmin ping --user=$DB_USER -h $HOSTNAME --protocol tcp --password=$DB_PASSWD > /dev/null 2>&1
  returned_value=$?
  echo ${returned_value}
}

DB_BACKUP="$DB_BACKUPDIR/$(date +%Y-%m-%d)"
echo "Running DB backups $(date +%Y-%m-%d)"
echo "Shutting down docker instances in prep for backups"
for i in "${DOCKER_INSTS[@]}"; do
  cd "$i"
  $DOCKER_PATH/docker-compose down
done
# iterate through
for i in "${DOCKER_INSTS[@]}"; do
  cd "$i"
  echo "Building docker instance in ${i}"
  $DOCKER_PATH/docker-compose build > /dev/null 2>&1
  if [ $? -ne 0 ]; then { echo "Compose build failed, aborting." ; exit 1; } fi
  echo "Bringing up docker instance"
  $DOCKER_PATH/docker-compose up -d > /dev/null 2>&1
  if [ $? -ne 0 ]; then { echo "Compose up failed, aborting." ; exit 1; } fi
  echo "Waiting 2 seconds..."
  sleep 2
  k=0
  until [ "$(is_mysql_alive)" -eq 0 ]; do
    let g=$((($MAX_MYSQL_WAIT_CYCLES - $k) * 2))
    echo "---> Waiting up to ${g} seconds for MySQL to be ready..."
    sleep 5
    let "k+=1"
    if [ "$k" -eq "$MAX_MYSQL_WAIT_CYCLES" ]; then
       echo "Failed to connect to MySQL. Not raging against the dying of the script."
       exit 1;
    fi
  done
  echo "Dumping to $DB_BACKUP" 1>&2

  # Create the backup directory
  mkdir -p $DB_BACKUP

  echo "Purging backups older than ${DAYS_TO_KEEP} days"
  # Remove backups older than KEEP days
  find $DB_BACKUPDIR -maxdepth 1 -type d -mtime +$DAYS_TO_KEEP -exec rm -r {} \;

  # Backup each database on the system
  for db in $($MYSQL_PATH/mysql --user=$DB_USER -h $HOSTNAME --protocol tcp --password=$DB_PASSWD -e 'show databases' -s --skip-column-names | grep -viE '(test|performance_schema|information_schema|mysql|sys)'); do
    echo "Dumping ${db}"
    $MYSQL_PATH/mysqldump --user=$DB_USER -h $HOSTNAME --protocol tcp --password=$DB_PASSWD --events --opt --single-transaction $db | gzip >"$DB_BACKUP/mysqldump-$HOSTNAME-$db-$(date +%Y-%m-%d).gz"
  done
  echo "Shutting down docker instance"
  $DOCKER_PATH/docker-compose down
done
