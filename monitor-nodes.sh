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
NODES="192.168.1.60 192.168.1.61 192.168.1.62"

# The person who gets email when things go wrong.
ADMIN_MAIL="root"

# The check script that is called to see if a node is functional or not.
CHECK_SCRIPT="checkserver.php"


DOWN_NODES_FILE="${TINYDNS}/nodes-down.txt"
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
      mail -s "FATAL: all nodes are down" $ADMIN_MAIL 
  exit 1
fi

#
# De-activate nodes that are down in DNS
#
if [ $NUM_DOWN -gt 0 ]
then
  mv $DATA $DATA.bak

  for n in `echo $DOWN_NODES`
  do
    echo "taking $n out of service." | mail -s "$n down" $ADMIN_MAIL
    sed -e "s/^\+\([0-9a-zA-Z\-\.]*\):${n}:\([0-9]*\)$/\-\1:${n}:\2/" $DATA.bak > $DATA
    
    PREV_DOWN=`echo $PREV_DOWN | sed -e "s/${n}//"`
  done
fi


PREV_NUM_DOWN=`echo $PREV_DOWN | wc -w`

#
# Re-activate nodes that were down in DNS but are back up.
#
if [ $PREV_NUM_DOWN -gt 0 ]
then
  mv $DATA $DATA.bak1
  for n in `echo $PREV_DOWN`
  do
    echo "putting $n back in service." | mail -s "$n up" $ADMIN_MAIL
    sed -e "s/^\-\([0-9a-zA-Z\-\.]*\):${n}:\([0-9]*\)$/\+\1:${n}:\2/" $DATA.bak1 > $DATA
  done
fi

echo $DOWN_NODES > $DOWN_NODES_FILE

# update DNS
make

