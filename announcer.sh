#!/bin/sh

#configuration
cd "$(dirname "$0")"
CONFIGFILE="firewall_mqtt.yml"

#launch the listener
echo "launching listner2.sh"
sh "./listner2.sh" &

firstRun=true

while true
do
    . ./parse_yaml.sh
    eval $(parse_yaml $CONFIGFILE  "config_")
    mqttString=$config_general_mqttPrefix/$config_general_mqttType/$config_general_mqttNode
    for val in $config_general_names; do
        #printf "Generating configuration for $val \n"
        #determine the state
        prefix='$config_'
        suffix='_rule'
        myexp=$prefix$val$suffix
        uniqueid="openwrtfw_$val"
        #echo "myexp: $myexp"
        rule=$(eval "echo $myexp")
        #echo "rule: $rule"
        mqttStringF=$mqttString/$val
        payload="
{
    \"name\": \"$val\",
    \"icon\": \"$config_general_mqttIconOn\",
    \"state_topic\": \"$mqttStringF/$config_general_mqttState\",
    \"command_topic\": \"$mqttStringF/$config_general_mqttCommand\",
    \"unique_id\": \"$uniqueid\",
    \"payload_off\": \"OFF\",
    \"payload_on\": \"ON\"
}
"
        #echo "payload: $payload"
        ruleStatus="uci show firewall.$rule | grep enabled | cut -d '=' -f 2 | xargs"
        #echo "rulestatus: $ruleStatus"
        deviceStatus=$(eval $ruleStatus)
        #echo "status: $deviceStatus"
        if [ -n $deviceStatus -a $deviceStatus -eq 0 ];then
            echo "rule is currently disabled"
            setval="OFF"
        else
            echo "rule is currently enabled"
            setval="ON"
        fi

        configstring=$mqttStringF/$config_general_mqttConfig
        setstring=$mqttStringF/$config_general_mqttState
        mpub="mosquitto_pub -h $config_general_host -p $config_general_port -u $config_general_user -P $config_general_pwd"
        pubcmd="$mpub -t \"$configstring\" -m '$payload'"
        statecmd="$mpub -t \"$setstring\" -m $setval"
        if $firstRun; then
            printf "configuration command: \n $pubcmd \n\n"
            eval $pubcmd
        fi
        #printf "status command: \n $statecmd \n\n"
        eval $statecmd
    done
    firstRun=false
    echo "sleeping $config_general_announcerWait seconds"
    sleep $config_general_announcerWait
done

echo "announcer done"


echo "i'm out"