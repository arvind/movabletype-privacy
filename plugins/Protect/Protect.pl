# Protect - A plugin for Movable Type.
# Copyright (c) 2006, Arvind.

package MT::Plugin::Protect;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.2 or later

use base 'MT::Plugin';
our $VERSION = '2.0';
our $SCHEMA_VERSION = '2.0';

my $plugin;
MT->add_plugin($plugin = __PACKAGE__->new({
	name            => "MT Protect",
	version         => $VERSION,
	description     => "<MT_TRANS phrase=\"Protect entries and blogs using passwords, typekey or openid authentication.\">",
	author_name     => "Arvind Satyanarayan",
	author_link     => "http://www.movalog.com/",
	plugin_link     => "http://plugins.movalog.com/protect/",
	doc_link        => "http://plugins.movalog.com/protect/manual",
	schema_version  => $SCHEMA_VERSION,
	object_classes  => [ 'Protect::Groups', 'Protect::Object' ],
	upgrade_functions => {
        'convert_data' => {
            version_limit => 2.0,   # runs for schema_version < 2.0
            code => \&convert_data
        }
    },
	l10n_class 	    => 'Protect::L10N',
    app_action_links => {
        'MT::App::CMS' => {
#            'list_entries' => {
#                link => 'mt-protect.cgi?__mode=list_entries',
#                link_text => 'List Protected Entries'
#            },
            'list_commenters' => {
                link => 'mt-protect.cgi?__mode=tk_groups',
                link_text => 'List Protection Groups'
            },
            'blog' => {
                link => 'mt-protect.cgi?__mode=edit',
                link_text => 'Protect Blog'
            }
        }
    },
	app_itemset_actions => {
		'MT::App::CMS' => {
			'commenter' => {
				key => "set_protection_group",
				label => "Create a Protection Group",
				code => sub {
					my $app = shift;
					$app->redirect($app->path . 'plugins/Protect/mt-protect.cgi?__mode=edit&_type=groups&author_id='. join ',', $app->param('id'));
				}				
			},
			# 'entry' => {
			#                 key => "set_protection",
			#                 label => "Protect Entries",
			#                 code => sub { $plugin->protect_entries(@_) },
			# 	condition => sub { my $app = MT->instance; $app->mode eq 'list_entries' }				
			# },
			# 'blog' => {
			#                 key => "set_protection",
			#                 label => "Protect Blog(s)",
			#                 code => sub { $plugin->protect_blogs(@_) }				
			# }
		}
	},
	callbacks => {
		'MT::App::CMS::AppTemplateSource.edit_entry' => sub { require Protect::Transformer; Protect::Transformer::_edit_entry(@_); },
		'MT::App::CMS::AppTemplateParam.edit_entry'  => sub { require Protect::Transformer; Protect::Transformer::_param(@_, 'entry'); },
		'MT::Entry::post_save' => sub { require Protect::Transformer; Protect::Transformer::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.edit_category' => sub { require Protect::Transformer; Protect::Transformer::_edit_category(@_); },
		'MT::App::CMS::AppTemplateParam.edit_category' => sub { require Protect::Transformer; Protect::Transformer::_param(@_, 'category'); },
		'MT::Category::post_save' => sub { require Protect::Transformer; Protect::Transformer::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.entry_table' => sub { require Protect::Transformer; Protect::Transformer::_list_entry(@_); },
		'MT::App::CMS::AppTemplateParam.list_entry' => sub { require Protect::Transformer; Protect::Transformer::_list_entry_param(@_); },
		'Protect::CMS::AppTemplateParam.edit' => sub { require Protect::Transformer; Protect::Transformer::_param(@_, 'blog'); }
	},
	container_tags => {
		# 'EntryProtect'	=> \&protected,
		# 'BlogProtect'	=> \&blog_protected,
		'Protect'		=> sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect(@_);},
		'IfProtected'	=> \&ifprotected
	},
	template_tags => {
		'ProtectObjectID' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect_obj_id(@_);},
		'ProtectObjectType' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect_obj_type(@_);}
	},
    settings => new MT::PluginSettings([
        ['protect_text', { Default => q{<MTIgnore>
#### Javascript to toggle the display of the various protection types
</MTIgnore>
<script type="text/javascript">
<!--
	function toggleProtect(type, id) {
		var types = new Array('password', 'typekey', 'livejournal', 'openid');
		for (var i = 0; i < types.length; i++) {
			var el = document.getElementById(types[i] + '-' + id + '-protect');
			if(el) el.style.display = 'none';
		}
		var el = document.getElementById(type + '-' + id + '-protect');
		if(el) el.style.display = 'block';
	}
//-->
</script>
<p>This <MTProtectObjectType> has been protected</p>
<p>
	<MTIfPasswordProtected>
		<a href="#" onclick="toggleProtect('password', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-password.gif" alt="Enter Password" /></a>
	</MTIfPasswordProtected>
	
	<MTIfTypekeyProtected>
		<a href="#" onclick="toggleProtect('typekey', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-typekey.gif" alt="Login via Typekey" /></a>
	</MTIfTypekeyProtected>
	
	<MTIfLiveJournalProtected>
		<a href="#" onclick="toggleProtect('livejournal', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-livejournal.gif" alt="Login via LiveJournal" /></a>
	</MTIfLiveJournalProtected>
	
	<MTIfOpenIDProtected>
		<a href="#" onclick="toggleProtect('openid', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-openid.gif" alt="Login via OpenID" /></a>
	</MTIfOpenIDProtected>
</p>

<form action="<MTCGIPath>plugins/Protect/signon.cgi" method="post" id="password-protect">
	<input type="hidden" name="__mode" value="verify" />
	<input type="hidden" name="blog_id" value="<MTBlogID>" />
	<input type="hidden" name="id" value="<MTProtectObjectID>" />
	<input type="hidden" name="_type" value="<MTProtectObjectType>" />
	
	<MTIfPasswordProtected>
		<div id="password-<MTProtectObjectID>-protect" style="display:none;">
			<p>This <MTProtectObjectType> has been password protected. Enter the password below to view the <MTProtectObjectType>:</p>
			<p>
				<label>Password: <input type="text" name="password" value="" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfPasswordProtected>
	
	<MTIfTypekeyProtected>
		<div id="typekey-<MTProtectObjectID>-protect" style="display:none;">
			<p>This <MTProtectObjectType> has been Typekey protected. Enter your Typekey username below to view the <MTProtectObjectType>:</p>
			<p>
				<label>Typekey Username: <input type="text" name="tk_user" value="" style="background: white url(<MTStaticWebPath>plugins/Protect/images/input-typekey.gif) no-repeat; padding-left: 22px;" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfTypekeyProtected>
	
	<MTIfLiveJournalProtected>
		<div id="livejournal-<MTProtectObjectID>-protect" style="display:none;">
			<p>This <MTProtectObjectType> has been LiveJournal protected. Enter your LiveJournal username below to view the <MTProtectObjectType>:</p>
			<p>
				<label>LiveJournal Username: <input type="text" name="lj_user" value="" style="background: white url(<MTStaticWebPath>plugins/Protect/images/input-livejournal.gif) no-repeat; padding-left: 22px;" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfLiveJournalProtected>	
	
	<MTIfOpenIDProtected>
		<div id="openid-<MTProtectObjectID>-protect" style="display:none;">
			<p>This <MTProtectObjectType> has been OpenID protected. Enter your OpenID URL below to view the <MTProtectObjectType>:</p>
			<p>
				<label>OpenID Username: <input type="text" name="openid_url" value="" style="background: white url(<MTStaticWebPath>plugins/Protect/images/input-openid.gif) no-repeat; padding-left: 22px;" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfOpenIDProtected>	
	
</form>
} }]
    ]),
	config_template => 'config.tmpl'
}));

# Allows external access to plugin object: MT::Plugin::Protect->instance
sub instance {
	$plugin;
}

sub version {
	$VERSION;
}

sub init {
	my $plugin = shift;
	$plugin->SUPER::init(@_);
	MT->config->PluginSchemaVersion({})
	unless MT->config->PluginSchemaVersion;
}

sub apply_default_settings {
  my ($plugin, $data, $scope_id) = @_;
  if ($scope_id eq 'system') {
    return $plugin->SUPER::apply_default_settings($data, $scope_id);
  } else {
    my $sys;
    for my $setting (@{$plugin->{'settings'}}) {
      my $key = $setting->[0];
      next if exists($data->{$key});
        # don't load system settings unless we need to
      $sys ||= $plugin->get_config_obj('system')->data;
      $data->{$key} = $sys->{$key};
    }
  }
}

sub convert_data {
	require Protect::Protect;
	require Protect::Object;
	require Protect::Groups;
	my $objs_iter = Protect::Protect->load_iter();
	while (my $orig_obj = $objs_iter->()) {
		my $obj = Protect::Object->new;
		$obj->blog_id($orig_obj->blog_id);
		$obj->object_id($orig_obj->entry_id);
		$obj->object_datasource('entry');
		if(!$orig_obj->entry_id) {
			$obj->object_datasource('blog');
			$obj->object_id($orig_obj->blog_id);
		}
		if($orig_obj->type eq 'Password') {
			$obj->password($orig_obj->data);
		} else {
			my $users = $orig_obj->data;
			$users = join ',', @$users;
			if($orig_obj->type eq 'Typekey') {
				$obj->typekey_users($users);
			} elsif($orig_obj->type eq 'OpenID') {
				$obj->openid_users($users);
			}
		}
		$obj->save or die $obj->errstr;
		$orig_obj->remove or die $orig_obj->errstr;
	}
	
	my $groups_iter = Protect::Groups->load_iter();
	while (my $group = $groups_iter->()) {
		my $users = $group->data;
		$users = join ',', @$users;		
		if($group->type eq 'Typekey') {
			$group->typekey_users($users);
		} elsif($group->type eq 'OpenID') {
			$group->openid_users($users);
		}
		$group->type('');
		$group->save or die $group->errstr;
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
				$start .= '$password = $db->get_var("select protect_data from mt_protect where protect_entry_id = '.$entry_id.'"); ';
				$start .= '$pass = $db->unserialize($password);';
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
				$start .= '$password = $db->get_var("select protect_data from mt_protect where protect_entry_id = 0 and protect_blog_id = '.$blog_id.'"); ';
				$start .= '$pass = $db->unserialize($password);';
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

# 
# sub config_template {
#     my $app = $mt;
#     my $q = $app->{query};
#     my ($plugin,$param) = @_;
#     my $cblog_id = $q->param('cblog_id');
#     if($cblog_id){
#         my $cblog = MT::Blog->load($cblog_id);
#         $param->{cblog} = $cblog->name;
#         $param->{installed} = $q->param('installed');
#         $param->{uninstalled} = $q->param('uninstalled');
#     $param->{protect_url} = $app->path;        
#     }
#     #    $param->{breadcrumbs} = $app->{breadcrumbs};
#     #    $param->{breadcrumbs}[-1]{is_last} = 1;
# if (my $auth = $app->{author}) {
# 
#         my @perms = MT::Permission->load({ author_id => $auth->id });
#         my @data;
#         for my $perms (@perms) {
#             next unless $perms->role_mask;
#             my $blog = MT::Blog->load($perms->blog_id);
#             my $pdblog = MT::PluginData->load({ plugin => 'Protect', key    => $perms->blog_id });
#             push @data, { blog_id   => $blog->id,
#                 blog_name => $blog->name,
#             blog_installed => $pdblog };
#         }
#         $param->{blog_loop} = \@data;
#        
#     }	
#     my $tmpl = <<'EOT';
#     <TMPL_IF NAME=CBLOG>
# <p class="message"><MT_TRANS phrase="Protection was"> <TMPL_IF NAME=INSTALLED><i><MT_TRANS phrase="installed"></i></TMPL_IF><TMPL_IF NAME=UNINSTALLED><i><MT_TRANS phrase="uninstalled"></i></TMPL_IF> <MT_TRANS phrase="from"> <TMPL_VAR NAME=CBLOG></p>
# </TMPL_IF>
#  <p><MT_TRANS phrase="Listed below are each of the blogs that you have installed on your system.  Following the blog name is the status of protections for that blog.  After the status of the blog is a link that will perform the opposite function for you.  For instance, if protection is disabled, you will see a link that will enable it for you.  Likewise, if protection is enabled, you will instead see the option to disable it."></p>
#  <ul style="list-style-type: none;">
#  <TMPL_LOOP NAME=BLOG_LOOP>
#      <li><p><a href="<TMPL_VAR NAME=MT_URL>?__mode=menu&blog_id=<TMPL_VAR NAME=BLOG_ID>" style="text-decoration: none;"><TMPL_VAR NAME=BLOG_NAME></a><br /><MT_TRANS phrase="Protection is"> <TMPL_IF NAME=BLOG_INSTALLED><MT_TRANS phrase="Enabled:"> <a href="plugins/Protect/mt-protect.cgi?__mode=load_files&_type=uninstall&cblog_id=<TMPL_VAR NAME=BLOG_ID>" style="text-decoration: none;"><MT_TRANS phrase="Disable"></a><TMPL_ELSE><MT_TRANS phrase="Disabled:"> <a href="plugins/Protect/mt-protect.cgi?__mode=load_files&_type=install&cblog_id=<TMPL_VAR NAME=BLOG_ID>" style="text-decoration: none;"><MT_TRANS phrase="Enable"></a></TMPL_IF></p></li>
#  </TMPL_LOOP>
#  </ul>
# EOT
# } 
# 


1;
