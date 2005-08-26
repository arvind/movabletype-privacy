#!/usr/bin/perl
package MT::Plugin::Protect;
use strict;
use MT;
use MT::Plugin;
#if (eval { use lib './plugins/Protect/lib'; 1 }) {
#  use lib './plugins/Protect/lib';
#}
use Protect::CMS;
use Protect::Protect;
use Protect::Groups;
use MT::Template::Context;
my $mt = MT->instance;
use vars qw($VERSION);
use base qw(MT::Plugin);

MT->add_plugin(MT::Plugin::Protect->new);

sub name { 'MT Protect' }
sub description { 'Adds the ability to protect entires either by password or using Typekey authentication.' }
sub version { $Protect::CMS::VERSION }
sub doc_link { 'http://www.movalog.com/plugins/wiki/MtProtect' }
sub author_name { 'Arvind Satyanarayan' }
sub author_link { 'http://www.movalog.com/' }
 

sub init_app {
    my $plugin = shift;
    $plugin->SUPER::init_app(@_);
    my ($app) = @_;

    if ($app->isa('MT::App::CMS')) {
        $app->add_itemset_action({type => 'commenter',
                                  key => "set_protection_group",
                                  label => "Create a Protection Group",
                                  code => sub { $plugin->tkgroup(@_) },
                               });
        $app->add_itemset_action({type => 'entry',
                                  key => "set_protection",
                                  label => "Protect Entry(ies)",
                                  code => sub { $plugin->protect_entries(@_) },
                               });      
        $app->add_itemset_action({type => 'blog',
                                  key => "set_protection",
                                  label => "Protect Blog(s)",
                                  code => sub { $plugin->protect_blogs(@_) },
                               });                                                           
    }
}                       
                        
# MT->add_plugin_action ('entry', 'mt-protect.cgi?__mode=edit', "Protect this entry");
MT->add_plugin_action ('list_entries', 'mt-protect.cgi?__mode=list_entries', "List Protected Entries");
MT->add_plugin_action ('blog', 'mt-protect.cgi?__mode=edit', 'Protect Blog');
MT->add_plugin_action ('list_commenters', "mt-protect.cgi?__mode=tk_groups", 'List Protection Groups');

MT::Template::Context->add_tag(ProtectInclude           => \&include);
MT::Template::Context->add_tag(ProtectIncludeSlim          => \&include_slim);
MT::Template::Context->add_container_tag(Protected    => \&protected);
MT::Template::Context->add_container_tag(EntryProtect    => \&protected);
MT::Template::Context->add_container_tag(BlogProtect    => \&blog_protected);
MT::Template::Context->add_conditional_tag(IfProtected    => \&ifprotected);

sub config_template {
    my $app = $mt;
    my $q = $app->{query};
    my ($plugin,$param) = @_;
    my $cblog_id = $q->param('cblog_id');
    if($cblog_id){
        my $cblog = MT::Blog->load($cblog_id);
        $param->{cblog} = $cblog->name;
        $param->{installed} = $q->param('installed');
        $param->{uninstalled} = $q->param('uninstalled');
    $param->{protect_url} = $app->path;        
    }
    #    $param->{breadcrumbs} = $app->{breadcrumbs};
    #    $param->{breadcrumbs}[-1]{is_last} = 1;
if (my $auth = $app->{author}) {

        my @perms = MT::Permission->load({ author_id => $auth->id });
        my @data;
        for my $perms (@perms) {
            next unless $perms->role_mask;
            my $blog = MT::Blog->load($perms->blog_id);
            my $pdblog = MT::PluginData->load({ plugin => 'Protect', key    => $perms->blog_id });
            push @data, { blog_id   => $blog->id,
                blog_name => $blog->name,
            blog_installed => $pdblog };
        }
        $param->{blog_loop} = \@data;
       
    }	
    my $tmpl = <<'EOT';
    <TMPL_IF NAME=CBLOG>
<p class="message"><MT_TRANS phrase="Protection was"> <TMPL_IF NAME=INSTALLED><i><MT_TRANS phrase="installed"></i></TMPL_IF><TMPL_IF NAME=UNINSTALLED><i><MT_TRANS phrase="uninstalled"></i></TMPL_IF> <MT_TRANS phrase="from"> <TMPL_VAR NAME=CBLOG></p>
</TMPL_IF>
 <p><MT_TRANS phrase="Listed below are each of the blogs that you have installed on your system.  Following the blog name is the status of protections for that blog.  After the status of the blog is a link that will perform the opposite function for you.  For instance, if protection is disabled, you will see a link that will enable it for you.  Likewise, if protection is enabled, you will instead see the option to disable it."></p>
 <ul style="list-style-type: none;">
 <TMPL_LOOP NAME=BLOG_LOOP>
     <li><p><a href="<TMPL_VAR NAME=MT_URL>?__mode=menu&blog_id=<TMPL_VAR NAME=BLOG_ID>" style="text-decoration: none;"><TMPL_VAR NAME=BLOG_NAME></a><br /><MT_TRANS phrase="Protection is"> <TMPL_IF NAME=BLOG_INSTALLED><MT_TRANS phrase="Enabled:"> <a href="plugins/Protect/mt-protect.cgi?__mode=load_files&_type=uninstall&cblog_id=<TMPL_VAR NAME=BLOG_ID>" style="text-decoration: none;"><MT_TRANS phrase="Disable"></a><TMPL_ELSE><MT_TRANS phrase="Disabled:"> <a href="plugins/Protect/mt-protect.cgi?__mode=load_files&_type=install&cblog_id=<TMPL_VAR NAME=BLOG_ID>" style="text-decoration: none;"><MT_TRANS phrase="Enable"></a></TMPL_IF></p></li>
 </TMPL_LOOP>
 </ul>
EOT
} 

sub tkgroup {
    my $plugin = shift;
    my ($app) = @_;
	
	my $q = $app->{query};
	my $author_ids;
	for my $author_id ($q->param('id')){
		$author_ids .= ",$author_id";
	}
	$app->redirect($app->path . 'plugins/Protect/mt-protect.cgi?__mode=edit&_type=groups&author_id='. $author_ids);
}

sub protect_entries {
    my $plugin = shift;
    my ($app) = @_;
	
	my $q = $app->{query};
	my ($entry_ids, $i);
	for my $entry_id ($q->param('id')){
		$i++;
		$entry_ids .= ",$entry_id";
	}
	if($i == 1) {
	$app->redirect($app->path . 'plugins/Protect/mt-protect.cgi?__mode=edit&_type=entry&id='. $q->param('id').'&blog_id='.$q->param('blog_id'));
	} else {
	$app->redirect($app->path . 'plugins/Protect/mt-protect.cgi?__mode=edit&_type=entry&entry_ids='. $entry_ids.'&blog_id='.$q->param('blog_id'));	
	}
}

sub protect_blogs {
    my $plugin = shift;
    my ($app) = @_;
	
	my $q = $app->{query};
	my ($blog_ids, $i);
	for my $blog_id ($q->param('id')){
		$i++;
		$blog_ids .= ",$blog_id";
	}
	if($i == 1) {
	$app->redirect($app->path . 'plugins/Protect/mt-protect.cgi?__mode=edit&_type=blog&blog_id='. $q->param('id'));
	} else {
	$app->redirect($app->path . 'plugins/Protect/mt-protect.cgi?__mode=edit&_type=blog&blog_ids='. $blog_ids);	
	}
}

sub include {
  my($ctx) = @_;	
    my $host = $ctx->stash('blog')->site_url;
    if ($host =~ m!^https?://([^/:]+)(:\d+)?/!) {
        $host = $_[1]->{exclude_port} ? $1 : $1 . ($2 || '');
    }  
  my $path = MT::instance()->server_path() || "";
  $path =~ s!/*$!!;
  my $blog_path = $_[0]->stash('blog')->site_path;
  $blog_path .= '/' unless $blog_path =~ m!/$!;
	my $html = "<?php ";
	$html .= '$tk_token = \''.$ctx->stash('blog')->remote_auth_token.'\'; ';
	$html .= 'include "'.$blog_path.'typekey_lib.php"; ';
	$html .= '$logged_in = typekey_logged_in();';
	$html .= '$redirect_url = sprintf("http://%s%s", $_SERVER[\'HTTP_HOST\'], $PHP_SELF);';
	$html .= '$login_url = typekey_login_url($redirect_url);';
	$html .= '$name = typekey_name();';
	$html .= '$nick = typekey_nick();';
	$html .= '$logout_url = typekey_logout_url();';
	$html .= 'global $this_page;';
	$html .= '$this_page = sprintf("http://%s%s", "'.$host.'", $PHP_SELF);';
	$html .= 'require_once("'.$blog_path.'openid.php");';
	$html .= 'include(\''.$path.'/php/mt.php\'); ';
	$html .= '$mt = new MT('.$ctx->stash('blog')->id.', \''.MT->instance->{cfg_file}.'\'); ';
	$html .= '$db = $mt->db(); ';
	$html .= '$openidname = $_SESSION["sess_openid_auth_code"];';
	$html .= ' ?>';
	return $html;	
}

sub include_slim {
  my($ctx) = @_;	
    my $host = $ctx->stash('blog')->site_url;
    if ($host =~ m!^https?://([^/:]+)(:\d+)?/!) {
        $host = $_[1]->{exclude_port} ? $1 : $1 . ($2 || '');
    }  
  my $path = MT::instance()->server_path() || "";
  $path =~ s!/*$!!;
  my $blog_path = $_[0]->stash('blog')->site_path;
  $blog_path .= '/' unless $blog_path =~ m!/$!;
	my $html = "<?php ";
	$html .= '$tk_token = \''.$ctx->stash('blog')->remote_auth_token.'\'; ';
	$html .= 'include "'.$blog_path.'typekey_lib.php"; ';
	$html .= '$logged_in = typekey_logged_in();';
	$html .= '$redirect_url = sprintf("http://%s%s", $_SERVER[\'HTTP_HOST\'], $PHP_SELF);';
	$html .= '$login_url = typekey_login_url($redirect_url);';
	$html .= '$name = typekey_name();';
	$html .= '$nick = typekey_nick();';
	$html .= '$logout_url = typekey_logout_url();';
	$html .= 'global $this_page;';
	$html .= '$this_page = sprintf("http://%s%s", "'.$host.'", $PHP_SELF);';
	$html .= 'require_once("'.$blog_path.'openid.php");';
	$html .= '$openidname = $_SESSION["sess_openid_auth_code"];';
	$html .= ' ?>';
	return $html;	
}

sub ifprotected {
	my ($ctx, $args) = @_;
	my $blog_id = $_[0]->stash('blog')->id;
	my $e = $_[0]->stash('entry');
	my $entry_id = "0";
	$entry_id = $e->id
		if $e;
	my $protected = Protect::Protect->load({ entry_id   => $entry_id, blog_id => $blog_id });
	return $protected;	
}


sub protected {
	my ($ctx, $args, $cond) = @_;
  my $blog_id = $_[0]->stash('blog')->id;
  my $blog_url = $_[0]->stash('blog')->site_url;
  $blog_url .= '/' unless $blog_url =~ m!/$!;
  my $builder = $ctx->stash ('builder');
  my $tokens = $ctx->stash ('tokens');
	my $e = $_[0]->stash('entry');
	my $entry_id = $e->id;
    my $staticwebpath = MT::ConfigMgr->instance->StaticWebstaticwebpath;
    if (!$staticwebpath) {
        $staticwebpath = MT::ConfigMgr->instance->CGIstaticwebpath;
        $staticwebpath .= '/' unless $staticwebpath =~ m!/$!;
        $staticwebpath .= 'mt-static/';
    }
    $staticwebpath .= '/' unless $staticwebpath =~ m!/$!;	
	my ($start, $middle, $bottom, $protected);
    defined (my $out = $builder->build ($ctx, $tokens, $cond))
      or return $ctx->error ($ctx->errstr);
		unless($protected = Protect::Protect->load({ entry_id   => $entry_id })){
		return $out;
	}
	if($protected) {
		my $text = $args->{password_text} || "This post is password protected. To view it please enter your password below:";
		my $type = $protected->type;
		if($type eq 'Password') {
				$start = "<?php\n";
				$start .= '$pass = $db->get_var("select protect_password from mt_protect where protect_entry_id = '.$entry_id.'"); ';
				$start .= '$cookie = \'mt-postpass_\'.md5($pass); ';
				$start .= 'if($pass == "" || isset($_REQUEST[$cookie]) ) { ?>';
				$middle .= '<?php } else { ?>';
				$middle .= '<div class="protected">';
				$middle .= '<form action="'.$blog_url.'mt-password.php" method="post">';
				$middle .= '<input name="entry_id" value="'.$entry_id.'" type="hidden" />';
				$middle .= '<input name="blog_id" value="'.$blog_id.'" type="hidden" />';
     		$middle .= '<p>'.$text.'</p>';
     		$middle .= '<p><label for="post_password">Password:</label> <input name="post_password" type="text" size="20" /> <input type="submit" name="Submit" value="Submit" /></p>';
        $middle .= '</form>';
        $middle .= '</div>';
				$bottom .= '<?php } ?>';
				return $start.$out.$middle.$bottom;
		} elsif($type eq 'Typekey'){
			my $signintext = $args->{tk_signin_text} || "This entry has been Typekey protected so only selected Typekey users can read it. ";
			my $notallowed = $args->{tk_barred_text} || "You do not have the rights to access this entry. Sorry!";
	
			$start = "<?php\n";
			$start .= 'switch($name){';
      my $users = $protected->data;
      for my $user (@$users) {	
      	# Thanks for the regex Tweezerman!
      	if($user =~ /group:(.*)/){
      		my $group = $1;
      		my $data = Protect::Groups->load({ label => $group });
      		my $user_groups = $data->data;
      		for my $user_group (@$user_groups) {	
		      	$start .= "case \"$user_group\":\n";
		      }    		
      	} else {
      $start .= "case \"$user\":\n"; }
      }
      $start .= ' ?>';
      $start .= '<p>Thanks for signing in <?php echo typekey_nick() ?> <font size="1">(<a href="<?php echo typekey_logout_url() ?>">Logout</a>)</font></p>';
      $middle = "<?php\n";
      $middle .= 'break;';
      $middle .= 'default:';
      $middle .= 'if(!$logged_in) {';
      $middle .= 'echo "<p class=\"protected\">'.$signintext.' <a href=\"$login_url\">Sign in</a></p>";';	
      $middle .= '} elseif($logged_in){';
      $middle .= 'echo "<p class=\"protected\">Hello $nick.'.$notallowed.' (<a href=\"$logout_url\">Sign Out</a>)</p>";';
      $middle .= '} } ?>';
      return $start.$out.$middle;
		} elsif($type eq 'OpenID'){
			my $signintext = $args->{oi_signin_text} || "This entry has been protected using OpenID so only selected OpenID users can read it. ";
			my $notallowed = $args->{oi_barred_text} || "You do not have the rights to access this entry. Sorry!";
	
			$start = "<?php\n";
			$start .= 'switch($openidname){';
      my $users = $protected->data;
      for my $user (@$users) {	
      	# Thanks for the regex Tweezerman!
      	if($user =~ /group:(.*)/){
      		my $group = $1;
      		my $data = Protect::Groups->load({ label => $group });
      		my $user_groups = $data->data;
      		for my $user_group (@$user_groups) {
      			$user_group = 'http://'.$user_group
      				if(index($user_group,'http://') == -1);
      			$user_group .= '/' unless $user_group =~ m!/$!;		
		      	$start .= "case \"$user_group\":\n";
		      }    		
      	} else {
      			$user = 'http://'.$user
      				if(index($user,'http://') == -1);	
      $user .= '/' unless $user =~ m!/$!;				      		
      $start .= "case \"$user\":\n"; }
      }
      $start .= ' ?>';
      $start .= '<p>Thanks for signing in <?php echo $openidname ?> <font size="1">(<a href="<?php echo $PHP_SELF."?openid_logout"; ?>">Logout</a>)</font></p>';
      $middle = "<?php\n";
      $middle .= 'break;';
      $middle .= 'default: ?>';
			$middle .= '<form method="post" id="openidform" action="<?php echo $_SERVER["PHP_SELF"]; ?>">';
 			$middle .= '<div>';
 			$middle .= '<?php if ($_SESSION["sess_openid_auth_code"] != "") { ?>';
   		$middle .= 'You are logged in as: <?=$_SESSION["sess_openid_auth_code"]?>'.$notallowed.' (<a href="<?php echo $PHP_SELF."?openid_logout"; ?>">Logout</a>)';
  		$middle .= '<?php } else { ?>';
   		$middle .= '<input type="hidden" name="openid_type" value="openid" />';
   		$middle .= '<label for="openid_name">'.$signintext.'</label><br />';
   		$middle .= '<input style="padding-left: 22px;background:#fff url('.$staticwebpath.'images/openid.gif) 2px 1px no-repeat;" type="text" value="" name="openid_name" id="openid_name" />';
   		$middle .= '<input type="submit" id="openidsubmit" value="Log In" />';
 			$middle .= '<?php } ?>';
 			$middle .= '</div>';
			$middle .= '</form>';      
			$middle .= '<?php } ?>';
      return $start.$out.$middle;
		}
	}	 
}

sub blog_protected {
	my ($ctx, $args, $cond) = @_;
  my $blog_id = $_[0]->stash('blog')->id;
  my $blog_url = $_[0]->stash('blog')->site_url;
  $blog_url .= '/' unless $blog_url =~ m!/$!;
    my $staticwebpath = MT::ConfigMgr->instance->StaticWebstaticwebpath;
    if (!$staticwebpath) {
        $staticwebpath = MT::ConfigMgr->instance->CGIstaticwebpath;
        $staticwebpath .= '/' unless $staticwebpath =~ m!/$!;
        $staticwebpath .= 'mt-static/';
    }
    $staticwebpath .= '/' unless $staticwebpath =~ m!/$!;	  
  my $builder = $ctx->stash ('builder');
  my $tokens = $ctx->stash ('tokens');
	my $entry_id = '0';
	my ($start, $middle, $bottom, $protected);
    defined (my $out = $builder->build ($ctx, $tokens, $cond))
      or return $ctx->error ($ctx->errstr);
		unless($protected = Protect::Protect->load({ entry_id   => $entry_id, blog_id => $blog_id })){
		return $out;
	}
	if($protected) {
		my $text = $args->{password_text} || "This blog is password protected. To view it please enter your password below:";
		my $type = $protected->type;
		if($type eq 'Password') {
				$start = "<?php\n";
				$start .= '$pass = $db->get_var("select protect_password from mt_protect where protect_entry_id = '.$entry_id.'"); ';
				$start .= '$cookie = \'mt-postpass_\'.md5($pass); ';
				$start .= 'if($pass == "" || isset($_REQUEST[$cookie]) ) { ?>';
				$middle .= '<?php } else { ?>';
				$middle .= '<div class="protected">';
				$middle .= '<form action="'.$blog_url.'mt-password.php" method="post">';
				$middle .= '<input name="entry_id" value="'.$entry_id.'" type="hidden" />';
				$middle .= '<input name="blog_id" value="'.$blog_id.'" type="hidden" />';
     		$middle .= '<p>'.$text.'</p>';
     		$middle .= '<p><label for="post_password">Password:</label> <input name="post_password" type="text" size="20" /> <input type="submit" name="Submit" value="Submit" /></p>';
        $middle .= '</form>';
        $middle .= '</div>';
				$bottom .= '<?php } ?>';
				return $start.$out.$middle.$bottom;
		} elsif($type eq 'Typekey'){
			my $signintext = $args->{tk_signin_text} || "This blog has been Typekey protected so only selected Typekey users can read it. ";
			my $notallowed = $args->{tk_barred_text} || "You do not have the rights to access this blog. Sorry!";

			$start = "<?php\n";
			$start .= 'switch($name){';
      my $users = $protected->data;
      for my $user (@$users) {	
      	# Thanks for the regex Tweezerman!
      	if($user =~ /group:(.*)/){
      		my $group = $1;
      		my $data = Protect::Groups->load({ label => $group });
      		my $user_groups = $data->data;
      		for my $user_group (@$user_groups) {	
		      	$start .= "case \"$user_group\":\n";
		      }    		
      	} else {
      $start .= "case \"$user\":\n"; }
      }
      $start .= ' ?>';
      $start .= '<p class="protected">Thanks for signing in <?php echo typekey_nick() ?> <font size="1">(<a href="<?php echo typekey_logout_url() ?>">Logout</a>)</font></p>';
      $middle = "<?php\n";
      $middle .= 'break;';
      $middle .= 'default:';
      $middle .= 'if(!$logged_in) {';
      $middle .= 'echo "<p class=\"protected\">'.$signintext.' <a href=\"$login_url\">Sign in</a></p>";';	
      $middle .= '} elseif($logged_in){';
      $middle .= 'echo "<p class=\"protected\">Hello $nick.'.$notallowed.' (<a href=\"$logout_url\">Sign Out</a>)</p>";';
      $middle .= '} } ?>';

      return $start.$out.$middle;
		} elsif($type eq 'OpenID'){
			my $signintext = $args->{oi_signin_text} || "This blog has been protected using OpenID so only selected OpenID users can read it. ";
			my $notallowed = $args->{oi_barred_text} || "You do not have the rights to access this blog. Sorry!";
	
			$start = "<?php\n";
			$start .= 'switch($openidname){';
      my $users = $protected->data;
      for my $user (@$users) {	
      	# Thanks for the regex Tweezerman!
      	if($user =~ /group:(.*)/){
      		my $group = $1;
      		my $data = Protect::Groups->load({ label => $group });
      		my $user_groups = $data->data;
      		for my $user_group (@$user_groups) {
      			$user_group = 'http://'.$user_group
      				if(index($user_group,'http://') == -1);
      			$user_group .= '/' unless $user_group =~ m!/$!;		
		      	$start .= "case \"$user_group\":\n";
		      }    		
      	} else {
      			$user = 'http://'.$user
      				if(index($user,'http://') == -1);	
      $user .= '/' unless $user =~ m!/$!;				      		
      $start .= "case \"$user\":\n"; }
      }
      $start .= ' ?>';
      $start .= '<p>Thanks for signing in <?php echo $openidname ?> <font size="1">(<a href="<?php echo $PHP_SELF."?openid_logout"; ?>">Logout</a>)</font></p>';
      $middle = "<?php\n";
      $middle .= 'break;';
      $middle .= 'default: ?>';
			$middle .= '<form method="post" id="openidform" action="<?php echo $_SERVER["PHP_SELF"]; ?>">';
 			$middle .= '<div>';
 			$middle .= '<?php if ($_SESSION["sess_openid_auth_code"] != "") { ?>';
   		$middle .= 'You are logged in as: <?=$_SESSION["sess_openid_auth_code"]?>'.$notallowed.' (<a href="<?php echo $PHP_SELF."?openid_logout"; ?>">Logout</a>)';
  		$middle .= '<?php } else { ?>';
   		$middle .= '<input type="hidden" name="openid_type" value="openid" />';
   		$middle .= '<label for="openid_name">'.$signintext.'</label><br />';
   		$middle .= '<input style="padding-left: 22px;background:#fff url('.$staticwebpath.'images/openid.gif) 2px 1px no-repeat;" type="text" value="" name="openid_name" id="openid_name" />';
   		$middle .= '<input type="submit" id="openidsubmit" value="Log In" />';
 			$middle .= '<?php } ?>';
 			$middle .= '</div>';
			$middle .= '</form>';      
			$middle .= '<?php } ?>';
      return $start.$out.$middle;
		}
	}	 
}

