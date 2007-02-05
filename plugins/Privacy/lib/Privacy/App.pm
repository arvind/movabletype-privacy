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
	my $privacy_frame = MT::Plugin::Privacy->instance;
    if ($privacy_frame) {
        require MT::Request;
        my ($scope) = (@_);
        $config = MT::Request->instance->cache('protect_config_'.$scope);
        if (!$config) {
            $config = $privacy_frame->get_config_hash($scope);
            MT::Request->instance->cache('protect_config_'.$scope, $config);
        }
    }
    $config;
}

sub convert_data {
	my $privacy_frame = MT::Plugin::Privacy->instance;
	
	require Privacy::Protect;
	require Privacy::Object;
	require Privacy::Groups;
	
	my $driver = MT::Object->driver;
    my $db_defs = $driver->column_defs('Privacy::Protect');
    
	if(defined $db_defs) {
		my $objs_iter = Privacy::Protect->load_iter();
		while (my $orig_obj = $objs_iter->()) {
			my $defaults = {
				blog_id => $orig_obj->blog_id,
				object_id => $orig_obj->entry_id,
				object_datasource => 'entry',
				type => lc($orig_obj->type)
			};
			if(!$orig_obj->entry_id) {
				$defaults->{object_datasource} = 'blog';
				$defaults->{object_id} = $orig_obj->blog_id;
			}
			if($orig_obj->type eq 'Password') {
				my $obj = Privacy::Object->new;
				$obj->set_values($defaults);
				$obj->credential($orig_obj->data);
				$obj->save or die $obj->errstr;
			} else {
				my $users = $orig_obj->data;
				foreach (@$users) {
					my $obj = Privacy::Object->new;
					$obj->set_values($defaults);
					$obj->credential($_);
					$obj->save or die $obj->errstr;				
				}
			}
			$orig_obj->remove or die $orig_obj->errstr;
		}
	}
	my $groups_iter = Privacy::Groups->load_iter();
	while (my $group = $groups_iter->()) {
		my $defaults = {
			object_id => $group->id,
			object_datasource => $group->datasource,
			type => lc($group->type)
		};
		my $users = $group->data;
		foreach (@$users) {
			my $obj = Privacy::Object->new;
			$obj->set_values($defaults);
			$obj->credential($_);
			$obj->save or die $obj->errstr;				
		}
	}
}

sub load_files {
	my ($eh, $tmpls) = @_;
	my $privacy_frame = MT::Plugin::Privacy->instance;
	local (*FIN, $/);
    $/ = undef;
    foreach my $template (@$templates) {
        my $file = File::Spec->catfile($privacy_frame->{full_path}, 'tmpl', 'default_templates', dirify($template->{name}).'.tmpl');
        if ((-e $file) && (-r $file)) {
            open FIN, "<$file"; my $data = <FIN>; close FIN;
            $template->{text} = $data;
        } else {
            die $privacy_frame->translate("Couldn't find file '[_1]'", $file);
        }
		if(@$templates) {
			push @$templates, $template;
		} else {
	        $template->{name} = $privacy_frame->translate($template->{name});
	        $template->{text} = $privacy_frame->translate_templatized($template->{text});
			require MT::Blog;
			require MT::Template;
			my $iter = MT::Blog->load_iter;		
			while (my $blog = $iter->()) {			
		        my $tmpl = MT::Template->new;
		        $tmpl->set_values($template);
		        $tmpl->build_dynamic(0);
		        $tmpl->blog_id($blog->id);
		        $tmpl->save or
		            return $app->error($privacy_frame->translate(
		                "Populating blog with template '[_1]' failed: [_2]", $template->{name},
		                $tmpl->errstr));
			}			
		}
    }
}

sub _edit_entry {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $edit_tmpl_path = File::Spec->catdir($privacy_frame->{full_path},'tmpl','protect.tmpl');
	
	$old = qq{doAddCategory(this)};
	$old = quotemeta($old);
	$new = qq{doAddCategoryDefaults(this)};
	$$tmpl =~ s/$old/$new/;
	
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
<div class="field" id="protect"<TMPL_UNLESS NAME=DISP_PREFS_SHOW_PRIVACY> style="display:none;"</TMPL_UNLESS>>
<div class="field-header">
<label for="text_more"><MT_TRANS phrase="Privacy Settings"></label>
</div>
<div class="field-wrapper">

<TMPL_INCLUDE NAME="$edit_tmpl_path">

</div>
</div>

HTML
	$$tmpl =~ s/($old)/$1\n$new\n/;
}

sub _entry_prefs {
	my ($cb, $app, $template) = @_;
	my ($old, $new);	
	$old = qq{var customizable_fields = new Array('category'};	
	$old = quotemeta($old);	
	$new = qq{var customizable_fields = new Array('category','privacy'};
	$$template =~ s/$old/$new/;	
	
	$old = qq{<TMPL_IF NAME=DISP_PREFS_SHOW_PING_URLS>custom_fields.push('ping-urls');</TMPL_IF>};
	$old = quotemeta($old);
	$new = qq{<TMPL_IF NAME=DISP_PREFS_SHOW_PRIVACY>custom_fields.push('privacy');</TMPL_IF>};
	$$template =~ s/($old)/$1\n$new\n/;
	
	$old = qq{<li><label><input type="checkbox" name="custom_prefs" id="custom-prefs-keywords" value="keywords" onclick="setCustomFields(); return true"<TMPL_IF NAME=DISP_PREFS_SHOW_KEYWORDS> checked="checked"</TMPL_IF><TMPL_UNLESS NAME=DISP_PREFS_CUSTOM> disabled="disabled"</TMPL_UNLESS> class="cb" /> <MT_TRANS phrase="Keywords"></label></li>};
	$old = quotemeta($old);
	$new = qq{<li><label><input type="checkbox" name="custom_prefs" id="custom-prefs-privacy" value="privacy" onclick="setCustomFields(); return true"<TMPL_IF NAME=DISP_PREFS_SHOW_PRIVACY> checked="checked"</TMPL_IF><TMPL_UNLESS NAME=DISP_PREFS_CUSTOM> disabled="disabled"</TMPL_UNLESS> class="cb" /> <MT_TRANS phrase="Privacy Settings"></label></li>};
	$$template =~ s/($old)/$1\n$new\n/;
}

sub _edit_category {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $edit_tmpl_path = File::Spec->catdir($privacy_frame->{full_path},'tmpl','protect.tmpl');
	my $recursive_stub = File::Spec->catdir($privacy_frame->{full_path},'tmpl','recursive-stub.tmpl');
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
	
	$old = qq{<TMPL_INCLUDE NAME="rebuild-stub.tmpl">};
	$old = quotemeta($old);
	$new = <<HTML;
<TMPL_INCLUDE NAME="$recursive_stub">
HTML
	$$tmpl =~ s/($old)/$1\n$new\n/;
}

sub _edit_categories {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $privacy_frame = MT::Plugin::Privacy->instance;

	$old = qq{<TMPL_VAR NAME=CATEGORY_LABEL></a>};
	$old = quotemeta($old);
	$new = qq{<TMPL_IF NAME=PROTECTED>&nbsp;&nbsp;<a href="<TMPL_VAR NAME=SCRIPT_URL>?__mode=view&amp;_type=category&amp;blog_id=<TMPL_VAR NAME=BLOG_ID>&amp;id=<TMPL_VAR NAME=CATEGORY_ID>#protect"><img src="<TMPL_VAR NAME=STATIC_URI>plugins/Privacy/images/protected.gif" alt="<MT_TRANS phrase="Private Category">"  /></TMPL_IF>};
	$$tmpl =~ s/($old)/$1\n$new\n/;	
}

sub _list_entry {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $privacy_frame = MT::Plugin::Privacy->instance;

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
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $link = $app->base.$app->path.$privacy_frame->envelope.'/privacy.cgi';
	
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
		my @protected = Privacy::Object->load({ blog_id => $blog_id, object_id => $id, object_datasource => $type });
		$obj->{"protected"} = scalar @protected;
	}
	
}

sub _param {
	my($eh, $app, $param, $tmpl, $datasource) = @_;
	my $q = $app->{query};
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $blog_id = $q->param('blog_id') || 0;
	my $obj_id = $q->param('id') || $blog_id;
	my $auth_prefs = $app->user->entry_prefs;
	my $config = config($blog_id ? 'blog:'.$blog_id : 'system');
	
	my ($terms, @group_data, @category_defaults, $blog_default);
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
	require MT::PluginData;
	if($q->param('id') || ($obj_id && $datasource eq 'blog')) {
		$terms = { blog_id => $blog_id, object_id => $obj_id, object_datasource => $datasource };
	} elsif(!$q->param('id')) {
		$blog_default = MT::PluginData->load({ plugin => 'Privacy', key => 'blog'.$blog_id });
		if($blog_default) {
			if(($datasource eq 'entry' && $blog_default->data->{entries}) || ($datasource eq 'category' && $blog_default->data->{categories})){
				$terms = { blog_id => $blog_id, object_id => $blog_id, object_datasource => 'blog' };
			}		
		}		
	}
	
	$param->{is_private} = 1;
	my @auth_loop; 
	
    foreach my $type (@{$privacy_frame->{privacy_types}}) {
		my $key = $type->{key};
		$terms->{type} = $key;	
	
		my $row = $type;
		$row->{show} = $config->{"show_$key"};
		$row->{single} = ($type->{type} eq 'single') ? 1 : 0;	
		foreach (keys (%{$type->{lexicon}})) {
			$row->{$_} = $type->{lexicon}->{$_};
		}		
		if($type->{type} eq 'multiple') {
            my @users = Privacy::Object->load($terms);
            if(@users) {
	            my @user_loop;
	            push @user_loop, { user => $_->credential } for @users;
	            $row->{user_loop} = \@user_loop;
				$row->{is_selected} = 1;
			}
		} else {
			my $privacy = Privacy::Object->load($terms);
			$row->{is_selected} = $row->{credential} = $privacy->credential
				if $privacy;
		}
		push @auth_loop, $row;
    }
	
	$param->{auth_loop} = \@auth_loop;
	
	my $category_loop = $param->{category_loop};
	foreach my $cat (@$category_loop) {
		my $category_defaults = MT::PluginData->load({ plugin => 'Privacy', key => 'category'.$cat->{category_id} });
		next unless $category_defaults;
		my $cat_terms = { blog_id => $blog_id, object_id => $cat->{category_id}, object_datasource => 'category' };

		my $row = { id => $cat->{category_id} };
		
	    foreach my $type (@{$privacy_frame->{privacy_types}}) {
				my $key = $type->{key};
				$cat_terms->{type} = $key;
				if($type->{type} eq 'multiple') {
		            my @users = Privacy::Object->load($cat_terms);
		            next unless @users;
		            my @user_loop;
		            push @user_loop, $_->credential for @users;
		            $row->{"${key}_users"} = \@user_loop;
				} else {
					my $privacy = Privacy::Object->load($cat_terms);
					$row->{"$key"} = $privacy->credential
						if $privacy;
				}
	    }		
		push @category_defaults, $row;		
	}
	
	if(MT->product_code eq 'MTE') {
		require MT::Group;
		my $iter = MT::Group->load_iter;
		while (my $group = $iter->()) {
			my $row = { 
			  	id => $group->id,
		      	label => $group->display_name,
		      	description => $group->description
			};
			my $users_iter = $group->user_iter({ type => MT::Author::AUTHOR() });
			my @user_loop;
			while (my $user = $users_iter->()) {
				push @user_loop, $user->name;
			}
			$row->{"ldap_users"} = \@user_loop;
			push @group_data, $row;	
		}
	} else {
		require Privacy::Groups;
		my $iter = Privacy::Groups->load_iter(undef, { 'sort' => 'label', direction => 'ascend'});
		while (my $group = $iter->()) {
			my $row = { 
			  	id => $group->id,
		      	label => $group->label,
		      	description => $group->description
			};
		
			my $grp_terms = { blog_id => 0, object_id => $group->id, object_datasource => $group->datasource };
		
		    foreach my $type (@{$privacy_frame->{privacy_types}}) {
				my $key = $type->{key};
				$grp_terms->{type} = $key;
				if($type->{type} eq 'multiple') {
		            my @users = Privacy::Object->load($grp_terms);
		            next unless @users;
		            my @user_loop;
		            push @user_loop, $_->credential for @users;
		            $row->{"${key}_users"} = \@user_loop;
				} else {
					my $privacy = Privacy::Object->load($grp_terms);
					$row->{"$key"} = $privacy->credential
						if $privacy;
				}
		    }
		
			push @group_data, $row;		
		} 
	}
	require JSON;
	$param->{protection_groups} = JSON::objToJson(\@group_data);
	$param->{protection_groups_loop} = \@group_data;
	$param->{category_defaults} = JSON::objToJson(\@category_defaults);
	
	if($datasource ne 'entry') {
		$param->{allow_defaults} = 1;
		require MT::PluginData;
		my $default_config = MT::PluginData->load({ plugin => 'Privacy', key => 'blog'.$blog_id });
		if($default_config && $default_config->data->{entries} && $datasource ne 'blog') {
			$param->{is_blog_override} = 1;
			$param->{is_private} = 1;
		} else {
			$default_config = MT::PluginData->load({ plugin => 'Privacy', key => $datasource.$obj_id });		
		}		
		if($default_config) {
			$param->{is_entries} = $default_config->data->{entries};
			$param->{is_categories} = $default_config->data->{categories};
		}
	}
	$param->{"is_$datasource"} = 1;
	$param->{type} = $datasource;
	
	# foreach my $field (keys (%$config)) {
	# 	next unless $field =~ m/show_/;
	# 	$param->{$field} = $config->{$field};
	# }
	
	
	
	(my $cgi_path = $app->config->AdminCGIPath || $app->config->CGIPath) =~ s|/$||;
    my $privacy_frame_page = ($cgi_path . '/' 
                       . $privacy_frame->envelope . '/privacy.cgi');
	$param->{privacy_full_url} = $privacy_frame_page;	
}

sub post_save {
	my ($eh, $obj, $original) = @_;
	my $app = MT->instance;
	my $q = $app->{query};
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $blog_id = $q->param('blog_id') || 0;
	my $new_asset = !$q->param('id');
	
	return if (!$q->param('protect_beacon'));
	require Privacy::Object;
	
	my @orig_privacy = Privacy::Object->load({ blog_id => $blog_id, object_id => $obj->id, object_datasource => $obj->datasource });
	$_->remove or die $_->errstr foreach @orig_privacy;
	
	my @protections = $q->param('protection');
	my $defaults = {
		blog_id => $blog_id,
		object_id => $obj->id,
		object_datasource => $obj->datasource
	};
	
    foreach my $type (@{$privacy_frame->{privacy_types}}) {
		my $prvt_obj = Privacy::Object->new;
		$prvt_obj->set_values($defaults);
		$prvt_obj->type($type->{key});		
		if(in_array($type->{key}, @protections) || ($q->param('_type') eq 'groups' && $type->{type} ne 'single')) {
			if($type->{type} eq 'single') {
				$prvt_obj->credential($q->param($type->{key}));
				$prvt_obj->save or die $prvt_obj->errstr;
			} else {
				foreach (split /,/, $q->param($type->{key}."_users")) {
					$prvt_obj->id(0);
					$prvt_obj->credential($_);
					$prvt_obj->save or die $prvt_obj->errstr;			
				}				
			}
		}
    }	 
		
	if(ref($obj) eq 'MT::Category') {
		require MT::PluginData;
		my $blog_default = MT::PluginData->load({ plugin => 'Privacy', key => 'blog'.$blog_id });
		if($blog_default) {
			if($blog_default->data->{categories} && $new_asset){
				my @blog_protection = Privacy::Object->load({ blog_id => $blog_id, object_id => $blog_id, object_datasource=> 'blog' });
				foreach my $privacy (@blog_protection) {
					my $new_prvt = $privacy->clone();
					$new_prvt->id(0);
					$new_prvt->set_values($defaults);
					$new_prvt->save or die $new_prvt->errstr;
				}
			}		
		}	 
	}
		
	if(ref($obj) ne 'MT::Entry') {
		require MT::PluginData;
		my $default = MT::PluginData->get_by_key({ plugin => 'Privacy', key => $obj->datasource.$obj->id });

		$default->data({
			entries => ($q->param('entries') || 0),
			categories => ($q->param('categories') || 0)
		});
		$default->save or die $default->errstr;
	}
}

sub _header {
	my ($eh, $app, $tmpl) = @_;
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $link = $app->base.$app->path.$privacy_frame->envelope.'/privacy.cgi';
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