#!/bin/bash

SERVER_IP="13.78.48.145"
BASE_DIR="/tmp/ucd_install_tmp"
HOSTNAME=$(hostname -s)
PROPERTIES_FILE="install.properties.$HOSTNAME"
AGENT="/opt/ibm-ucd/agent/bin/agent"
JRE_FOLDER=$(find /usr -type d -name jre|head -1)
TEMP_FILE="/tmp/install.tmp"

/bin/cat <<EOM >$TEMP_FILE
IBM\ UrbanCode\ Deploy/java.home=<JRE_FOLDER>
agent.HttpFailoverHandler.disabled=null
agent.jms.full_encryption=false
locked/agent.brokerUrl=failover\:(ah3\://<SERVER_IP>\:7918)
locked/agent.home=/opt/ibm-ucd/agent
locked/agent.jms.remote.host=<SERVER_IP>
locked/agent.jms.remote.port=7918
locked/agent.mutual_auth=false
locked/agent.name=<HOSTNAME>
system.default.encoding=UTF-8
verify.server.identity=false
EOM

JRE_FOLDER=$(find /usr -type d -name jre|head -1)
$JRE_FOLDER/bin/java -version 2>>/dev/null
RC=$?

if [[ $RC -gt "0" ]] ; then
yum -y install java >> $HOSTNAME.install.log
fi

# Previous stuff cleanup if any
kill -9 `ps -eaf|grep ibm-ucd|grep -v grep|awk '{print $2}'` 2>>/dev/null
rm -rf $BASE_DIR
rm -rf "/opt/ibm-ucd"

mkdir $BASE_DIR
cd $BASE_DIR

wget --quiet --no-check-certificate https://"$SERVER_IP":8443/tools/ibm-ucd-agent.zip
if [[ "$?" -eq "0" ]]; then
unzip ibm-ucd-agent.zip >> $HOSTNAME.install.log
cd ibm-ucd-agent-install

else

echo "Agent not downloaded. Exiting"
exit 1

fi

if [[ -e $TEMP_FILE ]] ; then

cp $TEMP_FILE $PROPERTIES_FILE
sed -i "s#<JRE_FOLDER>#${JRE_FOLDER}#g" $PROPERTIES_FILE
sed -i "s/<HOSTNAME>/${HOSTNAME}/g" $PROPERTIES_FILE
sed -i "s/<SERVER_IP>/${SERVER_IP}/g" $PROPERTIES_FILE

./install-agent-from-file.sh $PROPERTIES_FILE >> $HOSTNAME.install.log

if [[ "$?" -gt "0" ]]; then
echo "Instalation not successful. Exiting"
exit
fi

if [[ -e $AGENT ]]; then

$AGENT start

else

echo "Installation was not complete. Exiting"
exit

fi

sleep 20

netstat -aon | grep 7918 >/dev/null
if [[ "$?" -eq "0" ]]; then
echo "UCD agent successfully installed and started"
else
echo "Issue in the setup."
fi

else

echo "Template does not exist. Exiting.."
echo 2

fi
