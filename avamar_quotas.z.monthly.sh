#!/bin/bash
exec 2>> /home/admin/cron.log
export PATH=$PATH:/usr/bin:usr/sbin:/home/admin:/home/admin/avamar_quotas
source /home/admin/.bash_profile
cd /home/admin/avamar_quotas

# script generates few email templates to be sent to the client at the end of the month

function create_html()
{

htmlheader=`cat <<EOT
<!DOCTYPE html>
 <head>
  <title>Monthly backup consumption report</title>
  <style> table {
font-family: "Arial","sans-serif";}/* added custom font-family  */

table.one {
margin-bottom: 3em;
border-collapse:collapse;}
td {/* removed the border from the table data rows  */
text-align: center;
width: 10em;
padding: 1em; }
th {/* removed the border from the table heading row  */
text-align: center;
padding: 1em;
background-color: #e8503a;/* added a red background color to the heading cells  */
color: white;}/* added a white font color to the heading text */
tr {
height: 1em;}
table tr:nth-child(even) {/* added all even rows a #eee color  */
background-color: #eee;}
table tr:nth-child(odd) {/* added all odd rows a #fff color  */
background-color:#fff;}</style>
 </head>
  <body>
   <h2>Capacity used for $domain </h2><hr>
 <br>
 <font color=#2F2F2F><h3>Current month usage</h3></font>
 <table>
  <tr>
   <th>Client name</th>
   <th>Amount in GB </th>
    </tr>
EOT`
htmlwarning=`cat <<EOT
<h3>Warning, Quota usege 80% for $domain! <br> </h3><br>`

htmlfooter=` cat << EOT
Assigned backup quota is $quote GB.<br>
<b>Current month usage $billed GB.</b><br>
  <footer>
  <p>Sent by some_name</p>
  <p>Contact information: <a href="mailto:some@somedomain.com">
  some@somedomain.com</a>.</p>
</footer> `

htmlquotaspent=`cat <<EOT
<h3>ALERT, Quota exceeded for $domain! <br> </h3><br>`

# Read result.csv parsing and creation of html table
# v2 reads only $2 var - protected bytes - it seems as the only relevant for counting backup usage
table=`
awk -F, 'BEGIN {print "<tr>"} { bekap += $2} { suma += $3}
{print "<tr><td>" $1 "</td><td>"}
{var=$3}
{printf("%.2f", var/1073741824)} {print " GB"}
{print "</td></tr>"}
END { printf("<tr><td><b>Stored in backup </b></td><td><b>%.2f GB</b></td></tr> <tr><td><b>Amount at the source </b></td><td><b>%.2f GB</b></td></tr></table>",suma/1073741824, bekap/1073741824)}' result.csv
`

}

function send_mail()
{
# to is var read with mccli tool from DD - mail address of the domain!
to=`mccli domain show --name=/$domain |grep Email|awk -F" " '{print $2}'`;

# create email header
(
echo "From: dd_email@domain.com";
echo "To: ${to}";
echo "Subject: Backup report for $domain";
echo "Content-Type: text/html";
echo "MIME-Version: 1.0";
echo "";
echo "${mail}";
) | /usr/sbin/sendmail -t
}

function send_mail_ict()
{
# optional: send mail to youself

to="your_mail@some.com"

# create email header
(
echo "From: dd_email@domain.com";
echo "To: ${to}";
echo "Subject: Backup report for $domain";
echo "Content-Type: text/html";
echo "MIME-Version: 1.0";
echo "";
echo "${mail}";
) | /usr/sbin/sendmail -t
}

echo `date`
for t in `cat avamar_tenants.csv`; do
# read file where tenants are defined + their quota in form (tenant,quota) in GBs
# tenant1,100
# tenant2,1024

domain=`echo $t|awk -F, '{print $1}'`
quote=`echo $t|awk -F, '{print $2}'`
warn_level=`echo $t|awk -F, 'BEGIN { level="'$quote'"*0.8 }END{print level}'`
echo ====================================
echo Report for domain $domain
echo Defined quota $quote GB
# Read data from DB for period "now-currentmonth" per domain
psql -p 5555 mcdb -t -A -F"," -c "select client_name,max(bytes_protected),max(bytes_scanned) from v_activities_2 where date_trunc('month', recorded_date) = date_trunc('month', current_date) and domain= '/$domain' group by client_name;" > result.csv

# Sum of all backups from DB is stored in result.csv
# v2 read only $3

sum=0
TEMP2=0
total_backup=0
for i in `cat result.csv`; do TEMP1=`echo $i | awk -F, '{print $3}'`; TEMP2=`echo $i | awk -F, 'BEGIN { tmp1="'$TEMP1'" } {tmp2="'$TEMP2'"}{tmp2+=tmp1}END{print tmp2}'` ; CLIENT=`echo $i | awk -F, '{print $2}'`; total_backup=`echo $i | awk -F, 'BEGIN { client1="'$CLIENT'" } {total1="'$total_backup'"}{total1+=client1}END{print total1}'` ; done;
# sum_float converted to float with 2 decimal points
sum_float=`bc -l <<< "scale=3; $TEMP2/1073741824"`
total_backup=`bc -l <<< "scale=3; $total_backup/1073741824"`
echo "Scanned $sum_float GB"
echo "Total stored in backup $total_backup GB"

# compare sum_float and quote as float - bash supports only int
# IF compared=1 THEN sum_float LT quote - quota exceeded!
compared1=`echo $total_backup'>'$quote | bc -l`
compared2=`echo $sum_float'>'$quote | bc -l`
compared3=`echo $sum_float'>'$total_backup | bc -l`

if [ $compared3 -eq 1 ]; then
   billed=$sum_float
else 
   billed=$total_backup
fi
compared_warn=`echo $billed'>'$warn_level | bc -l`

create_html


if [[ $compared1 -eq 1 || $compared2 -eq 1 ]]; then
  mail=$htmlheader$table$htmlquotaspent$htmlfooter
else
  if [[ $compared_warn -eq 1 ]]; then
     mail=$htmlheader$table$htmlwarning$htmlfooter
  else
     mail=$htmlheader$table$htmlfooter
  fi
fi

# send monthly report
send_mail
send_mail_ict

# this can be put in cron to send at the last day of the month: (as root)# crontab -u admin -e
# 18 14 01-31 * * [[ "$(date --date=tomorrow +\%d)" == "01" ]] && cd /home/admin/avamar_quotas;./avamar_quotas.z.monthly.sh & > /home/admin/quota.log

echo ====================================

done

