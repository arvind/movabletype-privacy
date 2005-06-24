<?php
function smarty_block_MTEntryProtect($args, $content, &$ctx, &$repeat) {
  global $tk_token, $logged_in, $login_url, $name, $nick, $logout_url;	
	$localvars = array('protected','type','pass','middle','cookie','auth_users');
	if (!isset($content)) {
		$ctx->localize($localvars);
    $blog = $ctx->stash('blog');
    $blog_id = $blog['blog_id'];
    $url = $blog['blog_site_url'];
    if (!preg_match('!/$!', $url))
    $url .= '/';
    $e = $ctx->stash('entry');
    $entry_id = $e['entry_id'];
    $sql = "select * from mt_protect where protect_entry_id = $entry_id";
    $protected = $ctx->mt->db->get_row($sql, ARRAY_A);		
		$ctx->stash('protected',$protected);
		if(isset($protected)) {
				$text = $args['password_text']; 
				if(empty($text))
					$text = "This post is password protected. To view it please enter your password below";
			$type = $protected['protect_type'];
			$ctx->stash('type',$type);
			if($type == 'Password') {
				$pass = $protected['protect_password'];
				$ctx->stash('pass',$pass);
				$cookie = 'mt-postpass_'.md5($pass);
				$ctx->stash('cookie',$cookie);
				$middle = '<div id="protect">';
        $middle .= '<form action="'.$blog_url.'mt-password.php" method="post">';
        $middle .= '<input name="entry_id" value="'.$entry_id.'" type="hidden" />';
        $middle .= '<input name="blog_id" value="'.$blog_id.'" type="hidden" />';
        $middle .= '<p>'.$text.'</p>';
        $middle .= '<p><label>Password:</label> <input name="post_password" type="text" size="20" /> <input type="submit" name="Submit" value="Submit" /></p>';
        $middle .= '</form>';	
        $middle .= '</div>';			
        $ctx->stash('middle',$middle);		
			}	
			elseif($type == 'Typekey'){
        // Thanks Tweezerman for help with this code
        $sql = "select protect_data from mt_protect where protect_entry_id = $entry_id";
        $tk_users = $ctx->mt->db->get_var($sql);
        $users = explode("\n- ", $tk_users);
        $users = preg_replace("/\n$/", "", $users);
        array_shift($users);
        $auth_users = array();
        foreach ($users as $user) {
            if (preg_match('/group:(.*)/', $user, $matches)) {
                $group = $matches[1];
                $sql = "select protect_groups_data from mt_protect_groups where protect_groups_label = \"$group\"";
                $protect_data = $ctx->mt->db->get_var($sql);
                $user_groups = explode("\n- ", $protect_data);
                array_shift($user_groups);
                $user_groups = preg_replace("/\n$/", "", $user_groups);
                $auth_users = array_merge($auth_users, $user_groups);
                } else {
                array_push($auth_users, $user);
            }
        }				
				$ctx->stash('auth_users',$auth_users);
			}
		}
	} else {
		$protected = $ctx->stash('protected');
		if(isset($protected)) {
			$type = $ctx->stash('type');
			if($type == 'Password') {
				$pass = $ctx->stash('pass');
					$cookie = $ctx->stash('cookie');
        if($pass == "" || isset($_REQUEST[$cookie]) ) {
//          return $content;
        }	else {
        	$content = $ctx->stash('middle');
        }			
			}
			elseif($type == "Typekey") {	
				$signintext = $args['tk_signin_text'];
				if(empty($signintext))
					$signintext = "This blog has been Typekey protected so only selected Typekey users can read it. ";
				$notallowed = $args['tk_barred_text'];
				if(empty($notallowed)) 
					$notallowed = "You do not have the rights to access this blog. Sorry!";		
				$auth_users = $ctx->stash('auth_users');
				if (in_array($name, $auth_users)) {
					$message = "<p class=\"protected\">Thanks for signing in $nick <font size=\"1\">(<a href=\"$logout_url\">Logout</a>)</font></p>";
					$content = $message.$content;
				} 
				else {
          if ($logged_in) {
              $content = "<p class=\"protected\">Hello $nick. ".$notallowed." (<a href=\"$logout_url\">Sign Out</a>)</p>";
            } else {
              $content = "<p class=\"protected\">".$signintext." <a href=\"$login_url\">Sign in</a></p>";
          }					
				}
			}
		}
	$ctx->restore($localvars);
	}
return $content;
}
?>