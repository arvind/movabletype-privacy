# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package MT::Plugin::Privacy;

use 5.006;    # requires Perl 5.6.x
use MT 4.0;   # requires MT 4.0 or later

use base 'MT::Plugin';
our $VERSION = '2.1';
our $SCHEMA_VERSION = '2.11';

my $plugin;
MT->add_plugin($plugin = __PACKAGE__->new({
	name            => "Privacy",
	version         => $VERSION,
	description     => "<MT_TRANS phrase=\"Make entries, category and blogs private using passwords or third party authentication\">",
	author_name     => "Arvind Satyanarayan",
	author_link     => "http://www.movalog.com/",
	plugin_link     => "http://plugins.movalog.com/privacy/",
	doc_link        => "http://plugins.movalog.com/privacy/manual",
	schema_version  => $SCHEMA_VERSION,
}));

# Allows external access to plugin object: MT::Plugin::Privacy->instance
sub instance { $plugin; }

sub init_registry {
	my $plugin = shift;
	my $r = {
		object_types => {
			'privacy_object' => 'Privacy::Object'
		}, 
		tags => {
			function => {
				'App:Privacy' => sub { runner('_hdlr_app_privacy', 'Privacy::Template::ContextHandlers', @_); }
			}
		},
		applications => {
			cms => {
				methods => {
					'edit_privacy' => sub { runner('edit_privacy', 'Privacy::App::CMS', @_); }
				}
			}
		}
		# callbacks => {
		# 	'MT::Entry::post_insert' => sub { MT->log('Hello'); }
		# }
	};
	
	# No need to add Privacy::Group if MT::Group exists
	unless (MT->registry('object_types', 'group')) {
		$r->{object_types}->{'privacy_group'} = 'Privacy::Group';
	}
	
	$plugin->registry($r);
}

sub runner {
    my $method = shift;
	my $class = shift;
    eval "require $class;";
    if ($@) { die $@; $@ = undef; return 1; }
    my $method_ref = $class->can($method);
    return $method_ref->($plugin, @_) if $method_ref;
    die $plugin->translate("Failed to find [_1]::[_2]", $class, $method);
}