# Protect - A plugin for Movable Type.
# Copyright (c) 2006, Arvind.

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
            version_limit => 2.0,   # runs for schema_version < 2.0
            code => \&convert_data
        },
		'mt_protect_php_file' => {
			version_limit => 2.0, 
			code => \&php_file
		}
    },
	l10n_class 	    => 'Protect::L10N',
    app_action_links => {
        'MT::App::CMS' => {
#            'list_entries' => {
#                link => 'mt-protect.cgi?__mode=list_entries',
#                link_text => 'List Protected Entries'
#            },
            # 'list_commenters' => {
            #     link => 'mt-protect.cgi?__mode=tk_groups',
            #     link_text => 'List Protection Groups'
            # },
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
			# 'entry' => {
			#                 key => "set_protection",
			#                 label => "Protect Entries",
			#                 code => sub { $plugin->protect_entries(@_) },
			# 	condition => sub { my $app = MT->instance; $app->mode eq 'list_entries' }				
			# },
			# 'blog' => {
			#                 key => "set_protection",
			#                 label => "Protect Blog(s)",
			#                 code => sub { $plugin->protect_blogs(@_) }				
			# }
		}
	},
	callbacks => {
		'MT::App::CMS::AppTemplateSource.edit_entry' => sub { require Protect::Transformer; Protect::Transformer::_edit_entry(@_); },
		'MT::App::CMS::AppTemplateParam.edit_entry'  => sub { require Protect::Transformer; Protect::Transformer::_param(@_, 'entry'); },
		'MT::Entry::post_save' => sub { require Protect::Transformer; Protect::Transformer::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.edit_category' => sub { require Protect::Transformer; Protect::Transformer::_edit_category(@_); },
		'MT::App::CMS::AppTemplateParam.edit_category' => sub { require Protect::Transformer; Protect::Transformer::_param(@_, 'category'); },
		'MT::Category::post_save' => sub { require Protect::Transformer; Protect::Transformer::post_save(@_); },
		'MT::App::CMS::AppTemplateSource.entry_table' => sub { require Protect::Transformer; Protect::Transformer::_list_entry(@_); },
		'MT::App::CMS::AppTemplateParam.list_entry' => sub { require Protect::Transformer; Protect::Transformer::_list_entry_param(@_); },
		'Protect::CMS::AppTemplateParam.edit' => sub { require Protect::Transformer; Protect::Transformer::_param(@_, 'blog'); },
		'*::AppTemplateSource'  => sub { require Protect::Transformer; Protect::Transformer::_header(@_); }
	},
	container_tags => {
		# 'EntryProtect'	=> \&protected,
		# 'BlogProtect'	=> \&blog_protected,
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

sub init {
	my $plugin = shift;
	$plugin->SUPER::init(@_);
	MT->config->PluginSchemaVersion({})
	unless MT->config->PluginSchemaVersion;
}

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

sub convert_data {
	require Protect::Protect;
	require Protect::Object;
	require Protect::Groups;
	my $objs_iter = Protect::Protect->load_iter();
	while (my $orig_obj = $objs_iter->()) {
		my $obj = Protect::Object->new;
		$obj->blog_id($orig_obj->blog_id);
		$obj->object_id($orig_obj->entry_id);
		$obj->object_datasource('entry');
		if(!$orig_obj->entry_id) {
			$obj->object_datasource('blog');
			$obj->object_id($orig_obj->blog_id);
		}
		if($orig_obj->type eq 'Password') {
			$obj->password($orig_obj->data);
		} else {
			my $users = $orig_obj->data;
			$users = join ',', @$users;
			if($orig_obj->type eq 'Typekey') {
				$obj->typekey_users($users);
			} elsif($orig_obj->type eq 'OpenID') {
				$obj->openid_users($users);
			}
		}
		$obj->save or die $obj->errstr;
		$orig_obj->remove or die $orig_obj->errstr;
	}
	
	my $groups_iter = Protect::Groups->load_iter();
	while (my $group = $groups_iter->()) {
		my $users = $group->data;
		$users = join ',', @$users;		
		if($group->type eq 'Typekey') {
			$group->typekey_users($users);
		} elsif($group->type eq 'OpenID') {
			$group->openid_users($users);
		}
		$group->type('');
		$group->save or die $group->errstr;
	}
}

sub php_file {
    require MT::FileMgr;
	require MT::Template; 
	require MT::WeblogPublisher;
    my $filemgr = MT::FileMgr->new('Local')
        or return $app->error(MT::FileMgr->errstr);
	my $pub = MT::WeblogPublisher->new;
	
    my $mt_protect_php = $filemgr->get_data(File::Spec->catfile($plugin->{full_path},"mt-protect.php"))
		or die $plugin->translate("Unable to get mt-password.php from plugin folder. File Manager gave the error: [_1].", $filemgr->errstr);

	require MT::Blog;
	my $iter = MT::Blog->load_iter;
	while (my $blog = $iter->()) {
		my $tmpl = MT::Template->load({ name => 'MT Protect Bootstrapper' });
		if(!$tmpl) {
			$tmpl = MT::Template->new;
			$tmpl->set_values({
				blog_id => $blog->id,
				name => 'MT Protect Bootstrapper',
				type => 'index',
				outfile => 'mt-protect.php',
				rebuild_me => 0
			});			
		}
		$tmpl->text($mt_protect_php);
		$tmpl->save or die $tmpl->errstr;
		$pub->rebuild_indexes(Blog => $blog, Template => $tmpl, Force => 1)
			or die $pub->errstr;
	}
}

1;
