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
	description     => "<__trans phrase=\"Make entries, category and blogs private using passwords or third party authentication\">",
	author_name     => "Arvind Satyanarayan",
	author_link     => "http://www.movalog.com/",
	plugin_link     => "http://plugins.movalog.com/privacy/",
	doc_link        => "http://plugins.movalog.com/privacy/manual",
	schema_version  => $SCHEMA_VERSION,
	settings => new MT::PluginSettings([
	            ['use_php', { Default => 1 }],
				['signin', { Default => q{This is a private <MTPrivateObjectType>. Please <a href="<MTPrivacySignInLink>">sign in</a>}}],
				['signout', { Default => q{Thank you for signing in (<a href="<MTPrivacySignOutLink>">sign out</a>)} }],
				['no_perms', { Default => q{Sorry, you do not have permission to view this <MTPrivateObjectType>. Please contact the author for more information}}]
	]),
	config_template => 'config.tmpl'
}));

# Allows external access to plugin object: MT::Plugin::Privacy->instance
sub instance { $plugin; }

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

sub init_registry {
	my $plugin = shift;
	my $r = {
		object_types => {
			'privacy_object' => 'Privacy::Object'
		}, 
		tags => {
			block => {
				'PrivateBlog' => sub { runner('_hdlr_private', 'Privacy::Template::ContextHandlers', @_); },
				'PrivateEntry' => sub { runner('_hdlr_private', 'Privacy::Template::ContextHandlers', @_); },
				'PrivateCategory' => sub { runner('_hdlr_private', 'Privacy::Template::ContextHandlers', @_); }
			},
			function => {
				'App:Privacy' => sub { runner('_hdlr_app_privacy', 'Privacy::Template::ContextHandlers', @_); },
				'PrivateObjectType' => sub { runner('_hdlr_private_object_type', 'Privacy::Template::ContextHandlers', @_); },
				'PrivacySignInLink' => sub { runner('_hdlr_privacy_signin_link', 'Privacy::Template::ContextHandlers', @_); },
				'PrivacySignOutLink' => sub { runner('_hdlr_privacy_signout_link', 'Privacy::Template::ContextHandlers', @_); },
			}
		},
		applications => {
			cms => {
				methods => {
					'edit_privacy' => sub { runner('edit_privacy', 'Privacy::App::CMS', @_); }
				}
			}
		},
		callbacks => {
			'MT::Entry::post_insert' => \&post_insert,
			'cms_post_save.entry' => sub { runner('cms_post_save', 'Privacy::App::CMS', @_); },
			'cms_post_save.category' => sub { runner('cms_post_save', 'Privacy::App::CMS', @_); },
			'cms_post_save.blog' => sub { runner('cms_post_save', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_source.edit_entry' => sub { runner('edit_entry_src', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_param.edit_entry' => sub { runner('edit_entry_param', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_param.edit_category' => sub { runner('edit_category_param', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_param.cfg_prefs'  => sub { runner('cfg_prefs_param', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_param.list_entry' => sub { runner('list_objects_param', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_source.entry_table' =>  sub { runner('list_objects_src', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_param.list_category' => sub { runner('list_objects_param', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_source.list_category' =>  sub { runner('list_objects_src', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_param.list_blog' => sub { runner('list_objects_param', 'Privacy::App::CMS', @_); },
			'MT::App::CMS::template_source.blog_table' =>  sub { runner('list_objects_src', 'Privacy::App::CMS', @_); },
			# 'MT::App::CMS::template_source.users_content_nav' => sub { runner('users_content_nav_src', 'Privacy::App::CMS', @_); }
		},
		default_templates => {
			index => {
				privacy_bootstrapper => {
					label => 'Privacy Bootstrapper',
					outfile => 'privacy.php',
					rebuild_me => 1,
					text => q{<?php
	include('<$MTCGIServerPath$>/php/mt.php');
	$mt = new MT(<$MTBlogID$>, '<$MTConfigFile$>');
	$db =& $mt->db;
	$config = $db->fetch_plugin_config('Privacy');
	if($_REQUEST['rand'] == $config['rand'])  {
		setcookie($_REQUEST['obj_type'].$_REQUEST['id'], 1, '', '/');
	}

	$config['rand'] = md5(time().mt_rand());	

	require_once("MTSerialize.php");
    $serializer = new MTSerialize();
	$data = $db->escape($serializer->serialize($config));	

	$db->query("update mt_plugindata set plugindata_data = '$data' where plugindata_plugin = 'Privacy' and plugindata_key = 'configuration'");
	header('Location: '. $_REQUEST['redirect']);
?>}
				}
			}
		}
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

# This populates the default privacy settings. It is only triggered for *new* objects
sub post_insert {
	my ($cb, $obj, $orig) = @_;
	
	require Privacy::Object;
	my $iter = Privacy::Object->load_iter({ blog_id => $obj->blog_id, object_id => $obj->blog_id, object_datasource => 'blog' });
	while (my $p = $iter->()) {
		my $privacy = $p->clone;
		$privacy->set_values({
			id => 0,
			object_id => $obj->id,
			object_datasource => $obj->datasource
		});
		$privacy->save or die $privacy->errstr;
	}
	1;
}

1;