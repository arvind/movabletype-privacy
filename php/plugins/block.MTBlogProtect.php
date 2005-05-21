<?php
function smarty_block_MTBlogProtect($content, $args, &$ctx, &$repeat) {
	$repeat = false;
	global $tk_token, $logged_in, $login_url, $name, $nick, $logout_url;
	$blog = $ctx->stash('blog');
  $blog_id = $blog['blog_id'];
  $url = $blog['blog_site_url'];
   if (!preg_match('!/$!', $url))
        $url .= '/';
	 $e = $ctx->stash('entry');
	 $entry_id = 0;
	 $sql = "select * from mt_protect where protect_entry_id = $entry_id and protect_blog_id = $blog_id";
		$protected = $ctx->mt->db->get_row($sql, ARRAY_A);
	if(isset($protected)) {
		 $type = $protected['protect_type'];
		if($type == 'Password') {
				$pass = $protected['protect_password'];
				$cookie = 'mt-postpass_'.md5($pass);
				if($pass == "" || isset($_REQUEST[$cookie]) ) { 
					echo "Hello World";
				} else { 
				$middle .= '<form action="'.$blog_url.'mt-password.php" method="post">';
				$middle .= '<input name="entry_id" value="'.$entry_id.'" type="hidden" />';
				$middle .= '<input name="blog_id" value="'.$blog_id.'" type="hidden" />';
     		$middle .= '<p>This post is password protected. To view it please enter your password below:</p>';
     		$middle .= '<p><label>Password:</label> <input name="post_password" type="text" size="20" /> <input type="submit" name="Submit" value="Submit" /></p>';
        $middle .= '</form>';
        echo $middle;
				}

		} elseif($type == 'Typekey') {
// Thanks Tweezerman for help with this code			
			 $sql = "select protect_data from mt_protect where protect_entry_id = $entry_id and protect_blog_id = $blog_id";
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
			 print_r($auth_users);
			 print_r($name);
			 $nname = "Arvind";
			 if (in_array($nname, $auth_users)) {
			  	echo "<p>Thanks for signing in $nick <font size=\"1\">(<a href=\"$logout_url\">Logout</a>)</font></p>"; 
			 } else { 
			   if ($logged_in) { 
			      echo "Hello $nick. You do not have the rights to access this entry. Sorry! (<a href=\"$logout_url\">Sign Out</a>)";
			   } else { 
			 		   echo "This entry has been Typekey protected so only selected Typekey users can read it. <a href=\"$login_url\">Sign in</a>";
			   } 
			 } 			
			
		}
	}	
}
?>
