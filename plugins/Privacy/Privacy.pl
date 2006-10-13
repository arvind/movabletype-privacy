# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.

package MT::Plugin::Privacy;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.2 or later

use base 'MT::Plugin';
our $VERSION = '2.0';
our $SCHEMA_VERSION = '2.0';

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
	object_classes  => [ 'Privacy::Groups', 'Privacy::Object' ],
	upgrade_functions => {
        'convert_data' => {
            version_limit => 2.0,
            code => sub { require Privacy::App; Privacy::App::convert_data(@_); },
        },
		'load_files' => {
			version_limit => 2.0, 
			code => sub { require Privacy::App; Privacy::App::load_files(@_); },
		}
    },
	l10n_class 	    => 'Privacy::L10N',
    app_action_links => {
        'MT::App::CMS' => {
            'blog' => {
                link => 'privacy.cgi?__mode=edit',
                link_text => 'Blog Privacy Settings'
            }
        }
    },
	app_itemset_actions => {
		'MT::App::CMS' => {
			'commenter' => {
				key => "set_protection_group",
				label => "Create a Privacy Group",
				code => sub {
					my $app = shift;
					$app->redirect($app->path . 'plugins/Privacy/privacy.cgi?__mode=edit&_type=groups&author_id='. join ',', $app->param('id'));
				}				
			},
		}
	},
	callbacks => {
		'MT::App::CMS::AppTemplateSource.edit_entry' => sub { require Privacy::App; Privacy::App::_edit_entry(@_); },
		'MT::App::CMS::AppTemplateParam.edit_entry'  => sub { require Privacy::App; Privacy::App::_param(@_, 'entry'); },
		'MT::App::CMS::AppTemplateSource.entry_prefs' => sub { require Privacy::App; Privacy::App::_entry_prefs(@_); },
		'MT::Entry::post_save' => sub { require Privacy::App; Privacy::App::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.edit_category' => sub { require Privacy::App; Privacy::App::_edit_category(@_); },
		'MT::App::CMS::AppTemplateParam.edit_category' => sub { require Privacy::App; Privacy::App::_param(@_, 'category'); },
		'MT::Category::post_save' => sub { require Privacy::App; Privacy::App::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.entry_table' => sub { require Privacy::App; Privacy::App::_list_entry(@_); },
		'MT::App::CMS::AppTemplateParam.list_entry' => sub { require Privacy::App; Privacy::App::_list_param(@_, 'entry'); },
		'MT::App::CMS::AppTemplateSource.edit_categories' => sub { require Privacy::App; Privacy::App::_edit_categories(@_); },
		'MT::App::CMS::AppTemplateParam.edit_categories' => sub { require Privacy::App; Privacy::App::_list_param(@_, 'category'); },		
		'MT::App::CMS::AppTemplateSource.system_list_blog' => sub { require Privacy::App; Privacy::App::_system_list_blog(@_); },
		'MT::App::CMS::AppTemplateParam.system_list_blog' => sub { require Privacy::App; Privacy::App::_list_param(@_, 'blog'); },
		'Privacy::CMS::AppTemplateParam.protect_blog' => sub { require Privacy::App; Privacy::App::_param(@_, 'blog'); },
		'*::AppTemplateSource'  => sub { require Privacy::App; Privacy::App::_header(@_); },
		'DefaultTemplateFilter'  => sub { require Privacy::App; Privacy::App::load_files(@_); }
	},
	container_tags => {
		'PrivateBlog'		=> sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::protect('blog', @_);},
		'PrivateEntry'		=> sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::protect('entry', @_);},		
		'PrivateCategory'		=> sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::protect('category', @_);},		
	},
	template_tags => {
		'PrivateObjectID' => sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::protect_obj_id(@_);},
		'PrivateObjectType' => sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::protect_obj_type(@_);}
	},
	conditional_tags => {
		'IfPasswordProtected' => sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::is_password(@_);},
		'IfTypekeyProtected' => sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::is_typekey(@_);},		
		'IfLiveJournalProtected' => sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::is_livejournal(@_);},		
		'IfOpenIDProtected' => sub { require Privacy::Template::ContextHandlers; Privacy::Template::ContextHandlers::is_openid(@_);}
	},
    settings => new MT::PluginSettings([
		['show_password', { Default => 1 }],
		['show_third_party', { Default => 0 }],
		['show_typekey', { Default => 0 }],
		['show_livejournal', { Default => 0 }],
		['show_openid', { Default => 0 }]
    ]),
	config_template => 'config.tmpl'
}));

# Allows external access to plugin object: MT::Plugin::Privacy->instance
sub instance {
	$plugin;
}

sub version {
	$VERSION;
}

# Corrects bug in MT 3.31/2 <http://groups.yahoo.com/group/mt-dev/message/962>
sub init {
	my $plugin = shift;
	$plugin->SUPER::init(@_);
	MT->config->PluginSchemaVersion({})
	unless MT->config->PluginSchemaVersion;
}

# Populates values for system templates
sub init_request {
    my $plugin = shift;
    my ($app) = @_;
	$plugin->SUPER::init_request(@_);
	$MT::L10N::en_us::Lexicon{_SYSTEM_TEMPLATE_PRIVACY_LOGIN} = 'Shown when an asset is private';
	$MT::L10N::en_us::Lexicon{_SYSTEM_TEMPLATE_PRIVACY_BARRED} = 'Shown when a reader logs in to view a private asset but is not explicitly allowed';
}

# Blog settings default to system settings (hence blog settings override system)
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

1;
