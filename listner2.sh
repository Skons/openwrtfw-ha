#!/bin/sh

#configuration
CONFIGFILE="firewall_mqtt.yml"
#echo "parse yaml"
. ./parse_yaml.sh
eval $(parse_yaml $CONFIGFILE  "config_")
mqttString=$config_general_mqttPrefix/$config_general_mqttType/$config_general_mqttNode
#printf "mqttString $mqttString \n"
mqttStringF=$mqttString/+
#printf "mqttStringF $mqttString \n"
monitorcmd="mosquitto_sub -h $config_general_host -p $config_general_port -u $config_general_user -P $config_general_pwd -q 1 -t \"$mqttStringF/$config_general_mqttCommand\" -v "
#printf "monitorcmd $monitorcmd \n"
mpub="mosquitto_pub -h $config_general_host -p $config_general_port -u $config_general_user -P $config_general_pwd"
#printf "mpub $mpub \n"
prefix='$config_'
suffix='_rule'

while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
do
    eval $monitorcmd | while read -r payload
    do
        echo "payload: $payload"
        entity=$(echo $payload | cut -d/ -f 4)
        prerule=$prefix$entity$suffix
        #echo "prerule: $prerule"
        rule=$(eval "echo $prerule")
        #echo "rule: $rule"
        mycm=$(echo $payload | cut -d ' ' -f 2)
        echo "received command for $entity which will affect rule $rule. the command is $mycm"
        setstring=$mqttString/$entity/$config_general_mqttState

        if [ "$mycm" = "ON" ]; then
            statecmd="$mpub -t \"$setstring\" -m ON"
            eval $statecmd
            printf "changed homeassistant state to ON for $entity \n"
            cfgFw="uci del firewall.$rule.enabled"
            eval $cfgFw
            uci commit firewall
            printf "changed firewall setting to enabled=0 for enity, rule $rule \n"
            /etc/init.d/firewall restart &>/dev/null
            printf "reloaded firewall \n"
        elif [ "$mycm" = "OFF" ]; then
            statecmd="$mpub -t \"$setstring\" -m OFF"
            eval $statecmd
            printf "changed homeassitant state to OFF for $entity \n"
            cfgFw="uci set firewall.$rule.enabled='0'"
            eval $cfgFw
            uci commit firewall
            printf "changed fireawll setting to enabled=1 for $entity, rule $rule \n"
            /etc/init.d/firewall restart &>/dev/null
            printf "reloaded firewall \n"
        else
            printf "received unknown command $mycm for $entity"
        fi
    done
    sleep 10  # Wait 10 seconds until reconnection
done # &  # Discomment the & to run in background (but you should rather run THIS script in background)

echo "done"