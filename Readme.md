# Borg Backup Wrapper Scripts

These scripts are wrappers around the main borg backup scripts.

Modules for plain file backup, mysql and postgresql backup exists.

## Recommended setup

git clone this repostory into the target folder:
`git clone <repo> borg`

And in there create the needed settings files.

Now the core scripts can be updated with a simple
`git pull`

No settings files will be overwritten

## Basic Settings

`borg.backup.settings`

This file must be configured, without it the backup will not work

The following must be set or checked:
LOG_FOLDER: default `/var/log/borg.backup/`
TARGET_FOLDER: must be set to a path where the backups can be written
BACKUP_FILE: the folder inside the TARGET_FOLDER that is the target for borg. Must end with `.borg`


Note: BACKUP_FILE is the base name. For all except file (current) a module suffix will be added:

eg:
`foo.name.borg` wil be `foor.name-mysql.borg` for mysql backups.

If `FILE_REPOSITORY_COMPATIBLE` is set to `false` in the borg.backup.file.settings then the file borg name will have `-file` added too. Currently this is not added to stay compatible with older scripts

All module settings files can have the following prefixed with `SUB_` to override master settings:
 * SUB_BACKUP_FILE
 * SUB_COMPRESSION
 * SUB_COMPRESSION_LEVEL
 * SUB_BACKUP_SET
 * SUB_KEEP_LAST
 * SUB_KEEP_HOURS
 * SUB_KEEP_DAYS
 * SUB_KEEP_WEEKS
 * SUB_KEEP_MONTHS
 * SUB_KEEP_YEARS
 * SUB_KEEP_WITHIN

## Setup backup via SSH to remote host

For this the following settings are from interest

```
TARGET_USER="";
TARGET_HOST="";
TARGET_PORT="";
```

Note that if `.ssh/config` is used only `TARGET_HOST` needs to be set. Recommened for handling proxy jumps and key files.

and `TARGET_BORG_PATH="";` if the target borg is in a non default path

## File backup settings

### Config variables


### Control files

```
backup.borg.file.include
backup.borg.file.exclude
```

`backup.borg.file.include` must be set

### File content rules

## PostgreSQL backup settings

This script must be run as the postgres user, normaly `postgres`.
The postgres user must be added to the backup group for this, so that the basic init file can be created in the borg base folder.

### Config variables

Variable | Default | Description
| - | - | - |
DATABASE_FULL_DUMP | | if empty, dump per databse, if set dump all in one file, if set to schema dump only schema
DATABASE_USER | | overide username to connect to database

### Control files

```
backup.borg.pgsql.include
backup.borg.pgsql.exclude
backup.borg.pgsql.schema-only
```

## MySQL backup settings

If non root ident authentication run is used, be sure that the `mysql` user is in the backup group.

### Config variables

Variable | Default | Description
| - | - | - |
DATABASE_FULL_DUMP | | if empty, dump per databse, if set dump all in one file, if set to schema dump only schema
MYSQL_DB_CONFIG | | override file for connection. In modern mariaDB installations it is rcommended to run the script as root or mysql user and use the ident authentication instead.

### Control files

```
backup.borg.mysql.include
backup.borg.mysql.exclude
backup.borg.mysql.schema-only
```

## gitea backup settings

Note that the backup needs the GIT_USER set that runs gitea.
This user is neede to create the temporary dump folder and access for the git files and database.

### Config Variables

Variable | Default | Description
| - | - | - |
GIT_USER | git | The user that runs gitea |
GITEA_TMP | /tmp/gitea/ | Where the temporary dump files from the backup are stored, as user git |
GITEA_BIN | /usr/local/bin/gitea | Where the gitea binary is located |
GITEA_CONFIG | /etc/gitea/app.ini | The configuration file for gitea |


### Control files

There are no control files for gitea backup

## zabbix config backup settings

### Config Variables

Variable | Default | Description
| - | - | - |
ZABBIX_DUMP | /usr/local/bin/zabbix-dump |
ZABBIX_DATABASE | '' | Must be set as either psql or mysql
ZABBIX_CONFIG | '' | if not set uses default location
ZABBIX_UNKNOWN_TABLES | '' | if set, changed to -f (force)

### Control files

There are no control files for zabbix settings backup
