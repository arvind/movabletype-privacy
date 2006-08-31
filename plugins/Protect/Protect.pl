# Protect - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.

package MT::Plugin::Protect;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.2 or later

use base 'MT::Plugin';
our $VERSION = '2.0';
our $SCHEMA_VERSION = '2.0';

my $plugin;
MT->add_plugin($plugin = __PACKAGE__->new({
	name            => "MT Protect",
	version         => $VERSION,
	description     => "<MT_TRANS phrase=\"Protect entries and blogs using passwords, typekey or openid authentication.\">",
	author_name     => "Arvind Satyanarayan",
	author_link     => "http://www.movalog.com/",
	plugin_link     => "http://plugins.movalog.com/protect/",
	doc_link        => "http://plugins.movalog.com/protect/manual",
	schema_version  => $SCHEMA_VERSION,
	object_classes  => [ 'Protect::Groups', 'Protect::Object' ],
	upgrade_functions => {
        'convert_data' => {
            version_limit => 2.0,
            code => sub { require Protect::App; Protect::App::convert_data(@_); },
        },
		'mt_protect_php_file' => {
			version_limit => 2.0, 
			code => sub { require Protect::App; Protect::App::load_php_file(@_); },
		}
    },
	l10n_class 	    => 'Protect::L10N',
    app_action_links => {
        'MT::App::CMS' => {
            'blog' => {
                link => 'mt-protect.cgi?__mode=edit',
                link_text => 'Protect Blog'
            }
        }
    },
	app_itemset_actions => {
		'MT::App::CMS' => {
			'commenter' => {
				key => "set_protection_group",
				label => "Create a Protection Group",
				code => sub {
					my $app = shift;
					$app->redirect($app->path . 'plugins/Protect/mt-protect.cgi?__mode=edit&_type=groups&author_id='. join ',', $app->param('id'));
				}				
			},
		}
	},
	callbacks => {
		'MT::App::CMS::AppTemplateSource.edit_entry' => sub { require Protect::App; Protect::App::_edit_entry(@_); },
		'MT::App::CMS::AppTemplateParam.edit_entry'  => sub { require Protect::App; Protect::App::_param(@_, 'entry'); },
		'MT::Entry::post_save' => sub { require Protect::App; Protect::App::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.edit_category' => sub { require Protect::App; Protect::App::_edit_category(@_); },
		'MT::App::CMS::AppTemplateParam.edit_category' => sub { require Protect::App; Protect::App::_param(@_, 'category'); },
		'MT::Category::post_save' => sub { require Protect::App; Protect::App::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.entry_table' => sub { require Protect::App; Protect::App::_list_entry(@_); },
		'MT::App::CMS::AppTemplateParam.list_entry' => sub { require Protect::App; Protect::App::_list_param(@_, 'entry'); },
		'MT::App::CMS::AppTemplateSource.edit_categories' => sub { require Protect::App; Protect::App::_edit_categories(@_); },
		'MT::App::CMS::AppTemplateParam.edit_categories' => sub { require Protect::App; Protect::App::_list_param(@_, 'category'); },		
		'MT::App::CMS::AppTemplateSource.system_list_blog' => sub { require Protect::App; Protect::App::_system_list_blog(@_); },
		'MT::App::CMS::AppTemplateParam.system_list_blog' => sub { require Protect::App; Protect::App::_list_param(@_, 'blog'); },
		'Protect::CMS::AppTemplateParam.protect_blog' => sub { require Protect::App; Protect::App::_param(@_, 'blog'); },
		'*::AppTemplateSource'  => sub { require Protect::App; Protect::App::_header(@_); },
		'DefaultTemplateFilter'  => sub { require Protect::App; Protect::App::default_template_filter(@_); }
	},
	container_tags => {
		'BlogProtect'		=> sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect('blog', @_);},
		'EntryProtect'		=> sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect('entry', @_);},		
		'CategoryProtect'		=> sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect('category', @_);},		
	},
	template_tags => {
		'ProtectObjectID' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect_obj_id(@_);},
		'ProtectObjectType' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::protect_obj_type(@_);}
	},
	conditional_tags => {
		'IfPasswordProtected' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::is_password(@_);},
		'IfTypekeyProtected' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::is_typekey(@_);},		
		'IfLiveJournalProtected' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::is_livejournal(@_);},		
		'IfOpenIDProtected' => sub { require Protect::Template::ContextHandlers; Protect::Template::ContextHandlers::is_openid(@_);}
	},
    settings => new MT::PluginSettings([
		['show_password', { Default => 1 }],
		['show_third_party', { Default => 0 }],
		['show_typekey', { Default => 0 }],
		['show_livejournal', { Default => 0 }],
		['show_openid', { Default => 0 }],
        ['protect_text', { Default => q{<MTIgnore>
#### Javascript to toggle the display of the various protection types
</MTIgnore>
<script type="text/javascript">
<!--
	function toggleProtect(type, id) {
		var types = new Array('password', 'typekey', 'livejournal', 'openid');
		for (var i = 0; i < types.length; i++) {
			var el = document.getElementById(types[i] + '-' + id + '-protect');
			if(el) el.style.display = 'none';
		}
		var el = document.getElementById(type + '-' + id + '-protect');
		if(el) el.style.display = 'block';
	}
//-->
</script>
<p>This is a private <MTProtectObjectType>. To view it, please choose one of the options below and follow the steps.</p>
<p>
	<MTIfPasswordProtected>
		<a href="#" onclick="toggleProtect('password', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-password.gif" alt="Enter Password" /></a>
	</MTIfPasswordProtected>
	
	<MTIfTypekeyProtected>
		<a href="#" onclick="toggleProtect('typekey', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-typekey.gif" alt="Login via Typekey" /></a>
	</MTIfTypekeyProtected>
	
	<MTIfLiveJournalProtected>
		<a href="#" onclick="toggleProtect('livejournal', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-livejournal.gif" alt="Login via LiveJournal" /></a>
	</MTIfLiveJournalProtected>
	
	<MTIfOpenIDProtected>
		<a href="#" onclick="toggleProtect('openid', '<MTProtectObjectID>');"><img src="<MTStaticWebPath>plugins/Protect/images/button-openid.gif" alt="Login via OpenID" /></a>
	</MTIfOpenIDProtected>
</p>

<form action="<MTCGIPath>plugins/Protect/signon.cgi" method="post" id="password-protect">
	<input type="hidden" name="__mode" value="verify" />
	<input type="hidden" name="blog_id" value="<MTBlogID>" />
	<input type="hidden" name="id" value="<MTProtectObjectID>" />
	<input type="hidden" name="_type" value="<MTProtectObjectType>" />
	
	<MTIfPasswordProtected>
		<div id="password-<MTProtectObjectID>-protect" style="display:none;">
			<p>Enter the password below to view this <MTProtectObjectType>:</p>
			<p>
				<label>Password: <input type="text" name="password" value="" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfPasswordProtected>
	
	<MTIfTypekeyProtected>
		<div id="typekey-<MTProtectObjectID>-protect" style="display:none;">
			<p>Enter your Typekey username below to view this <MTProtectObjectType>:</p>
			<p>
				<label>Typekey Username: <input type="text" name="tk_user" value="" style="background: white url(<MTStaticWebPath>plugins/Protect/images/input-typekey.gif) no-repeat; padding-left: 22px;" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfTypekeyProtected>
	
	<MTIfLiveJournalProtected>
		<div id="livejournal-<MTProtectObjectID>-protect" style="display:none;">
			<p>Enter your LiveJournal username below to view this <MTProtectObjectType>:</p>
			<p>
				<label>LiveJournal Username: <input type="text" name="lj_user" value="" style="background: white url(<MTStaticWebPath>plugins/Protect/images/input-livejournal.gif) no-repeat; padding-left: 22px;" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfLiveJournalProtected>	
	
	<MTIfOpenIDProtected>
		<div id="openid-<MTProtectObjectID>-protect" style="display:none;">
			<p>Enter your OpenID URL below to view this <MTProtectObjectType>:</p>
			<p>
				<label>OpenID Username: <input type="text" name="openid_url" value="" style="background: white url(<MTStaticWebPath>plugins/Protect/images/input-openid.gif) no-repeat; padding-left: 22px;" /></label> 
				<input type="submit" name="submit" value="Submit" id="submit" />
			</p>
		</div>
	</MTIfOpenIDProtected>	
	
</form>
} }]
    ]),
	config_template => 'config.tmpl'
}));

# Allows external access to plugin object: MT::Plugin::Protect->instance
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
