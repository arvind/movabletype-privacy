#!/usr/bin/perl
package MT::Plugin::Protect;
use strict;
use MT;
use MT::Plugin;
#if (eval { use lib './plugins/Protect/lib'; 1 }) {
#  use lib './plugins/Protect/lib';
#}
use lib File::Spec->catdir('plugins','Protect','lib');
use Protect::CMS;
use Protect::Protect;
use Protect::Groups;
use MT::Template::Context;

use vars qw($VERSION);
my $about = {
	dir => 'Protect',
  name => 'MT Protect v'.$Protect::CMS::VERSION,
  config_link => 'mt-protect.cgi?__mode=global_config',
  description => 'Adds the ability to protect entires either by password or using Typekey authentication.',
  doc_link => 'http://www.movalog.com/plugins/wiki/MtProtect'
}; 
MT->add_plugin(new MT::Plugin($about));
MT->add_plugin_action ('entry', 'mt-protect.cgi?__mode=edit', "Protect this entry");
MT->add_plugin_action ('list_entries', 'mt-protect.cgi?__mode=list_entries', "List Protected Entries");
MT->add_plugin_action ('blog', 'mt-protect.cgi?__mode=edit', 'Edit Protection Options');
MT->add_plugin_action ('list_commenters', "mt-protect.cgi?__mode=edit&_type=groups\" onclick=\"var l=encodeURI(location); var h=this.href;var s;var ids = new Array;ids=document.getElementsByName('id');for (var i=0;i < ids.length;i++) if (ids[i].checked) s=ids[i].value+','+s;this.href=h+'&amp;author_id='+s+'&amp;_return='+l;\" annoying=\"", 'Add checked commenters to group');

MT::Template::Context->add_tag(ProtectInclude           => \&include);
MT::Template::Context->add_container_tag(Protected    => \&protected);
MT::Template::Context->add_container_tag(EntryProtect    => \&protected);
MT::Template::Context->add_container_tag(BlogProtect    => \&blog_protected);
MT::Template::Context->add_conditional_tag(IfProtected    => \&ifprotected);

sub include {
  my($ctx) = @_;	
  my $path = MT::instance()->server_path() || "";
  $path =~ s!/*$!!;
  my $blog_path = $_[0]->stash('blog')->site_path;
  $blog_path .= '/' unless $blog_path =~ m!/$!;
	my $html = "<?php ";
	$html .= '$tk_token = \''.$ctx->stash('blog')->remote_auth_token.'\'; ';
	$html .= 'include "'.$blog_path.'typekey_lib.php"; ';
	$html .= '$logged_in = typekey_logged_in();';
	$html .= '$login_url = typekey_login_url();';
	$html .= '$name = typekey_name();';
	$html .= '$nick = typekey_nick();';
	$html .= '$logout_url = typekey_logout_url();';
	$html .= 'include(\''.$path.'/php/mt.php\'); ';
	$html .= '$mt = new MT('.$ctx->stash('blog')->id.', \''.$path.'/mt.cfg\'); ';
	$html .= '$db = $mt->db(); ';
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
	my ($ctx, $args) = @_;
  my $blog_id = $_[0]->stash('blog')->id;
  my $blog_url = $_[0]->stash('blog')->site_url;
  $blog_url .= '/' unless $blog_url =~ m!/$!;
  my $builder = $ctx->stash ('builder');
  my $tokens = $ctx->stash ('tokens');
	my $e = $_[0]->stash('entry');
	my $entry_id = $e->id;
	my ($start, $middle, $bottom, $protected);
    defined (my $out = $builder->build ($ctx, $tokens))
      or return $ctx->error ($ctx->errstr);
		unless($protected = Protect::Protect->load({ entry_id   => $entry_id })){
		return $out;
	}
	if($protected) {
		my $type = $protected->type;
		if($type eq 'Password') {
				$start = "<?php\n";
				$start .= '$pass = $db->get_var("select protect_password from mt_protect where protect_entry_id = '.$entry_id.'"); ';
				$start .= '$cookie = \'mt-postpass_\'.md5($pass); ';
				$start .= 'if($pass == "" || isset($_REQUEST[$cookie]) ) { ?>';
				$middle = '<?php } else { ?>';
				$middle .= '<form action="'.$blog_url.'mt-password.php" method="post">';
				$middle .= '<input name="entry_id" value="'.$entry_id.'" type="hidden" />';
				$middle .= '<input name="blog_id" value="'.$blog_id.'" type="hidden" />';
     		$middle .= '<p>This post is password protected. To view it please enter your password below:</p>';
     		$middle .= '<p><label>Password:</label> <input name="post_password" type="text" size="20" /> <input type="submit" name="Submit" value="Submit" /></p>';
        $middle .= '</form>';
				$bottom = '<?php } ?>';
				return $start.$out.$middle.$bottom;
		} elsif($type eq 'Typekey'){
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
      $middle .= 'echo "This entry has been Typekey protected so only selected Typekey users can read it. <a href=\"$login_url\">Sign in</a>";';	
      $middle .= '} elseif($logged_in){';
      $middle .= 'echo "Hello $nick. You do not have the rights to access this entry. Sorry! (<a href=\"$logout_url\">Sign Out</a>)";';
      $middle .= '} } ?>';
      return $start.$out.$middle;
		}
	}	 
}

sub blog_protected {
	my ($ctx, $args) = @_;
  my $blog_id = $_[0]->stash('blog')->id;
  my $blog_url = $_[0]->stash('blog')->site_url;
  $blog_url .= '/' unless $blog_url =~ m!/$!;
  my $builder = $ctx->stash ('builder');
  my $tokens = $ctx->stash ('tokens');
	my $entry_id = '0';
	my ($start, $middle, $bottom, $protected);
    defined (my $out = $builder->build ($ctx, $tokens))
      or return $ctx->error ($ctx->errstr);
		unless($protected = Protect::Protect->load({ entry_id   => $entry_id, blog_id => $blog_id })){
		return $out;
	}
	if($protected) {
		my $type = $protected->type;
		if($type eq 'Password') {
				$start = "<?php\n";
				$start .= '$pass = $db->get_var("select protect_password from mt_protect where protect_entry_id = '.$entry_id.' and protect_blog_id ='.$blog_id.'"); ';
				$start .= '$cookie = \'mt-postpass_\'.md5($pass); ';
				$start .= 'if($pass == "" || isset($_REQUEST[$cookie]) ) { ?>';
				$middle = '<?php } else { ?>';
				$middle .= '<form action="'.$blog_url.'mt-password.php" method="post">';
				$middle .= '<input name="entry_id" value="'.$entry_id.'" type="hidden" />';
				$middle .= '<input name="blog_id" value="'.$blog_id.'" type="hidden" />';
     		$middle .= '<p>This post is password protected. To view it please enter your password below:</p>';
     		$middle .= '<p><label>Password:</label> <input name="post_password" type="text" size="20" /> <input type="submit" name="Submit" value="Submit" /></p>';
        $middle .= '</form>';
				$bottom = '<?php } ?>';
				return $start.$out.$middle.$bottom;
		} elsif($type eq 'Typekey'){
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
      $middle .= 'echo "This entry has been Typekey protected so only selected Typekey users can read it. <a href=\"$login_url\">Sign in</a>";';	
      $middle .= '} elseif($logged_in){';
      $middle .= 'echo "Hello $nick. You do not have the rights to access this entry. Sorry! (<a href=\"$logout_url\">Sign Out</a>)";';
      $middle .= '} } ?>';
      return $start.$out.$middle;
		}
	}	 
}

