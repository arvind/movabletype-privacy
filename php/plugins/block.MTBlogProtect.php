<?php
function smarty_block_MTBlogProtect($args, $content, &$ctx, &$repeat) {
  global $tk_token, $logged_in, $login_url, $name, $nick, $logout_url;	
    $staticwebpath = $ctx->mt->config['StaticWebPath'];
    if (!$staticwebpath) {
        $staticwebpath = $ctx->mt->config['CGIPath'];
        if (substr($staticwebpath, strlen($staticwebpath) - 1, 1) != '/')
            $staticwebpath .= '/';
        $staticwebpath .= 'mt-static/';
    }
    if (substr($staticwebpath, strlen($staticwebpath) - 1, 1) != '/')
        $staticwebpath .= '/';    
	$localvars = array('protected','type','pass','middle','cookie','auth_users');
	if (!isset($content)) {
		$ctx->localize($localvars);
    $blog = $ctx->stash('blog');
    $blog_id = $blog['blog_id'];
    $url = $blog['blog_site_url'];
    if (!preg_match('!/$!', $url))
    $url .= '/';
 
    $e = $ctx->stash('entry');
    $entry_id = 0;
    $sql = "select * from mt_protect where protect_entry_id = $entry_id and protect_blog_id = $blog_id";
    $protected = $ctx->mt->db->get_row($sql, ARRAY_A);	
    	
		$ctx->stash('protected',$protected);
		if(isset($protected)) {
			$type = $protected['protect_type'];
			$ctx->stash('type',$type);
			if($type == 'Password') {
				$text = $args['password_text']; 
				if(empty($text))
					$text = "This post is password protected. To view it please enter your password below";
				$pass = $ctx->mt->db->unserialize($protected['protect_data']);
				$ctx->stash('pass',$pass);
				$cookie = 'mt-postpass_'.md5($pass);
				$ctx->stash('cookie',$cookie);
				$middle = '<div id="protect">';
        $middle .= '<form action="'.$url.'mt-password.php" method="post">';
        $middle .= '<input name="entry_id" value="'.$entry_id.'" type="hidden" />';
        $middle .= '<input name="blog_id" value="'.$blog_id.'" type="hidden" />';
        $middle .= '<p>'.$text.'</p>';
        $middle .= '<p><label>Password:</label> <input name="post_password" type="text" size="20" /> <input type="submit" name="Submit" value="Submit" /></p>';
        $middle .= '</form>';	
        $middle .= '</div>';	
        $ctx->stash('middle',$middle);		
			}	
			elseif($type == 'Typekey'){
				$users = $ctx->mt->db->unserialize($protected['protect_data']);
        $auth_users = array();
        foreach ($users as $user) {
            if (preg_match('/group:(.*)/', $user, $matches)) {
                $group = $matches[1];
                $sql = "select protect_groups_data from mt_protect_groups where protect_groups_label = \"$group\"";
                $protect_data = $ctx->mt->db->get_var($sql);
								$user_groups = $ctx->mt->db->unserialize($protect_data);
                $auth_users = array_merge($auth_users, $user_groups);
                } else {
                array_push($auth_users, $user);
            }
        }				
				$ctx->stash('tk_auth_users',$auth_users);
			}
			elseif($type == 'OpenID'){
				$users = $ctx->mt->db->unserialize($protected['protect_data']);
        $auth_users = array();
        foreach ($users as $user) {
            if (preg_match('/group:(.*)/', $user, $matches)) {
                $group = $matches[1];
                $sql = "select protect_groups_data from mt_protect_groups where protect_groups_label = \"$group\"";
                $protect_data = $ctx->mt->db->get_var($sql);
								$user_groups = $ctx->mt->db->unserialize($protect_data);
                $auth_users = array_merge($auth_users, $user_groups);
                } else {
								 	$pos = strpos($user, 'http://');
								 	if($pos === false) {
								 		$user = 'http://'.$user;
								 	}
								  if (substr($user, strlen($user) - 1, 1) != '/')
								        $user .= '/'; 								 	                	
                array_push($auth_users, $user);
            }
        }				
				$ctx->stash('oi_auth_users',$auth_users);
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
				$auth_users = $ctx->stash('tk_auth_users');
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
			elseif($type == "OpenID") {
				$signintext = $args['oi_signin_text'];
				if(empty($signintext))
					$signintext = "This blog has been protected using OpenID so only selected OpenID users can read it. ";
				$notallowed = $args['oi_barred_text'];
				if(empty($notallowed)) 
					$notallowed = "You do not have the rights to access this blog. Sorry!";			
				$openidname = $_SESSION["sess_openid_auth_code"];
				$oi_logout_url = sprintf("http://%s%s", $_SERVER['HTTP_HOST'], $_SERVER['REQUEST_URI']).'?openid_logout';										
				$auth_users = $ctx->stash('oi_auth_users');
				if (in_array($openidname, $auth_users)) {
					$message = "<p class=\"protected\">You are logged in as: ".$openidname." <font size=\"1\">(<a href=\"$oi_logout_url\">Logout</a>)</font></p>";
					$content = $message.$content;
				} 
				else {
          if ($_SESSION["sess_openid_auth_code"]) {
              $content = "<p class=\"protected\">You are logged in as: ".$openidname.". ".$notallowed." (<a href=\"$oi_logout_url\">Sign Out</a>)</p>";
            } else {
            	$content = '<form method="post" id="openidform" action="'.$_SERVER["REQUEST_URI"].'">';
				   		$content .= '<input type="hidden" name="openid_type" value="openid" />';
				   		$content .= '<label for="openid_name">'.$signintext.'</label><br />';
				   		$content .= '<input style="padding-left: 22px;background:#fff url('.$staticwebpath.'images/openid.gif) 2px 1px no-repeat;" type="text" value="" name="openid_name" id="openid_name" />';
				   		$content .= '<input type="submit" id="openidsubmit" value="Log In" />';
				   		$content .= '</form>';
          }					
				}
			}			
		}
	$ctx->restore($localvars);
	}
return $content;
}
?>