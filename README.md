# db_dump_doc
Bash script to dump MySQL databases from docker instances

Have you got a lot of projects that use Docker, and want nightly dumps of your dev MySQL databases?

You're in luck... in a disturbingly crufty sort of way. This script dumps all databases (excluding system and test database) from each of the specified Docker instances, and keeps the dum files around for a selected timeframe.

Edit the parameters at the top of the file, and call it from your crontab.

## DOs
* Use this to dump dev databases so you can write risky migrations or updates. If necessary, you can just restore your database to last's night's version.
* Use the dumped database when transferring your dev environment to another machine.
* Note that if you've left a Docker instance running, this script will shut it down when it runs.

## DON'Ts
* Don't use this on a production server or anywhere that the accounts or data are sensitive.
* Don't blame me if it doesn't do things the way you think it should, or if it breaks something. It worked for me. That's the only guarantee offered here.