# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.

package MT::Plugin::Privacy::LDAP;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.2 or later

# return 1 if MT->product_code ne 'MTE';

use base 'MT::Plugin';
our $VERSION = '1.0';

my $plugin;
MT->add_plugin($plugin = __PACKAGE__->new({
	name            => "Author and LDAP Authentication",
	version         => $VERSION,
	description     => "<MT_TRANS phrase=\"Allows you to make assets private using MTAuthor or LDAP Authentication. Available for only Movable Type Enterprise. \">",
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
	if(MT->produce_code eq 'MTE') {
		$privacy->add_privacy_type({
			key => "ldap",
			label => "Authors and LDAP",
			type => "multiple", 
			lexicon => {
				'FIELD_LABEL' => 'MT authors and LDAP users',
				'FIELD_EXPLANATION' => 'Enter MT authors and LDAP users here',
			},
			verification_fields => {
				'username' => 'text',
				'password' => 'password'
			},
			signon_code => sub { $plugin->verify(@_); }
	    });		
	}
}

sub verify {
	my $plugin = shift;
	my ($app, $allow) = @_;
	my $q = $app->param;
	my $blog_id = $q->param('blog_id');
	
	require MT::Request;
	my $req = MT::Request->instance;
	my $obj = $req->stash('private_obj');	

	require MT::Auth;
	if(my $valid_auth = MT::Auth->is_valid_password($q->param('username'), $q->param('password'))) {
		require Privacy::Object;
		my @users = Privacy::Object->load({ type => 'ldap', object_id => $obj->id, object_datasource => $obj->datasource, blog_id => $blog_id });
		
		if(in_array($q->param('username')), @users) {
			return $req->stash('privacy_allow', 1);
		}
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
