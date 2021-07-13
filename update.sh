#!/bin/sh
# Contribute: https://raw.githubusercontent.com/khoahoc/access_point/main/update.sh

###############################################################################################################################
###                                             SYSTEM INFO
###############################################################################################################################

# Lay MAC address cua thiet bi hien tai
getCurrentAPMacAddress(){
	## Mac should be br-wan
	local MAC_BRWAN=`ifconfig | grep br-wan | awk '{print $5}'` 

	if [ "${#MAC_BRWAN}" -gt 1 ]                                       
	then                                                   
	    MAC=$MAC_BRWAN
	else
		echo "Not detected MAC: $MAC on this model! Please contact sysadmin@sudosys.com for support this device." >&2; exit 1
	fi
}

# Lay WIFI ID tren wifi.sudosys.com
getWifiID()
{
	WIFI_AP_ID=`wget --no-check-certificate -O - -q "https://wifi.sudosys.com/public_check_added_device/$MAC"`

	if  [ -z "$WIFI_AP_ID" ] ; then
	  printf "Not found this device on the portal. \n Please add device on wifi.sudosys.com first!" >&2; exit 1
	fi	
}

# Lay Local IP tren wifi.sudosys.com
getLocalNatIP()
{
	LOCAL_NAT_IP=`wget --no-check-certificate -O - -q "https://wifi.sudosys.com/public_get_private_ip/$MAC"`
	if  [ -z "${#LOCAL_NAT_IP}" ]
	then
	  echo "Cannot generate local IP. Please contact sysadmin@sudosys.com for support." >&2; exit 1
	fi
}


# Bat dau qua trinh cai dat
## Khoi tao gia tri
getCurrentAPMacAddress
getWifiID
getLocalNatIP

## Print thong tin he thong
printf "\n
---------====[ WIFI V1.0 INSTALLATION ACCESS POINT PROGRAM ] ====---------
Your Mac Address: $MAC
Your Wifi ID: $WIFI_AP_ID 
Your Local NAT IP: $LOCAL_NAT_IP \n\n\n"

echo "===============================  WIFI SCRIPT   ============================================="
###############################################################################################################################
###                                             WIFI SCRIPT
###############################################################################################################################

generateNewUpdateScript()
{
    wget --no-check-certificate https://raw.githubusercontent.com/khoahoc/access_point/main/update.sh -O /tmp/update.sh -q 
}

compareUpdateScript()
{
    generateNewUpdateScript
    currentUpdateScript=`sha256sum /etc/update.sh  | awk '{print $1}'`
    newUpdateScript=`sha256sum /tmp/update.sh  | awk '{print $1}'`
    if [ $currentUpdateScript == $newUpdateScript ]
    then
        printf "Update Script matched\n"
    else
        printf "Updated new Wifi Script\n"
        mv /tmp/update.sh /etc/update.sh
    fi
}

# Setup Update Script
if [ -f "/etc/update.sh" ]; 
then
    compareUpdateScript
else 
    echo "Being download new Update script and put to /tmp/update.sh"
    generateNewUpdateScript
    mv /tmp/update.sh /etc/update.sh
fi

echo "=================================================================================="

echo "===============================  AUTOSSH   ============================================="
###############################################################################################################################
###                                             AUTO SSSH
###############################################################################################################################

isAutoSSHRunning()
{
    autoSSH_STATUS=`ps  | grep autossh | wc -l`
    if [ $autoSSH_STATUS -gt 1 ]
    then
        printf "AutoSSH: OK\n"
    else 
        /etc/init.d/autossh restart
        printf "AutoSSH: Restarted\n"
    fi
}

generateNewAutoSSHConfig()
{
    echo "config autossh
	option ssh	'-N -T
				-o StrictHostKeyChecking=no
				-o ServerAliveInterval=60
				-o ServerAliveCountMax=10
				-R $LOCAL_NAT_IP:2222:localhost:22 
				-R $LOCAL_NAT_IP:9100:localhost:9100
				-R $LOCAL_NAT_IP:7681:localhost:7681
                -p 12922
				noaccess@wifi.sudosys.com'
	option gatetime	'0'
	option monitorport	'0'
	option poll	'600'
	option enabled	'1'" > /tmp/autossh
}

compareAutoSSHConfig()
{
    generateNewAutoSSHConfig
    currentAutoSSHConfig=`sha256sum /etc/config/autossh  | awk '{print $1}'`
    newAutoSSHConfig=`sha256sum /tmp/autossh  | awk '{print $1}'`
    if [ $currentAutoSSHConfig == $newAutoSSHConfig ]
    then
        printf "AutoSSH Config matched \n"
    else
        printf "Update new AutoSSH Config \n"
        mv /tmp/autossh /etc/config/autossh
    fi
}

# Setup AutoSSH
nodeExporter_STATUS=`opkg list-installed | grep autossh | wc -l`
if [ $nodeExporter_STATUS -eq 1 ]
then
    printf "AutoSSH: OK\n"
else 
    /etc/init.d/prometheus-node-exporter-lua restart
    /etc/init.d/autossh restart
    /etc/init.d/network restart
    printf "AutoSSH: Restarted\n"
fi


if [ -f "/etc/config/autossh" ]; 
then
    compareAutoSSHConfig
    
else 
    printf "Being generate new AutoSSH config file and put to /tmp/autossh"
    generateNewAutoSSHConfig
    mv /tmp/autossh /etc/config/
fi

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/autossh enable

# Kiem tra AutoSSH da chay chua?
isAutoSSHRunning

echo "===============================  NODE EXPORTER   ============================================="
###############################################################################################################################
###                                             NODE EXPORTER
###############################################################################################################################

isNodeExporterRunning()
{
    nodeExporter_STATUS=`netstat -nltp | grep 9100 | wc -l`
    if [ $nodeExporter_STATUS -eq 1 ]
    then
        printf "Node Exporter: OK\n"
    else 
        /etc/init.d/prometheus-node-exporter-lua restart
        printf "Node Exporter: Restarted\n"
    fi
}

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/prometheus-node-exporter-lua enable

# Kiem tra Node Exporter da chay chua?
isNodeExporterRunning

echo "===============================  PROMETHEUS SERVER   ==========================================="
###############################################################################################################################
###                                             PROMETHEUS SERVER
###############################################################################################################################

isPrometheuServerRunning()
{
    prometheusServer_STATUS=`wget --no-check-certificate -O - -q "https://wifi.sudosys.com/public_check_prometheus_online/$LOCAL_NAT_IP"`
    if [ $prometheusServer_STATUS -eq 0 ]
    then
        /etc/init.d/prometheus-node-exporter-lua restart
        /etc/init.d/network restart
        printf "Connection is restarted\n"
    else
        printf "Prometheus Server: OK\n"
    fi
}

# Kiem tra phan mem giam sat da chay chua?
isPrometheuServerRunning

echo "===============================  TTYD   ==================================================="
###############################################################################################################################
###                                             TTYD
###############################################################################################################################



isTTYDRunning()
{
    TTYD_STATUS=`netstat -nltp  | grep 127.0.0.1:7681 | wc -l`
    if [ $TTYD_STATUS -gt 0 ]
    then
        printf "TTYD: OK\n"
    else 
        /etc/init.d/ttyd restart
        printf "TTYD: Restarted\n"
    fi
}

generateNewTTYDConfig()
{
    echo "config ttyd
	option interface '@loopback'
	option command '/bin/sh -l'
" > /tmp/ttyd
}

compareTTYDConfig()
{
    generateNewTTYDConfig
    currentTTYDConfig=`sha256sum /etc/config/ttyd  | awk '{print $1}'`
    newTTYDConfig=`sha256sum /tmp/ttyd  | awk '{print $1}'`
    if [ $currentTTYDConfig == $newTTYDConfig ]
    then
        printf "TTYD Config matched\n"
    else
        printf "Update new TTYD Config\n"
        mv /tmp/ttyd /etc/config/ttyd
    fi
}

# Setup TTYD
if [ -f "/etc/config/ttyd" ]; 
then
    compareTTYDConfig
else 
    printf "Being generate new TTYD config file and put to /tmp/ttyd"
    generateNewTTYDConfig
    mv /tmp/ttyd /etc/config/
fi

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/ttyd enable

# Kiem tra TTYD da chay chua?
isTTYDRunning

echo "===============================  CRONTAB   ============================================="
###############################################################################################################################
###                                             CRONTAB
###############################################################################################################################

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/cron enable

isCrontabRunning()
{
    cron_STATUS=`ps  | grep crond | wc -l `
    if [ $cron_STATUS -gt 0 ]
    then
        printf "Crontabs: OK\n"
    else
        /etc/init.d/cron restart
        printf "Crontabs: Restarted\n"
    fi
}

# Kiem tra Crontab da chay chua?
isCrontabRunning

echo "===============================  OpenNDS   ============================================="
###############################################################################################################################
###                                             OpenNDS
###############################################################################################################################

# Dam bao rang khi reboot, dich vu duoc khoi dong theo


isOpenNDSRunning()
{
    cron_STATUS=`ndsctl status | grep "openNDS Status" | wc -l`
    if [ $cron_STATUS -gt 0 ]
    then
        printf "openNDS: OK\n"
    else
        /usr/sbin/ipset create openndsset hash:ip
        /etc/init.d/odhcpd restart 
        /etc/init.d/firewall restart
        /etc/init.d/network restart
        /etc/init.d/opennds restart
        printf "openNDS: Restarted\n"
    fi
}

# Kiem tra Crontab da chay chua?
isOpenNDSRunning

printf "---------==============[ INSTALLATION COMPLETED! ] =================---------\n"

isAutoSSHRunning #?
isNodeExporterRunning #? 
isPrometheuServerRunning #?
isTTYDRunning #? 
isCrontabRunning #?
isOpenNDSRunning #?

printf "\nNote: Please reboot AP to make sure everything working exacely!!\n"
