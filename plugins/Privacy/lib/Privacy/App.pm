package Privacy::App;

use MT::Util qw( start_background_task dirify );

my $templates = [
          {
            'outfile' => 'privacy.php',
            'name' => 'Privacy: Bootstrapper',
            'type' => 'index',
            'rebuild_me' => '1'
          },
          {
            'name' => 'Privacy: Login',
            'type' => 'privacy_login',
          },
          {
            'name' => 'Privacy: Not Allowed',
            'type' => 'privacy_barred',
          },
        ];

sub config {
    my $config = {};
	my $plugin = MT::Plugin::Privacy->instance;
    if ($plugin) {
        require MT::Request;
        my ($scope) = (@_);
        $config = MT::Request->instance->cache('protect_config_'.$scope);
        if (!$config) {
            $config = $plugin->get_config_hash($scope);
            MT::Request->instance->cache('protect_config_'.$scope, $config);
        }
    }
    $config;
}

sub convert_data {
	my $plugin = MT::Plugin::Privacy->instance;
	
	require Privacy::Protect;
	require Privacy::Object;
	require Privacy::Groups;
	my $objs_iter = Privacy::Protect->load_iter();
	while (my $orig_obj = $objs_iter->()) {
		my $obj = Privacy::Object->new;
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
	
	my $groups_iter = Privacy::Groups->load_iter();
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

sub load_files {
	my ($eh, $tmpls) = @_;
	my $plugin = MT::Plugin::Privacy->instance;
	local (*FIN, $/);
    $/ = undef;
    foreach my $tmpl (@$templates) {
        my $file = File::Spec->catfile($plugin->{full_path}, 'tmpl', 'default_templates', dirify($tmpl->{name}).'.tmpl');
        if ((-e $file) && (-r $file)) {
            open FIN, "<$file"; my $data = <FIN>; close FIN;
            $tmpl->{text} = $data;
        } else {
            die $plugin->translate("Couldn't find file '[_1]'", $file);
        }
		if(@$tmpls) {
			push @$tmpls, $tmpl;
		}
    }
	
	if(!@$tmpls) {
		require MT::Blog;
		require MT::Template;
		my $iter = MT::Blog->load_iter;		
		while (my $blog = $iter->()) {
		    for my $val (@$templates) {
		        $val->{name} = $plugin->translate($val->{name});
		        $val->{text} = $plugin->translate_templatized($val->{text});
		        my $tmpl = MT::Template->new;
		        $tmpl->set_values($val);
		        $tmpl->build_dynamic(0);
		        $tmpl->blog_id($blog->id);
		        $tmpl->save or
		            return $app->error($plugin->translate(
		                "Populating blog with template '[_1]' failed: [_2]", $val->{name},
		                $tmpl->errstr));
		    }			
		}
	}
		
}

sub _edit_entry {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $plugin = MT::Plugin::Privacy->instance;
	my $edit_tmpl_path = File::Spec->catdir($plugin->{full_path},'tmpl','protect.tmpl');
	
	$old = <<HTML;
<TMPL_IF NAME=DISP_PREFS_SHOW_TAGS>
<div class="field" id="tag-field">
<div class="field-header">
<label for="tags"><MT_TRANS phrase="Tags"></label>
<a href="#" onclick="return openManual('entries', 'entry_tags')" class="help">?</a> <span class="hint"><TMPL_IF NAME=AUTH_PREF_TAG_DELIM_COMMA><MT_TRANS phrase="(comma-delimited list)"><TMPL_ELSE><TMPL_IF NAME=AUTH_PREF_TAG_DELIM_SPACE><MT_TRANS phrase="(space-delimited list)"><TMPL_ELSE><MT_TRANS phrase="(delimited by '[_1]')" params="<TMPL_VAR NAME=AUTH_PREF_TAG_DELIM>"></TMPL_IF></TMPL_IF></span>
</div>
<div class="textarea-wrapper">
<input name="tags" id="tags" tabindex="7" value="<TMPL_VAR NAME=TAGS ESCAPE=HTML>" onchange="setDirty()" />
</div>
<!--[if lte IE 6.5]><div id="iehack"><![endif]-->
<div id="tags_completion" class="full-width"></div>
<!--[if lte IE 6.5]></div><![endif]-->
</div>
</TMPL_IF>

HTML
	$old = quotemeta($old);
	$new = <<HTML;

<div class="field" id="protect">
<div class="field-header">
<label for="text_more"><MT_TRANS phrase="Make Entry Private"></label>
</div>
<div class="field-wrapper">

<TMPL_INCLUDE NAME="$edit_tmpl_path">

</div>
</div>

HTML
	$$tmpl =~ s/($old)/$1\n$new\n/;
}

sub _edit_category {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $plugin = MT::Plugin::Privacy->instance;
	my $edit_tmpl_path = File::Spec->catdir($plugin->{full_path},'tmpl','protect.tmpl');
	
	$old = <<HTML;
<p><label for="description"><MT_TRANS phrase="Description"></label> <a href="#" onclick="return openManual('categories', 'category_description')" class="help">?</a><br />
<textarea name="description" id="description" rows="5" cols="72" class="wide"><TMPL_VAR NAME=DESCRIPTION ESCAPE=HTML></textarea></p>
HTML
	$old = quotemeta($old);
	$new = <<HTML;
<TMPL_INCLUDE NAME="$edit_tmpl_path">
<br clear="all" />
HTML
	$$tmpl =~ s/($old)/$1\n$new\n/;
	
	$old = qq{<input accesskey="s" type="submit" value="<MT_TRANS phrase="Save">" title="<MT_TRANS phrase="Save this category (s)">" />};
	$old = quotemeta($old);
	$new = qq{<input accesskey="s" type="submit" value="<MT_TRANS phrase="Save">" title="<MT_TRANS phrase="Save this category (s)">" onclick="submitForm(this.form)" />};
	$$tmpl =~ s/$old/$new/;
}

sub _edit_categories {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $plugin = MT::Plugin::Privacy->instance;

	$old = qq{<TMPL_VAR NAME=CATEGORY_LABEL></a>};
	$old = quotemeta($old);
	$new = qq{<TMPL_IF NAME=PROTECTED>&nbsp;&nbsp;<a href="<TMPL_VAR NAME=SCRIPT_URL>?__mode=view&amp;_type=category&amp;blog_id=<TMPL_VAR NAME=BLOG_ID>&amp;id=<TMPL_VAR NAME=CATEGORY_ID>#protect"><img src="<TMPL_VAR NAME=STATIC_URI>plugins/Privacy/images/protected.gif" alt="<MT_TRANS phrase="Private Category">"  /></TMPL_IF>};
	$$tmpl =~ s/($old)/$1\n$new\n/;	
}

sub _list_entry {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $plugin = MT::Plugin::Privacy->instance;

	$old = qq{<TMPL_VAR NAME=TITLE_LONG>};
	$old = quotemeta($old);
	$new = qq{<TMPL_UNLESS NAME=IS_POWER_EDIT><TMPL_IF NAME=PROTECTED><img src="<TMPL_VAR NAME=STATIC_URI>plugins/Privacy/images/protected.gif" alt="<MT_TRANS phrase="Entry Protected">"  /></a><TMPL_ELSE>&nbsp;</TMPL_IF></TMPL_UNLESS>};
	$$tmpl =~ s/($old)/$1\n$new\n/;	
	
	$old = qq{<TMPL_VAR NAME=TITLE_SHORT>};
	$old = quotemeta($old);
	$new = qq{<TMPL_UNLESS NAME=IS_POWER_EDIT><TMPL_IF NAME=PROTECTED></a>&nbsp;&nbsp;<a href="<TMPL_VAR NAME=SCRIPT_URL>?__mode=view&amp;_type=entry&amp;id=<TMPL_VAR NAME=ID>&amp;blog_id=<TMPL_VAR NAME=BLOG_ID>#protect"><img src="<TMPL_VAR NAME=STATIC_URI>plugins/Privacy/images/protected.gif" alt="<MT_TRANS phrase="Private Entry">"  /><TMPL_ELSE>&nbsp;</TMPL_IF></TMPL_UNLESS>};
	$$tmpl =~ s/($old)/$1\n$new\n/;	
}

sub _system_list_blog {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $plugin = MT::Plugin::Privacy->instance;
	my $link = $app->base.$app->path.$plugin->envelope.'/privacy.cgi';
	
	$old = qq{<TMPL_VAR NAME=NAME ESCAPE=HTML></a>};
	$old = quotemeta($old);
	$new = qq{<TMPL_IF NAME=PROTECTED></a>&nbsp;&nbsp;<a href="$link?__mode=edit&amp;_type=blog&blog_id=<TMPL_VAR NAME=ID>#protect"><img src="<TMPL_VAR NAME=STATIC_URI>plugins/Privacy/images/protected.gif" alt="<MT_TRANS phrase="Private Blog">"  /></TMPL_IF>};
	$$tmpl =~ s/($old)/$1\n$new\n/;	
}

sub _list_param {
	my($eh, $app, $param, $tmpl, $type) = @_;
	my $objs;
	if($type eq 'entry') {
		$objs = $param->{entry_table}[0]{object_loop};
	} elsif($type eq 'category') {
		$objs = $param->{category_loop};
	} elsif($type eq 'blog') {
		$objs = $param->{blog_loop};
	}
	require Privacy::Object;
	foreach my $obj (@$objs) {
		my $blog_id = $obj->{weblog_id} || $app->param('blog_id') || $obj->{id};
		my $id = $obj->{id} || $obj->{category_id};
		my $protected = Privacy::Object->load({ blog_id => $blog_id, object_id => $id, object_datasource => $type });
		if($protected && ($protected->password || $protected->typekey_users || $protected->livejournal_users || $protected->openid_users)) {
			$obj->{"protected"} = 1;
		}
	}
	
}

sub _param {
	my($eh, $app, $param, $tmpl, $datasource) = @_;
	my $q = $app->{query};
	my $blog_id = $q->param('blog_id');
	my $obj_id = $q->param('id') || $blog_id;
	my $auth_prefs = $app->user->entry_prefs;
	my $config = config('blog:'.$blog_id);
	
    if (my $delim = chr($auth_prefs->{tag_delim})) {
        if ($delim eq ',') {
            $param->{'auth_pref_tag_delim_comma'} = 1;
        } elsif ($delim eq ' ') {
            $param->{'auth_pref_tag_delim_space'} = 1;
        } else {
            $param->{'auth_pref_tag_delim_other'} = 1;
        }
        $param->{'auth_pref_tag_delim'} = $delim;
    }

	require Privacy::Object;
	my $data = Privacy::Object->load({ blog_id => $blog_id, object_id => $obj_id, object_datasource => $datasource });
	if($obj_id && (my $data = Privacy::Object->load({ blog_id => $blog_id, object_id => $obj_id, object_datasource => $datasource }))) {
		$param->{is_password} = $data->password;
		$param->{is_typekey} = $data->typekey_users;
		$param->{is_livejournal} = $data->livejournal_users;
		$param->{is_openid} = $data->openid_users;
		my(@typekey_users, @livejournal_users, @openid_users);
		push @typekey_users, {'tk_user' => $_ }
			foreach split /,/, $data->typekey_users;
		push @livejournal_users, {'lj_user' => $_ }
			foreach split /,/, $data->livejournal_users;	
		push @openid_users, {'oi_user' => $_ }
			foreach split /,/, $data->openid_users;	
		$param->{password} = $data->password;	
		$param->{typekey_users} = \@typekey_users;
		$param->{livejournal_users} = \@livejournal_users;
		$param->{openid_users} = \@openid_users;
	}
	my @group_data;
	require Privacy::Groups;
	my $iter = Privacy::Groups->load_iter(undef, { 'sort' => 'label', direction => 'ascend'});
	while (my $group = $iter->()) {
		my(@typekey_users, @livejournal_users, @openid_users);
		my @typekey_users = split /,/, $group->typekey_users;
		my @livejournal_users = split /,/, $group->livejournal_users;	
		my @openid_users = split /,/, $group->openid_users;			
		push @group_data, {
		  	id => $group->id,
	      	label => $group->label,
	      	description => $group->description,
			typekey_users => \@typekey_users,
			livejournal_users => \@livejournal_users,
			openid_users => \@openid_users

		};
	} 
	require JSON;
	$param->{protection_groups} = JSON::objToJson(\@group_data);
	$param->{protection_groups_loop} = \@group_data;
	$param->{allow_recursive} = 1 
		if $datasource ne 'entry';
	$param->{"is_$datasource"} = 1;
	$param->{type} = $datasource;
	foreach my $field (keys (%$config)) {
		next unless $field =~ m/show_/;
		$param->{$field} = $config->{$field};
	}
}

sub post_save {
	my ($eh, $obj, $original) = @_;
	my $app = MT->instance;
	my $q = $app->{query};
	my $blog_id = $q->param('blog_id');
	return
		if (!$q->param('protect_beacon'));
		
	my @protections = $q->param('protection');
	my $password = 	in_array('Password', @protections) ? $q->param('privacy_password') : '';
	my $typekey_users = in_array('Typekey', @protections) ? $q->param('typekey_users') : '';
	my $livejournal_users = in_array('LiveJournal', @protections) ? $q->param('livejournal_users') : '';
	my $openid_users = in_array('OpenID', @protections) ? $q->param('openid_users') : '';
	require Privacy::Object;
	my $data = Privacy::Object->load({ blog_id => $blog_id, object_id   => $obj->id, object_datasource => $obj->datasource });
	if($data) {
		$data->remove or die $data->errstr;
	}
	$data = Privacy::Object->new;
	$data->blog_id($blog_id);
	$data->object_id($obj->id);
	$data->object_datasource($obj->datasource);

	if(ref($obj) eq 'MT::Entry' && $obj->category){
		my $category = $obj->category;
		my $category_protection = Privacy::Object->load({ blog_id => $blog_id, object_id => $category->id, object_datasource=> $category->datasource});
		if($category_protection) {
			$password = $category_protection->password if !$password;
			$typekey_users = $typekey_users ? join ',', $typekey_users, $category_protection->typekey_users : $category_protection->typekey_users;
			$livejournal_users = $livejournal_users ? join ',', $livejournal_users, $category_protection->livejournal_users : $category_protection->livejournal_users;
			$openid_users = $openid_users ? join ',', $openid_users, $category_protection->openid_users : $category_protection->openid_users;
		}
	}
	$data->password($password);
	$data->typekey_users($typekey_users);
	$data->livejournal_users($livejournal_users);
	$data->openid_users($openid_users);	
	if($password || $typekey_users || $livejournal_users || $openid_users) {
		$data->save or
			die $data->errstr; 
	}
	if($q->param('do_recursive')) {
		if(ref($obj) eq 'MT::Blog') {
			start_background_task(sub {
				require MT::Category;
				my $cat_iter = MT::Category->load_iter({ blog_id => $blog_id });
				while (my $cat = $cat_iter->()) {
					my $protected = Privacy::Object->load({ blog_id => $blog_id, object_id => $cat->id, object_datasource => $cat->datasource});
					if($protected) {
						$protected->remove or
							die $protected->errstr;
					}
					$protected = Privacy::Object->new;
					$protected->blog_id($blog_id);
					$protected->object_id($cat->id);
					$protected->object_datasource($cat->datasource);					
					$protected->password($password);
					$protected->typekey_users($typekey_users);
					$protected->livejournal_users($livejournal_users);
					$protected->openid_users($openid_users);	
					if($password || $typekey_users || $livejournal_users || $openid_users) {
						$protected->save or
							die $protected->errstr; 
					}
				}
			});
		}
		if(ref($obj) eq 'MT::Blog' || ref($obj) eq 'MT::Category') {
			start_background_task(sub {			
				require MT::Entry;
				my %args;
				if(ref($obj) eq 'MT::Category') {
				    $args{'join'} = [ 'MT::Placement', 'entry_id',
				        { category_id => $obj->id } ];
				}
				my $entry_iter = MT::Entry->load_iter({ blog_id => $blog_id }, \%args);
				while (my $entry = $entry_iter->()) {
					my $protected = Privacy::Object->load({ blog_id => $blog_id, object_id => $entry->id, object_datasource => $entry->datasource});
					if($protected) {
						$protected->remove or
							die $protected->errstr;
					}
					$protected = Privacy::Object->new;
					$protected->blog_id($blog_id);
					$protected->object_id($entry->id);
					$protected->object_datasource($entry->datasource);					
					$protected->password($password);
					$protected->typekey_users($typekey_users);
					$protected->livejournal_users($livejournal_users);
					$protected->openid_users($openid_users);	
					if($protected->id || $password || $typekey_users || $livejournal_users || $openid_users) {
						$protected->save or
							die $protected->errstr; 
					}		
				}
			});
		}
	}	
}

sub _header {
	my ($eh, $app, $tmpl) = @_;
	my $plugin = MT::Plugin::Privacy->instance;
	my $link = $app->base.$app->path.$plugin->envelope.'/privacy.cgi';
	my $old = q{<li><a<TMPL_IF NAME=NAV_AUTHORS> class="here"</TMPL_IF> id="nav-authors" title="<MT_TRANS phrase="List Authors">" href="<TMPL_VAR NAME=MT_URL>?__mode=list_authors"><MT_TRANS phrase="Authors"></a></li>};
	$old = quotemeta($old);
	my $new = <<HTML;
<li><a style="background-image: url(<TMPL_VAR NAME=STATIC_URI>plugins/Privacy/images/icon-groups.gif);" <TMPL_IF NAME=NAV_GROUPS> class="here"</TMPL_IF> id="nav-groups" title="<MT_TRANS phrase="Privacy Groups">" href="$link?__mode=groups"><MT_TRANS phrase="Privacy Groups"></a></li>
HTML
	$$tmpl =~ s/($old)/$1\n$new\n/;
}

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

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
