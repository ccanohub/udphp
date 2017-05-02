#!/bin/sh

# Orchestrator Url
SIGNUP_URL=http://...../signup.php
# Authentication against orchestrator
USER=OpenVPNClient1
PW=123456 (please set a good password)

# Interval between signup requests
INTERVAL=65
# For OpenWrt. Configuration of the OpenVPN client 
OPENVPN_CONFIG_NAME=OPENVPN_UDP_CLIENT

# In case server address is not specified by Orchestrator we save current
DEFAULT_SERVER_ADDRESS=$(uci get openvpn.$OPENVPN_CONFIG_NAME.remote)
# Allow override address by server?
SIGNUP_CAN_OVERRIDE_SERVER_ADDRESS=0


while :
do
	# Call the service at $SIGNUP_URL and get the OpenVPN config values
	# would be nice if OpenWrt's version of curl supported digest auth, but it doesn't :_(
	signup_result=$(curl --user $USER:$PW $SIGNUP_URL 2>/dev/null)
	
	server_address=$DEFAULT_SERVER_ADDRESS
	server_port=""
	# Result can be:
	# Just the port	
	port=$(echo $signup_result | sed -nr 's/^([0-9]{1,5})$/\1/p')
	if [[ ! -z $port ]]
	then
		server_port=$port
	else
		# the expression ipaddress:port
		ip=$(echo $signup_result | sed -nr 's/^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)):([0-9]+)$/\1/p')
		port=$(echo $signup_result | sed -nr 's/^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)):([0-9]+)$/\6/p')
		if [[ ! -z $ip ]]
		then
			server_address=$ip
			server_port=$port
		else
			# the expression domainname.com:port
			domain=$(echo $signup_result | sed -nr 's/^([0-9a-zA-Z][0-9a-zA-Z\.]+[0-9a-zA-Z]{2,6}):([0-9]{1,5})$/\1/p')
			port=$(echo $signup_result | sed -nr 's/^([0-9a-zA-Z][0-9a-zA-Z\.]+[0-9a-zA-Z]{2,6}):([0-9]{1,5})$/\2/p')
			if [[ ! -z $domain ]]
			then
				server_address=$domain
				server_port=$port
			else
				echo "$(date) Unknown address returned from the signup:$signup_result"
			fi
		fi
	fi

	if [[ ! -z $server_port ]]
	then
		openvpn_need_restart=0
		if [[ $SIGNUP_CAN_OVERRIDE_SERVER_ADDRESS == 1 && $server_address != $DEFAULT_SERVER_ADDRESS ]]
		then
			echo "$(date) Address changed from $DEFAULT_SERVER_ADDRESS to $server_address"
			uci set openvpn.$OPENVPN_CONFIG_NAME.remote=$server_address
			openvpn_need_restart=1
		fi
		
		current_port=$(uci get openvpn.$OPENVPN_CONFIG_NAME.port)
		if [[ $current_port != $server_port ]]
		then
			echo "$(date) Port changed from $current_port to $server_port"
			uci set openvpn.$OPENVPN_CONFIG_NAME.port=$server_port
			openvpn_need_restart=1
		fi
		
		if [[ $openvpn_need_restart != 0 ]]
		then
			uci commit openvpn
			/etc/init.d/openvpn restart
		fi
	
	# else 
		## Something went wrong with the signup, just try again later
	fi

	sleep $INTERVAL
done

