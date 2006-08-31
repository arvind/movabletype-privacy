<?php
	include('<$MTCGIServerPath$>/php/mt.php');
	$mt = new MT(<$MTBlogID$>, '<$MTConfigFile$>');
	$db =& $mt->db;
	$config = $db->fetch_plugin_config('MT Protect');
	if($_REQUEST['rand'] == $config['rand'])  {
		setcookie($_REQUEST['obj_type'].$_REQUEST['id'], 1, time()+60*60*24, '/');
	}
	
	$config['rand'] = md5(time().mt_rand());	
	
	require_once("MTSerialize.php");
    $serializer = new MTSerialize();
	$data = $db->escape($serializer->serialize($config));	
	
	$db->query("update mt_plugindata set plugindata_data = '$data' where plugindata_plugin = 'MT Protect' and plugindata_key = 'configuration'");
	header('Location: '. $_REQUEST['redirect']);
?>