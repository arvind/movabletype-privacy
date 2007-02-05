# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.

package MT::Plugin::Privacy;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.2 or later

use base 'MT::Plugin';
our $VERSION = '2.0b4';
our $SCHEMA_VERSION = '2.1';

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
            version_limit => 2.1,
            code => sub { runner('app', 'convert_data', @_);  },
        },
		'load_files' => {
			version_limit => $SCHEMA_VERSION, 
			code => sub { runner('app', 'load_files', @_); },
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
		'MT::App::CMS::AppTemplateSource.edit_entry' => sub { runner('app', '_edit_entry', @_); },
		'MT::App::CMS::AppTemplateParam.edit_entry'  => sub { runner('app', '_param', @_, 'entry'); },
		'MT::App::CMS::AppTemplateSource.entry_prefs' => sub { runner('app', '_entry_prefs', @_); },
		'MT::Entry::post_save' => sub { runner('app', 'post_save', @_); },
		'MT::App::CMS::AppTemplateSource.edit_category' => sub { runner('app', '_edit_category', @_); },
		'MT::App::CMS::AppTemplateParam.edit_category' => sub { runner('app', '_param', @_, 'category'); },
		'MT::Category::post_save' => sub { runner('app', 'post_save', @_); },
		'MT::App::CMS::AppTemplateSource.entry_table' => sub { runner('app', '_list_entry', @_); },
		'MT::App::CMS::AppTemplateParam.list_entry' => sub { runner('app', '_list_param', @_, 'entry'); },
		'MT::App::CMS::AppTemplateSource.edit_categories' => sub { runner('app', '_edit_categories', @_); },
		'MT::App::CMS::AppTemplateParam.edit_categories' => sub { runner('app', '_list_param', @_, 'category'); },		
		'MT::App::CMS::AppTemplateSource.system_list_blog' => sub { runner('app', '_system_list_blog', @_); },
		'MT::App::CMS::AppTemplateParam.system_list_blog' => sub { runner('app', '_list_param', @_, 'blog'); },
		'Privacy::App::CMS::AppTemplateParam.edit_blog' => sub { runner('app', '_param', @_, 'blog'); },
		'Privacy::App::CMS::AppTemplateParam.edit_group' => sub { runner('app', '_param', @_, 'protect_groups'); },		
		'*::AppTemplateSource'  => sub { runner('app', '_header', @_); },
		'DefaultTemplateFilter'  => sub { runner('app', 'load_files', @_); }
	},
	container_tags => {
		'PrivateBlog' => sub { runner('template', 'private', 'blog', @_);},
		'PrivateEntry' => sub { runner('template', 'private', 'entry', @_);},		
		'PrivateCategory' => sub { runner('template', 'private', 'category', @_);},		
		'PrivacyTypes' => sub { runner('template', 'privacy_types', @_);},			
		'PrivacyTypeFields' => sub { runner('template', 'privacy_type_fields', @_);}					
	},
	template_tags => {
		'PrivateObjectID' => sub { runner('template', 'private_obj_id', @_);},
		'PrivateObjectType' => sub { runner('template', 'private_obj_type', @_);},
		'PrivacyTypeName' => sub { runner('template', 'privacy_type_name', @_);},
		'PrivacyTypeFieldName' =>  sub { runner('template', 'privacy_type_field_name', @_);},
		'PrivacyTypeFieldType' =>  sub { runner('template', 'privacy_type_field_type', @_);},		
	},
	settings => new MT::PluginSettings([
	            ['use_php', { Default => 1 }]
	]),
	config_template => \&config_template
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
		for my $type (@{$plugin->{privacy_types}}) {
		  my $key = "show_".$type->{key};
		  next if exists($data->{$key});
		    # don't load system settings unless we need to
		  $sys ||= $plugin->get_config_obj('system')->data;
		  $data->{$key} = $sys->{$key};
		}
	}
}

sub add_privacy_type {
    my $privacy = shift;
    my ($privacy_type) = @_;

    Carp::croak 'privacy types require a string called "key"' 
        unless ($privacy_type->{key}
                && !(ref($privacy_type->{key})));
    Carp::croak 'privacy types require a coderef called "signon_code"'
        unless ($privacy_type->{signon_code} && 
                (ref $privacy_type->{signon_code} eq 'CODE'));
    Carp::croak 'privacy types require a string called "label"'
        unless ($privacy_type->{label} && 
                !(ref $privacy_type->{label}));

    $privacy_type->{orig_label} = $privacy_type->{label};
    $privacy_type->{plugin} = $MT::plugin_sig if $MT::plugin_sig && !$is_core;
    push @{$plugin->{privacy_types}}, $privacy_type;
}

sub config_template {
    my $plugin = shift;
    my ($param, $scope) = @_;
	my @auth_loop;
	foreach my $type (@{$plugin->{privacy_types}}) {
		my $row = $type;
		my $key = $type->{key};
		$row->{show} = $plugin->get_config_value("show_$key", $scope);
		$row->{single} = ($type->{type} eq 'single') ? 1 : 0;
		push @auth_loop, $row;
	}
	$param->{auth_loop} = \@auth_loop;
	return $plugin->load_tmpl('config.tmpl');
}

sub save_config {
    my $plugin = shift;
    my ($param, $scope) = @_;
    my $pdata = $plugin->get_config_obj($scope);
    $scope =~ s/:.*//;
	my $data = $pdata->data() || {};
	foreach my $type (@{$plugin->{privacy_types}}) {
		my $key = "show_".$type->{key};
		$data->{$key} = exists $param->{$key} ? $param->{$key} : undef;
	}
	my @vars = $plugin->config_vars($scope);
    foreach (@vars) {
        $data->{$_} = exists $param->{$_} ? $param->{$_} : undef;
    }
    $pdata->data($data);
    $pdata->save() or die $pdata->errstr;
}

sub runner {
    my $class = shift;
	my $method = shift;
	if($class eq 'app') {
		$class = 'Privacy::App';
	} elsif($class eq 'template') {
		$class = 'Privacy::Template::ContextHandlers';
	}
    eval "require $class;";
    if ($@) { die $@; $@ = undef; return 1; }
    my $method_ref = $class->can($method);
    return $method_ref->($plugin, @_) if $method_ref;
    die $plugin->translate("Failed to find [_1]::[_2]", $class, $method);
}

1;
