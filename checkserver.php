<?php
/**
 * Monitor health of a cluster node.
 *
 * Create a database and user allow localhost access by that user.
 *
 *  By: Danny Sheehan   http://www.setuptips.com
 */

define('DB_NAME',     'db_name');
define('DB_USER',     'db_user');
define('DB_PASSWORD', 'db_password');
define('DB_HOST',     'localhost');

if ( ! ($conn = mysql_connect(DB_HOST, DB_USER, DB_PASSWORD)) )
{
  header("HTTP/1.0 404 Not Found");
  die('Mysql error: ' . mysql_error());
}

if ( ! mysql_select_db(DB_NAME) )
{
  header("HTTP/1.0 404 Not Found");
  die('Mysql error: ' . mysql_error());
}

mysql_close($conn);

//
// Ensure the monitor script dosn't cache the result.
// See http://stackoverflow.com/questions/49547/making-sure-a-web-page-is-not-cached-across-all-browsers
//
header('Cache-Control: no-cache, no-store, must-revalidate'); // HTTP 1.1.
header('Pragma: no-cache'); // HTTP 1.0.
header('Expires: 0'); // Proxies.

echo "Connected to Database " . gethostname() . "\n";
?>

