#!/usr/bin/perl -w

use strict;

my($MT_DIR, $PLUGIN_DIR, $PLUGIN_ENVELOPE);
BEGIN {
eval {
    require File::Basename; import File::Basename qw( dirname );
    require File::Spec;

    $MT_DIR = $ENV{PWD};
    $MT_DIR = dirname($0)
        if !$MT_DIR || !File::Spec->file_name_is_absolute($MT_DIR);
    $MT_DIR = dirname($ENV{SCRIPT_FILENAME})
        if ((!$MT_DIR || !File::Spec->file_name_is_absolute($MT_DIR))
            && $ENV{SCRIPT_FILENAME});
    unless ($MT_DIR && File::Spec->file_name_is_absolute($MT_DIR)) {
        die "Plugin couldn't find own location";
    }
};
if ($@) {
    print "Content-type: text/html\n\n$@";
    exit(0);
}

$PLUGIN_DIR = $MT_DIR;
($MT_DIR, $PLUGIN_ENVELOPE) = $MT_DIR =~ m|(.*[\\/])(plugins[\\/].*)$|i;

unshift @INC, $MT_DIR . 'lib';
unshift @INC, $MT_DIR . 'extlib';
unshift @INC, $PLUGIN_DIR . '/lib';
};


package Protect::OpenIDSignOn;

use MT;
use MT::App;
use base qw( MT::App );

use Net::OpenID::Consumer;
use XML::XPath;

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;

    $app->add_methods(
        oops   => \&oops,
        signon => \&signon,
        verify => \&verify,
    );

    $app->{default_mode} = 'oops';
    $app;
}

sub oops {
    "<h1>Here be dragons.</h1>";
}

sub _get_csr {
    my $ua = eval { require LWPx::ParanoidAgent; LWPx::ParanoidAgent->new; };
    $ua ||= LWP::UserAgent->new;
    Net::OpenID::Consumer->new(
        ua => $ua,
        args => $_[0]->{query},
        consumer_secret => 'HELLO HAPPY SECRET SECRET',
    );
}

sub signon {
    my $app = shift;
    my $csr = $app->_get_csr;
    my $q = $app->{query};

    my $identity = $q->param('openid_url');
    if(!$identity && $q->param('lj_user')) {
        $identity = 'http://www.livejournal.com/users/' . $q->param('lj_user');
    }
    if(!$identity && $q->param('tk_user')) {
        $identity = 'http://profile.typekey.com/' . $q->param('tk_user');
    }
    my $claimed_identity = $csr->claimed_identity($identity)
        or return $app->error("Could not discover claimed identity: ". $csr->err);

    my $root = MT::ConfigMgr->instance->CGIPath;
	my $qs = '?__mode=verify';
	$qs .= "&$_=".$q->param($_)
		foreach $q->param;
	# for my $qparam ($q->param) {
	# 	$qs .= "&$qparam=".$q->param($qparam);
	# }
    my $return_to = $app->base . $app->uri . $qs;
    my $check_url = $claimed_identity->check_url(
        return_to => $return_to,
        trust_root => $root,
    );

    return $app->redirect($check_url);
}

sub _rand {
    my ($app) = @_;
    $app->{__have_md5} = (eval { require Digest::MD5; 1 } ? 1 : 0)
        unless exists $app->{__have_md5};
    $app->{__have_md5} ? substr(rand(), 2) :
        Digest::MD5::md5_hex(Digest::MD5::md5_hex(time() . {} . rand() . $$));
}

sub _get_profile_data {
    my ($app, $vident, $blog_id) = @_;

    my $ua = eval { require LWPx::ParanoidAgent; 1; }
           ? LWPx::ParanoidAgent->new
           : LWP::UserAgent->new
           ;

    my $profile = {};

    my $url = $vident->url;
    if( $url =~ m(^https?://www\.livejournal\.com\/users/([^/]+)/$) ||
        $url =~ m(^https?://www\.livejournal\.com\/~([^/]+)/$) ||
        $url =~ m(^https?://([^\.]+)\.livejournal\.com\/$) || 
		$url =~ m(^https?://profile\.typekey\.com\/([^/]+)/$) ||
		$url =~ m(^http?://profile\.typekey\.com\/([^/]+)/$)
    ) {
        $profile->{nickname} = $1;
    }

    $profile->{nickname} ||= $vident->display;
    return $profile;
}

sub verify {
    my $app = shift;
    my $q = $app->{query};
	my $plugin = MT::Plugin::Protect->instance;
	my $obj_type = $q->param('_type');
	my $obj_id = $q->param('id');
	my $blog_id = $q->param('blog_id');
	require MT::Blog;
	my $blog = MT::Blog->load($blog_id);
	my $allow = 0;
	require Protect::Object;
    my $obj = Protect::Object->load({ blog_id => $blog->id, object_datasource => $obj_type, object_id => $obj_id })
        or return $app->error('Invalid '.$obj_type.' id '. $obj_id .' in verification');
	if($q->param('password')) {
		if($q->param('password') eq $obj->password) {
			$allow = 1;
		}
	} else {
	    my $csr = $app->_get_csr;
		if(!$q->param('openid.mode')) {
			$app->signon;
		}
		$csr->verified_identity or die $csr->errcode;
	    if(my $setup_url = $csr->user_setup_url( post_grant => 'return' )) {
	        return $app->redirect($setup_url);
	    } elsif(my $vident = $csr->verified_identity) {
			my $profile = $app->_get_profile_data($vident, $blog->id);
			if($q->param('tk_user')) {
				my @typekey = split /,/, $obj->typekey_users;
				if(in_array($profile->{nickname}, @typekey)) {
					return 'hello';
					$allow = 1;
				}
			} elsif($q->param('lj_user')) {
				my @livejournal = split /,/, $obj->livejournal_users;
				if(in_array($profile->{nickname}, @livejournal)) {
					$allow = 1;
				}				
			} elsif($q->param('openid_url')) {
				my @openid = split /,/, $obj->openid_users;
				if(in_array($vident->url, @openid)) {
					$allow = 1;
				}				
			}   
         ## TODO: fake email to circumvent requirement
	        #$app->_make_commenter_session($session_id, '', $author->name, $profile->{nickname});
	    } elsif($q->param('openid.mode') eq 'cancel') {
	        ## Cancelled!
	        return $app->redirect($ENV{HTTP_REFERER});
	    }
	}
	if($allow) {
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
				-name => $obj_type.$obj_id, 
				-value => 1,
				-path => '/',
			    -expires => '+1d'
			);
			return $app->redirect($ENV{HTTP_REFERER});		    	
	    } else {
			my $rand = $app->_rand;
			$plugin->set_config_value('rand', $rand);   	
			my $url = $blog->site_url;
			$url .= '/' unless $url =~ m!/$!;
			return $app->redirect($url.'mt-protect.php?rand='.$rand.'&obj_type='.$obj_type.'&obj_id='.$obj_id.'&blog_id='.$blog->id);
	    }           				
	}
    return $app->error($app->translate('Sorry you do not have'));
}

sub in_array() {
    my $val = shift(@_);
    foreach my $elem (@_) {
        if($val eq $elem) {
            return 1;
        }
    }
    return 0;
}

1;


package main;

eval {
    my $app = Protect::OpenIDSignOn->new( Config => $MT_DIR . 'mt.cfg',
                                          Directory => $MT_DIR )
        or die Protect::OpenIDSignOn->errstr;
    local $SIG{__WARN__} = sub { $app->trace($_[0]) };
    $app->run;
};
if($@) {
    print "Content-Type: text/html\n\n";
    print "An error occurred: $@";
}

