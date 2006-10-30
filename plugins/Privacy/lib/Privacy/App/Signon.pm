# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.


package Privacy::App::Signon;
use strict;

use vars qw( $DEBUG @ISA );
@ISA = qw(MT::App);

use MT::Util qw( format_ts offset_time_list );

use MT::App;
use MT;

sub init
{
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;
    $app->add_methods(
		'signon' => \&signon
    );
  
    $app->{plugin_template_path} = File::Spec->catdir('plugins','Privacy','tmpl');
    $app->{default_mode}   = 'signon';
    $app->{user_class}     = 'MT::Author';
    $app->{requires_login} = 0;
    $app->{mtscript_url}   = $app->mt_uri;
    $app;
}

my %API = (
    entry   => 'MT::Entry',
    blog => 'MT::Blog',
    category => 'MT::Category',
);

sub _load_driver_for {
    my $app = shift;
    my($type) = @_;
    my $class = $API{$type} or
        return $app->error($app->translate("Unknown object type [_1]",
            $type));
    eval "use $class;";
    return $app->error($app->translate(
        "Loading object driver [_1] failed: [_2]", $class, $@)) if $@;
    $class;
}

sub signon {
	my $app = shift;
	my $q = $app->param;
	my $privacy_frame = $app->plugin;
		
	my $datasource = $q->param('datasource');
	my $auth_type = $q->param('auth');
	my $id = $q->param('id');
	my $blog_id = $q->param('blog_id');
	my $class = $app->_load_driver_for($datasource);
	my $obj = $class->load($id);
	
	require MT::Request;
	my $req = MT::Request->instance;
	$req->stash('private_obj', $obj);
	
	require MT::Blog;
	my $blog = MT::Blog->load($blog_id);
	my $redirect = $blog->site_url;
	
	if($datasource eq 'entry') {
		$redirect = $obj->permalink;
	} elsif($datasource eq 'category') {
		my $at = $blog->archive_type;
		if($at =~ /Category/) {
			require MT::Category;
			require MT::Util;
		    my $arch = $blog->archive_url;
		    $arch .= '/' unless $arch =~ m!/$!;
		    $arch = $arch . MT::Util::archive_file_for(undef, $blog, 'Category', $obj);
		    $arch = MT::Util::strip_index($arch, $blog);	
			$redirect = $arch;
		}
	}	
	
	my ($auth) = (grep {$_->{key} eq $auth_type}
                             @{$privacy_frame->{privacy_types}});
    return $app->errtrans("That authentication ([_1]) is apparently not implemented!",
                          $auth_type)
        unless $auth;

    my $allow;
 	$auth->{signon_code}->($app, \$allow);

	# # die $allow;
	if($allow == 1) {
		## Now issue the cookie, we'll check the domains of this script and the bog
		## If they match, let the script issue the cookie - more secure
		## Else redirect to the php script which will issue the cookie
		
		my ($cgihost, $bloghost);
	    my $path = MT::ConfigMgr->instance->CGIPath;
	    $path .= '/' unless $path =~ m!/$!;
	    if ($path =~ m!^https?://([^/:]+)(:\d+)?/!) {
	        $cgihost = $_[1]->{exclude_port} ? $1 : $1 . ($2 || '');
	    }
	    $path = $blog->site_url;
	    if ($path =~ m!^https?://([^/:]+)(:\d+)?/!) {
	        $bloghost = $_[1]->{exclude_port} ? $1 : $1 . ($2 || '');
	    } 
	    
	    if($cgihost eq $bloghost) {
			$app->bake_cookie(
				-name => $obj->datasource.$obj->id, 
				-value => 1,
				-path => '/'
			);
			return $app->redirect($redirect);		    	
	    } else {
			my $rand = $app->_rand;
			$privacy_frame->set_config_value('rand', $rand);   	
			my $url = $blog->site_url;
			$url .= '/' unless $url =~ m!/$!;
			return $app->redirect($url.'privacy.php?rand='.$rand.'&datasource='.$obj->datasource.'&id='.$id.'&blog_id='.$blog->id.'&redirect='.$redirect);
	    }           				
	} elsif($allow == 2) {
		require MT::Template;
		require MT::Template::Context;
		my $ctx = MT::Template::Context->new;
		$ctx->{__stash}{blog} = $blog;
		$ctx->{__stash}{blog_id} = $blog_id;
		$ctx->{__stash}{private_obj} = $obj;
		$ctx->{__stash}{"$datasource"} = $obj;
		my $tmpl = MT::Template->load({ blog_id => $blog_id, type => 'privacy_barred'});
		my %cond;
		my $protect_text = $tmpl->build($ctx, \%cond);
		$protect_text = $tmpl->errstr unless defined $protect_text;	
		$app->{no_print_body} = 1;
		$app->send_http_header;
		$app->print($protect_text);
	}
}


#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub _rand {
    my ($app) = @_;
    $app->{__have_md5} = (eval { require Digest::MD5; 1 } ? 1 : 0)
        unless exists $app->{__have_md5};
    $app->{__have_md5} ? substr(rand(), 2) :
        Digest::MD5::md5_hex(Digest::MD5::md5_hex(time() . {} . rand() . $$));
}

sub debug {
    my $err = shift;
    my $mark = shift || '>';
    print STDERR "$mark $err\n" if $DEBUG;
}

sub uri { my $app = shift; $app->app_path . $app->script . $app->uri_params(@_); }

sub plugin {
	return MT::Plugin::Privacy->instance;
}


1;