<?php
/**
 * Monitor health of a cluster node.
 *
 * Create a database and user allow localhost access by that user.
 *
 *  By: Danny Sheehan   http://www.ftmon.org
 */

define('DB_TABLE',     'servers');

define('DB_NAME',     'checkserver');
define('DB_USER',     'checkserver');
define('DB_PASSWORD', 'change_me);
//define('DB_HOST',     'localhost');
define('DB_HOST',     '127.0.0.1');


// Can we connect?
if ( ! ($conn = mysql_connect(DB_HOST, DB_USER, DB_PASSWORD)) )
{
  header("HTTP/1.0 404 Not Found");
  die('Mysql error: ' . mysql_error());
}

// Can we select?
if ( ! mysql_select_db(DB_NAME) )
{
  header("HTTP/1.0 404 Not Found");
  die('Mysql error: ' . mysql_error());
}

$this_host = gethostname();
$now = time();

// Can we query?
$sql="SELECT counter FROM " . DB_TABLE . " WHERE name = '$this_host'";
if ( ! ($result = mysql_query($sql)) )
{
  header("HTTP/1.0 404 Not Found");
  die('Mysql error: ' . mysql_error());
}

// First time? Then do insert rather than update.
$num = mysql_numrows($result);
if ( ! $num )
{
  $sql = "INSERT INTO " . DB_TABLE . " ".
         "(name, counter) ".
         "VALUES ".
         "('$this_host', '$now')";
  if ( ! ($result = mysql_query($sql)) )
  {
    header("HTTP/1.0 404 Not Found");
    die('Mysql error: ' . mysql_error());
  }
}
else
{ 
  $last_time = mysql_result($result, 0,"counter");
}


// Can we do an update?
$sql = "UPDATE " . DB_TABLE . " ".
       "SET counter = $now " .
       "WHERE name = '$this_host' ";
if ( ! ($result = mysql_query($sql)) )
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

$counter = $now - $last_time;

echo gethostname() . "," . $counter . "\n";

?>
