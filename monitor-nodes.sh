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
# BY: Danny Sheehan   http://www.ftmon.org
# -------------------------------------------------------------------
TINYDNS="/etc/service/tinydns/root"

# Update this with the IP address of the nodes in your cluster.
FT_NODES_ADDR="10.0.0.22 10.0.0.23 10.0.0.24"
#
# Set to the hostname of you master node as returned by 'uname -n'
FT_MASTER_HOST="ns1"
#
# These are a-records that you never want to disable.
# For example if you setup your own DNS servers and these are the a-records of
# those servers.
FT_DNS_EXCEPTIONS="ns1.yourdomain.com ns2.yourdomain.com ns3.yourdomain.com"
#
# The user designated as the administrator.
# Be sure to setup a /etc/aliases entry.
FT_ADMIN="trump24"
#
# Where serious alerts get sent.
# Be sure to setup a /etc/aliases entry.
FT_PAGER="pager"
#
# The check script that is called to see if a node is functional or not.
# must be on your webserver. Can be in hidden path.
# I suggest you use
# https://github.com/dannysheehan/djbdns-tinydns/blob/master/checkserver.php
FT_CHECK_PAGE="checkserver.php"


# You can keep the above configuration variables organized in a config file.
CONFIG="/etc/default/ftmoncluster"
test -r $CONFIG && . $CONFIG


THIS_HOST=`uname -n`


DOWN_NODES_FILE="${TINYDNS}/nodes-down.txt"
touch ${DOWN_NODES_FILE}

DATA="${TINYDNS}/data"

# not much point trying to recover if we lost our network conectivity.
if ! nc -z google.com 80 
then
  exit 1
fi

cd $TINYDNS

MAX_NODES=`echo $FT_NODES_ADDR | wc -w`

PREV_DOWN=`cat $DOWN_NODES_FILE`

#
# First, we find out how many of our cluster nodes are down.
#
DOWN_NODES=""
for n in `echo $FT_NODES_ADDR`
do
   if ! wget -T 4 -t 2 -q  --spider http://$n/${FT_CHECK_PAGE} > /dev/null
   then
     DOWN_NODES="$DOWN_NODES $n"
   fi

done

#
# If all nodes are down, then leave the DNS records alone.
#
NUM_DOWN=`echo $DOWN_NODES | wc -w`
if [ $NUM_DOWN -eq $MAX_NODES ]
then
  echo "ERROR: All nodes are down."
  echo "ERROR: All nodes are down."  | \
      mail -s "$THIS_HOST: FATAL: all nodes are down" $FT_PAGER 


  if [ ! -e "/etc/init.d/mysql" ]
  then
    exit 1
  fi

  # try a limited bootstrap in the event that mysql totally shuts down
  # but just on the node we designate as the "master node".
  if [ "$THIS_HOST" = "$FT_MASTER_HOST" ]
  then 
    if ! ps -fu mysql > /dev/null
    then
      echo "initiating mysql bootstrap"
      /etc/init.d/mysql bootstrap-pxc
    fi
  fi

  exit 1
fi

#
# De-activate round robin DNS records of nodes that are down.
#
if [ $NUM_DOWN -gt 0 ]
then

  for n in `echo $DOWN_NODES`
  do

    HOST_NAME=`getent hosts $n | awk '{print $2}'`

    # deactive only if down 2 times in a row.
    if echo $PREV_DOWN | grep -q $n
    then
      echo "taking $HOST_NAME out of service."
      echo "taking $HOST_NAME out of service." | \
       mail -s "$THIS_HOST : $HOST_NAME down more than 1 count" $FT_ADMIN

      mv $DATA $DATA.bak
      cat $DATA.bak | while read DRECORD
      do

        # Deactivate A records for the down server/'s.
        # Except for A records that are designated as exceptions. e.g. dns server a-records
        if echo $DRECORD | egrep -q "^\+" 
        then
          HNAME=`echo $DRECORD | cut -d: -f1 | sed -e "s/\+//"` 
          if [[ $FT_DNS_EXCEPTIONS =~ $HNAME ]]
          then
            echo $DRECORD
          else
           echo $DRECORD | sed -e "s/^\+${HNAME}:${n}\(.*\)$/\-${HNAME}:${n}\1/"
          fi
        else
          echo $DRECORD
        fi
      done  > $DATA

      # update DNS records.
      make data.cdb

    else
      echo "$HOST_NAME is down."
      echo "$HOST_NAME is down." | \
           mail -s "$THIS_HOST : $HOST_NAME down for 1 count" $FT_ADMIN
    fi
    PREV_DOWN=`echo $PREV_DOWN | sed -e "s/${n}//"`
  done
fi

# These should be the nodes that are now up.
PREV_NUM_DOWN=`echo $PREV_DOWN | wc -w`

#
# Re-activate round robin DNS records of nodes that were down but are now back up.
#
if [ $PREV_NUM_DOWN -gt 0 ]
then
  for n in `echo $PREV_DOWN`
  do
    HOST_NAME=`getent hosts $n | awk '{print $2}'`
    echo "putting $HOST_NAME back in service."
    echo "putting $HOST_NAME back in service." | \
       mail -s "$THIS_HOST : $HOST_NAME up" $FT_PAGER
    mv $DATA $DATA.bak1
    sed -e "s/^\-\([0-9a-zA-Z\-\.]*\):${n}\(.*\)$/\+\1:${n}\2/" $DATA.bak1 > $DATA
    # update DNS
    make data.cdb
  done
fi

echo $DOWN_NODES > $DOWN_NODES_FILE

#
# If msql server is down, try restarting it.
# oom-killer most likely killed it.
#
if [ -e "/etc/init.d/mysql" ]
then
  #
  # start mysql if it is down.
  #
  if ! pgrep -u mysql > /dev/null
  then
    sleep 50
    echo "mysql is down - restarting." | \
       mail -s "$THIS_HOST : Starting mysql" $FT_ADMIN
   service mysql start
  fi
fi

