package Protect::Transformer;

sub _edit_entry {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $plugin = MT::Plugin::Protect->instance;
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
<label for="text_more"><MT_TRANS phrase="Protect Entry"></label>
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
	my $plugin = MT::Plugin::Protect->instance;
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

sub _list_entry {
	my($eh, $app, $tmpl) = @_;
	my($old, $new);
	my $plugin = MT::Plugin::Protect->instance;
	# $old = qq{<th id="en-title"><MT_TRANS phrase="Title"></th>};
	# $old = quotemeta($old);
	# $new = qq{<TMPL_UNLESS NAME=IS_POWER_EDIT><th id="en-protected">&nbsp;</th></TMPL_UNLESS>};
	# $$tmpl =~ s/($old)/\n$new\n$1\n/;
	
	$old = qq{<TMPL_VAR NAME=TITLE_LONG>};
	$old = quotemeta($old);
	$new = qq{<TMPL_UNLESS NAME=IS_POWER_EDIT><TMPL_IF NAME=ENTRY_PROTECTED><img src="<TMPL_VAR NAME=STATIC_URI>plugins/Protect/images/protected.gif" alt="<MT_TRANS phrase="Entry Protected">"  /></a><TMPL_ELSE>&nbsp;</TMPL_IF></TMPL_UNLESS>};
	$$tmpl =~ s/($old)/$1\n$new\n/;	
	
	$old = qq{<TMPL_VAR NAME=TITLE_SHORT>};
	$old = quotemeta($old);
	$new = qq{<TMPL_UNLESS NAME=IS_POWER_EDIT><TMPL_IF NAME=ENTRY_PROTECTED></a>&nbsp;&nbsp;<a href="<TMPL_VAR NAME=SCRIPT_URL>?__mode=view&amp;_type=entry&amp;id=<TMPL_VAR NAME=ID>&amp;blog_id=<TMPL_VAR NAME=BLOG_ID>#protect"><img src="<TMPL_VAR NAME=STATIC_URI>plugins/Protect/images/protected.gif" alt="<MT_TRANS phrase="Entry Protected">"  /><TMPL_ELSE>&nbsp;</TMPL_IF></TMPL_UNLESS>};
	$$tmpl =~ s/($old)/$1\n$new\n/;	
}

sub _list_entry_param {
	my($eh, $app, $param, $tmpl) = @_;
	my $blog_id = $app->param('blog_id');
	my $entries = $param->{entry_table}[0]{object_loop};
	require Protect::Object;
	foreach my $entry (@$entries) {
		my $data = Protect::Object->load({ blog_id => $blog_id, object_id => $entry->{id}, object_datasource => 'entry' });
		if($data && ($data->password || $data->typekey_users || $data->livejournal_users || $data->openid_users)) {
			$entry->{entry_protected} = 1;
		}
	}
	
}

sub _param {
	my($eh, $app, $param, $tmpl, $datasource) = @_;
	my $q = $app->{query};
	my $blog_id = $q->param('blog_id');
	my $obj_id = $q->param('id') || $blog_id;
	my $auth_prefs = $app->user->entry_prefs;
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
	require Protect::Object;
	my $data = Protect::Object->load({ blog_id => $blog_id, object_id => $obj_id, object_datasource => $datasource });
	if($data) {
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
	require Protect::Groups;
	my $iter = Protect::Groups->load_iter(undef, { 'sort' => 'label', direction => 'ascend'});
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
}

sub post_save {
	my ($eh, $obj, $original) = @_;
	my($data);
	my $app = MT->instance;
	my $q = $app->{query};
	my $blog_id = $q->param('blog_id');
	return
		if (!$q->param('protect_beacon'));
		
	my @protections = $q->param('protection');
	my $password = 	in_array('Password', @protections) ? $q->param('password') : '';
	my $typekey_users = in_array('Typekey', @protections) ? $q->param('typekey_users') : '';
	my $livejournal_users = in_array('LiveJournal', @protections) ? $q->param('livejournal_users') : '';
	my $openid_users = in_array('OpenID', @protections) ? $q->param('openid_users') : '';
	
	require Protect::Object;
	unless($data = Protect::Object->load({ blog_id => $blog_id, object_id   => $obj->id, object_datasource => $obj->datasource })){
		$data = Protect::Object->new;
		$data->blog_id($blog_id);
		$data->object_id($obj->id);
		$data->object_datasource($obj->datasource);
	}
	if(ref($obj) eq 'MT::Entry' && $obj->category){
		my $category = $obj->category;
		my $category_protection = Protect::Object->load({ blog_id => $blog_id, object_id => $category->id, object_datasource=> $category->datasource});
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
}

sub _header {
	my ($eh, $app, $tmpl) = @_;
	my $plugin = MT::Plugin::Protect->instance;
	my $link = $app->base.$app->path.$plugin->envelope.'/mt-protect.cgi';
	my $old = q{<li><a<TMPL_IF NAME=NAV_AUTHORS> class="here"</TMPL_IF> id="nav-authors" title="<MT_TRANS phrase="List Authors">" href="<TMPL_VAR NAME=MT_URL>?__mode=list_authors"><MT_TRANS phrase="Authors"></a></li>};
	$old = quotemeta($old);
	my $new = <<HTML;
<li><a style="background-image: url(<TMPL_VAR NAME=STATIC_URI>plugins/Protect/images/icon-groups.gif);" <TMPL_IF NAME=NAV_GROUPS> class="here"</TMPL_IF> id="nav-groups" title="<MT_TRANS phrase="Privacy Groups">" href="$link?__mode=groups"><MT_TRANS phrase="Privacy Groups"></a></li>
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
