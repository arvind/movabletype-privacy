# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.

package MT::Plugin::Privacy::Password;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.2 or later

use base 'MT::Plugin';
our $VERSION = '2.0';

my $plugin;
MT->add_plugin($plugin = __PACKAGE__->new({
	name            => "Password Authentication",
	version         => $VERSION,
	description     => "<MT_TRANS phrase=\"Allows you to make assets private using passwords\">",
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
		key => "password",
		label => "Password",
		type => "single", 
		lexicon => {
			'FIELD_LABEL' => 'Password',
		},
		verification_fields => {
			'password' => 'password'
		},
		signon_code => sub { $plugin->verify(@_); }
    });
}

sub verify {
	my $plugin = shift;
    my ($app) = @_;
	my $blog_id = $app->param('blog_id');

	require MT::Request;
	my $req = MT::Request->instance;
	my $obj = $req->stash('private_obj');
	
	require Privacy::Object;
	my $password = Privacy::Object->load({ type => 'password', object_id => $obj->id, object_datasource => $obj->datasource, blog_id => $blog_id });

	return $req->stash('privacy_allow', 1)  if $app->param('password') eq $password->credential;
	
	return $req->stash('privacy_allow', 2);
}


1;
