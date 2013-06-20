Setup a crontab on each node 

*/1 * * * * /usr/local/bin/monitor-nodes.sh


On each cluster node install the following check script
e.g. for tuxlite LAMP install

/home/<user>/domains/<node>/public_html/checkserver.php
