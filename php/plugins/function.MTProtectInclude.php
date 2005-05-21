<?php
function smarty_function_MTProtectInclude($args, &$ctx) {
    $path = $ctx->mt->config['CGIPath'];
    if (substr($path, strlen($path) - 1, 1) != '/') {
        $path .= '/';
      }
    $blog = $ctx->stash('blog');
    $blog_path = $blog['blog_site_path'];
    if (!preg_match('!/$!', $blog_path)) {
        $blog_path .= '/'; 
      }
    global $tk_token, $logged_in, $login_url, $name, $nick, $logout_url;  
    $tk_token = $blog['blog_remote_auth_token'];
		$include = $blog_path.'typekey_lib.php';
		include_once($include); 
		$logged_in = typekey_logged_in();
		$login_url = typekey_login_url();
		$name = typekey_name();
		$nick = typekey_nick();
		$logout_url = typekey_logout_url();		
}
?>
