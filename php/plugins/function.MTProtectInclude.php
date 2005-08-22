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
    global $tk_token, $logged_in, $login_url, $name, $nick, $logout_url, $redirect_url, $this_page, $openidname, $oi_logout_url;  
    $requested_path = $ctx->mt->request;
    $data =& $ctx->mt->resolve_url($requested_path);
    $info =& $data['fileinfo'];
		$this_page = sprintf("http://%s%s", $_SERVER['HTTP_HOST'], $info['fileinfo_url']);
    $redirect_url = sprintf("http://%s%s", $_SERVER['HTTP_HOST'], $_SERVER['REQUEST_URI']);
    $tk_token = $blog['blog_remote_auth_token'];
		include_once($blog_path.'typekey_lib.php'); 
		$logged_in = typekey_logged_in();
		$login_url = typekey_login_url($redirect_url);
		$name = typekey_name();
		$nick = typekey_nick();
		$openidname = $_SESSION["sess_openid_auth_code"];
		$oi_logout_url = sprintf("http://%s%s", $_SERVER['HTTP_HOST'], $_SERVER['REQUEST_URI']).'?openid_logout';
		$logout_url = typekey_logout_url();		
		require($blog_path.'openid.php');
}
?>
