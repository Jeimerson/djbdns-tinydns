#!/bin/bash
# -------------------------------------------------------------------
# This script monitors nodes in a apache cluster implemented with 
# round robin DNS and takes them out of DNS if they are down.  
#
# It assumes dbjdns tinydns  
#
# NOTES:
#    http://www.atrixnet.com/load-balancing-with-round-robin-dns/
#
# BY: Danny Sheehan   http://www.setuptips.com
# -------------------------------------------------------------------
TINYDNS="/etc/service/tinydns/root"

# Update this with the IP address of the nodes in your cluster.
# Or export as environment variables.
if [ -z "$NODES" ]
then
  NODES="192.168.1.2 192.168.1.3 192.168.1.1"
fi

THIS_HOST=`uname -n`

# The person who gets email when things go wrong.
ADMIN_MAIL="pager"

# The check script that is called to see if a node is functional or not.
CHECK_SCRIPT="checkserver.php"


DOWN_NODES_FILE="${TINYDNS}/nodes-down.txt"
touch ${DOWN_NODES_FILE}

DATA="${TINYDNS}/data"

cd $TINYDNS

MAX_NODES=`echo $NODES | wc -w`

PREV_DOWN=`cat $DOWN_NODES_FILE`

DOWN_NODES=""
for n in `echo $NODES`
do
   if ! wget -t 2 -q  --spider http://$n/${CHECK_SCRIPT} > /dev/null
   then
     DOWN_NODES="$DOWN_NODES $n"
   fi
done


NUM_DOWN=`echo $DOWN_NODES | wc -w`
if [ $NUM_DOWN -eq $MAX_NODES ]
then
  echo "ERROR: All nodes are down."  | \
      mail -s "$THIS_HOST: FATAL: all nodes are down" $ADMIN_MAIL 
  exit 1
fi

#
# De-activate nodes that are down in DNS
#
if [ $NUM_DOWN -gt 0 ]
then

  for n in `echo $DOWN_NODES`
  do

    HOST_NAME=`getent hosts $n | awk '{print $2}'`

    # deactive only if down 2 times in a row.
    if echo $PREV_DOWN | grep -q $n
    then
      echo "taking $HOST_NAME out of service." | \
                  mail -s "$THIS_HOST : $HOST_NAME down for more than 1 count" $ADMIN_MAIL
      mv $DATA $DATA.bak
      sed -e "s/^\+\([0-9a-zA-Z\-\.]*\):${n}:\([0-9]*\)$/\-\1:${n}:\2/" $DATA.bak > $DATA
      # update DNS
      make
    else
      echo "$HOST_NAME is down." | \
                  mail -s "$THIS_HOST : $HOST_NAME down for 1 count" $ADMIN_MAIL
    fi
    PREV_DOWN=`echo $PREV_DOWN | sed -e "s/${n}//"`
  done
fi

# These should be nodes that are now up.
PREV_NUM_DOWN=`echo $PREV_DOWN | wc -w`

#
# Re-activate nodes that were down in DNS but are back up.
#
if [ $PREV_NUM_DOWN -gt 0 ]
then
  for n in `echo $PREV_DOWN`
  do
    HOST_NAME=`getent hosts $n | awk '{print $2}'`
    echo "putting $HOST_NAME back in service." | mail -s "$THIS_HOST : $HOST_NAME up" $ADMIN_MAIL
    mv $DATA $DATA.bak1
    sed -e "s/^\-\([0-9a-zA-Z\-\.]*\):${n}:\([0-9]*\)$/\+\1:${n}:\2/" $DATA.bak1 > $DATA
    # update DNS
    make
  done
fi

echo $DOWN_NODES > $DOWN_NODES_FILE

#
# start mysql if it is down.
#
if ! pgrep -u mysql > /dev/null
then
  echo "mysql is down - restarting." | mail -s "$THIS_HOST : Starting mysql" $ADMIN_MAIL
 service mysql start
fi 
