# Borg Backup Wrapper Scripts

These scripts are wrappers around the main borg backup scripts.

Modules for plain file backup, mysql and postgresql backup exists.

## IMPORTANT NOTICE FOR UPGRADE TO VERSION 4.0 OR HIGHER

*VERSION 4.0* CHANGE

Version 4.0 introduces default borg repository name with `-file` for the `file` module. The repository has to be renamed manual before the next backup or the backup will fail.

*Example:*

Old backup name
```sh
BACKUP_FILE="some-backup-data.borg"
```
Then the file need to be renamed the following way:
`mv some-backup-data.borg some-backup-data-file.borg`

Below changes have to be done after the `file` module backup has been renamed.

With Version 4.0 all backup sets are prefixed with the module name and a comma. For exmaple the files backup will have backup set "file,YYYY-MM-DD" as base name.

To make sure prune of archives will work the `_borg_backup_set_prefix_cleanup.sh` script has to be run once. It has the same config (-c), debug (-d) and dry run (-n) options like the main scripts. It is recommended to run with the dry-run script first and see that the list of chagnes matches the expectation.

The zabbix module has the prefix changed from `zabbix-settings-` to `zabbix,settings-` to match the new archive set rules

## Recommended setup

git clone this repostory into the target folder:
`git clone <repo> borg`

And in there create the needed settings files.

Now the core scripts can be updated with a simple
`git pull`

No settings files will be overwritten

## Possible command line options

### `-c <config folder>`
if this is not given, /usr/local/scripts/borg/ is used

### `-L <log folder>`
override config set and default log folder

### `-T <tag>`
create one time stand alone backup prefixed with tag name

### `-D <tag backup set>`
remove a tagged backup set, full name must be given

### `-b <borg executable>`
override the default borg executable found in path

### `-P`
print list of archives created

### `-V`
verify if repository exists, if not abort

### `-e`
exit after running verify `-V`

### `-I`
init repository (must be run first)

### `-Z`
run `borg compact` over given repository

### `-C`
run `borg check` over given repository

#### `-y`
Add `--verify-data` to `borg check`. Only works with `-C`

#### `-p <prefix|glob>`
Only `borg check` data that has given prefix or glob (with *). Only works with `-C`

### `-i`
print out only info

### `-l`
list files during backup

### `-v`
be verbose

### `-d`
debug output all commands

### `-n`
only do dry run

### `-h`
this help page

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

All below have default values if not set in the main settings file
 * COMPRESSION: zstd
 * COMPRESSION_LEVEL: 3
 * ENCRYPTION: none
 * FORCE_VERIFY: false
 * COMPACT_INTERVAL: 1
 * CHECK_INTERVAL: none
 * KEEP_LAST: 0
 * KEEP_HOURS: 0
 * KEEP_DAYS: 7
 * KEEP_WEEKS: 4
 * KEEP_MONTHS: 6
 * KEEP_YEARS: 1

All module settings files can have the following prefixed with `SUB_` to override master settings:
 * SUB_BACKUP_FILE
 * SUB_COMPRESSION
 * SUB_COMPRESSION_LEVEL
 * SUB_COMPACT_INTERVAL
 * SUB_CHECK_INTERVAL
 * SUB_BACKUP_SET
 * SUB_KEEP_LAST
 * SUB_KEEP_HOURS
 * SUB_KEEP_DAYS
 * SUB_KEEP_WEEKS
 * SUB_KEEP_MONTHS
 * SUB_KEEP_YEARS
 * SUB_KEEP_WITHIN

## Setup backup via SSH to remote host on `borg.backup.settings`

For this the following settings are from interest

```
TARGET_USER="";
TARGET_HOST="";
TARGET_PORT="";
```

Note that if `.ssh/config` is used only `TARGET_HOST` needs to be set. Recommened for handling proxy jumps and key files.

and `TARGET_BORG_PATH="";` if the target borg is in a non default path

## Override borg executable in `borg.backup.settings`

`BORG_EXECUTABLE="<full path to borg>"`

## Note on CHECK_INTERVAL and SUB_CHECK_INTERVAL

If set to empty or 0 it will not run an automatic check. If set to 1 it will run a check after each backup. Any other value means days differente to the last check.

Running check manually (`-C`) will not reset the last check timestamp.

Automatic checks always add `--verify-data`, with manual `-C` the option `-y` has to be set.

## File backup settings

On new setups it is recommended to use the `borg.backup.file.setings` and set
`FILE_REPOSITORY_COMPATIBLE`
to `true`

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


## File connection

Running any of the commands below
- borg.backup.file.sh
- borg.backup.gitea.sh
- borg.backup.mysql.sh
- borg.backup.pgsql.sh
- borg.backup.zabbix.sh

1) Run `borg.backup.functions.init.sh` (always)
2) Run `borg.backup.functions.verify.sh` (always)
3) (other code in "file" module)
4) Run `borg.backup.functions.info.sh` (always)
5) Run `borg.backup.functions.compact.sh` (not if one time tag)
6) Run `borg.backup.functions.check.sh` (not if one time tag)
7) Run `borg.backup.functions.close.sh` (always, can be called on error too)
