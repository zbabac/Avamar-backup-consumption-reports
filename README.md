# Avamar_backup_consumption
*Bash script to add feature of giving usage quota to tenants, checking it, and sending emails about consumption*

# DISCLAIMER #
This script works in production environment. You're free to use it according to the GNU license. The script is executed as admin, it calls psql to query database, so it is powerfull tool! GNU v3 states that you accept all liability for usage, but I will emphasize it:

Read it carefully and check if it suits your environment. I accept no damage that may be done to your data. The script works fine in my environment (Avamar 18), but if you decide to use it in yours, you accept all liability for using it and for any damage that may come as result of the usage. I am just giving it to anyone whom it may help in solving data measurement and reporting in Avamar.
*REMEMBER: responsibility for the system is yours and by using these scripts, you are accepting the sole responsibility. Also, you are accepting the whole liability that any alteration of the script by you, and damage that you may cause to your system by doing that.*

## Background ##
Avamar is a great system for BaaS and works great in our production environment. It just lacks the option to charge customers per certain amounts of backup used.

So, if you have the flat system, then you should probably stop reading. If you need a basic feature for charging per GB of data that customer keeps in the Avamar backup, then this is the thing.

## Explanation of tariff model ##

These scripts don't measure the amount of data stored in Avamar and DD. Our tariff model is to measure how much of data the client has defined for backup. E.g. client has a folder protected on its machine that has total 18GB of data. The first backup will send that data to Avamar, it will compress it and deduplicate and store it on DD. It will take, let's say 2GB. But, we charge 18GB, because he/she wants to protect 18GB!

The idea is that we define quotas for each customer, for example this one will buy 30GB of space for backup. We want to check consumption every day, if it passes 80% of the defined quota, we send warning emeil.
If they pass defined quota, we send Alert email. If usage is lower we don't spam them, so we don't send anything.

Also, at the end of the month, we send monthly report, which is the same as the first script, it's just unconditional, we send it at every run.

The script is written in bash, with usage of AWK for parsing the data fetched by psql from the table v_activities_2. I used the column bytes_protected.

**If you want some other model, then you can use some other value from this table. The principle should be the same.**

## Usage ##
First, create dir in admin home:

`mkdir /home/admin/avamar_quotas`

`cd /home/admin/avamar_quotas`

then copy those 3 files there and add execute permission:

`chmod ugo+x avamar_quotas*.sh`

and you're set to go. You can execute individual scripts or add crontab to admin user like in the samples.

**Just don't forget to edit `avamar_tenants.csv` and replace tenant1, etc with your real tenant names, otherwise the script will not find any clients.**

You can run script interactively, it will display some basic info and you can check if it found the tenants and the consumption.

Or you can run it via cron, like below.

For daily script execute as root:

`crontab -u admin -e`

insert new line:

`45 12 * * * cd /home/admin/avamar_quotas;./avamar_quotas.z.sh & > /home/admin/quota.log`


For monthly script execute as root:

`crontab -u admin -e`

insert new line:

`18 14 01-31 * * [[ "$(date --date=tomorrow +\%d)" == "01" ]] && cd /home/admin/avamar_quotas;./avamar_quotas.z.monthly.sh & > /home/admin/quota.log`
