# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.

package MT::Plugin::Privacy::OpenID;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.2 or later

use base 'MT::Plugin';
our $VERSION = '2.0';

my $plugin;
MT->add_plugin($plugin = __PACKAGE__->new({
	name            => "OpenID Authentication",
	version         => $VERSION,
	description     => "<MT_TRANS phrase=\"Allows you to make assets private using Typekey, LiveJournal or OpenID Authentication\">",
	author_name     => "Arvind Satyanarayan",
	author_link     => "http://www.movalog.com/",
	plugin_link     => "http://plugins.movalog.com/privacy/",
	doc_link        => "http://plugins.movalog.com/privacy/manual",
}));

# Allows external access to plugin object: MT::Plugin::Privacy->instance
sub instance {
	$plugin;
}

sub version {
	$VERSION;
}

sub init_app {
    my $plugin = shift;
    $plugin->SUPER::init_app(@_);
    my ($app) = @_;
	my $privacy = MT::Plugin::Privacy->instance;
	$privacy->add_privacy_type({
		key => "typekey",
		label => "Typekey",
		type => "multiple", 
		lexicon => {
			'FIELD_LABEL' => 'Typekey Users',
			'FIELD_EXPLANATION' => 'Enter Typekey users here',
		},
		verification_fields => {
			'username' => 'text'
		},
		signon_code => sub { $plugin->verify(@_); }
    });
	$privacy->add_privacy_type({
		key => "livejournal",
		label => "LiveJournal",
		type => "multiple", 
		lexicon => {
			'FIELD_LABEL' => 'LiveJournal Users',
			'FIELD_EXPLANATION' => 'Enter LiveJournal users here',
		},
		verification_fields => {
			'username' => 'text'
		},
		signon_code => sub { $plugin->verify(@_); }
    });
	$privacy->add_privacy_type({
		key => "openid",
		label => "OpenID",
		type => "multiple", 
		lexicon => {
			'FIELD_LABEL' => 'OpenID URLs',
			'FIELD_EXPLANATION' => 'Enter OpenID URLs here',
		},
		verification_fields => {
			'url' => 'text'
		},
		signon_code => sub { $plugin->verify(@_); }
    });
}

my %URL = (
	'typekey' => 'http://profile.typekey.com/',
	'livejournal' => 'http://www.livejournal.com/users/',
	'openid' => ''
);

sub _get_profile_data {
    my ($plugin, $vident, $blog_id) = @_;

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

    $profile->{nickname} ||= $vident->url;
    return $profile;
}

sub verify {
	my $plugin = shift;
	my ($app, $allow) = @_;
	my $q = $app->param;
	my $type = $q->param('auth');
	
	require MT::Request;
	my $req = MT::Request->instance;
	my $obj = $req->stash('private_obj');	

	require Net::OpenID::Consumer;
	require XML::XPath;

    my $ua = eval { require LWPx::ParanoidAgent; LWPx::ParanoidAgent->new; };
    $ua ||= MT->new_ua;
	
	my $csr = Net::OpenID::Consumer->new(
	  ua    => $ua,
	  args  => $app->{query},
	  consumer_secret => 'HELLO HAPPY SECRET SECRET',
	);	
	my $user = $q->param('url') || $q->param('username');
	if(!$q->param('openid.mode')) {
	    my $claimed_identity = $csr->claimed_identity($URL{$type}.$user)
	        or return $app->error("Could not discover claimed identity: ". $csr->err);		
	
		my $qs = '?';
		$qs .= "&$_=".$q->param($_)
			foreach $q->param;	
		
	    my $check_url = $claimed_identity->check_url(
	        return_to => $app->base.$app->uri.$qs,
	        trust_root => $app->config->CGIPath,
	    );		
	
		return $app->redirect($check_url);
	}
	
    if(my $setup_url = $csr->user_setup_url( post_grant => 'return' )) {
        return $app->redirect($setup_url);
    } elsif(my $vident = $csr->verified_identity) {
		my $profile = $plugin->_get_profile_data($vident, $obj->blog_id);
		
		require Privacy::Object;
		my @users = Privacy::Object->load({ type => $type, object_id => $obj->id, object_datasource => $obj->datasource, blog_id => ($obj->blog_id || $obj->id) });
		
		if(in_array($profile->{nickname}), @users) {
			return $req->stash('privacy_allow', 1);
		}
    } else {
	       die "Error validating identity: " . $csr->errcode;
	  }	
	
	return $req->stash('privacy_allow', 2);
}

sub in_array() {
    my $val = shift(@_);
    foreach my $elem (@_) {
        if(lc($val) =~ lc($elem->credential)) {
            return 1;
        }
    }
    return 0;
}


1;
