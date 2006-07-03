# Protect Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Arvind Satyanarayan
#

package Protect::CMS;
use strict;

use vars qw( $DEBUG $VERSION @ISA $SCHEMA_VERSION );
@ISA = qw(MT::App::CMS);
$VERSION = '1.21';
$SCHEMA_VERSION = 1.2;

use MT::Util qw( format_ts offset_time_list );
use MT::ConfigMgr;
use MT::App::CMS;
use MT;
use MT::Permission;
use Protect::Protect;
use Protect::Groups;
use JSON;

sub init
{
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;
    $app->add_methods(
    'global_config'       => \&config_global,
    'load_files'             => \&load_files,
    'edit'                => \&edit,
    'save'                => \&save,
    'list_entries'        => \&list_entries,
    'list_blogs'          => \&list_blogs,
    'tk_groups'           => \&tk_groups,
    'delete'              => \&delete,
  
    );
    
    
    $app->{plugin_template_path} = File::Spec->catdir('plugins','Protect','tmpl');
    $app->{default_mode}   = 'edit';
    $app->{user_class}     = 'MT::Author';
    $app->{requires_login} = 1;
    $app->{mtscript_url}   = $app->mt_uri;
    $app;
}

sub build_page {
    
    my $app = shift;
    my $q = $app->{query};
    my($page, $param) = @_;
    $param->{plugin_name       } =  "Protect";
    $param->{blog_id           } = $q->param('blog_id');
    $param->{plugin_version    } =  $VERSION;
    $param->{plugin_author     } =  "Arvind Satyanarayan";
    $param->{mtscript_url      } =  $app->{mtscript_url};
    $param->{script_full_url   } =  $app->base . $app->uri;
    $param->{mt_version        } =  MT->VERSION;
    $param->{language_tag      } =  $app->current_language;
    $app->SUPER::build_page($page, $param);
}

sub edit {
    my $app = shift;
    my $q = $app->{query};
    my ($param, $tmpl, $entry, @typekey_data,@openid_data, $datasource);
    my $blog_id = $q->param('blog_id');
    my $id = $q->param('id');
    my $type = $q->param('_type') || $q->param('from');
	if($type eq 'blog' || $type eq 'blog_home'){
		$tmpl = 'edit.tmpl';
		$app->add_breadcrumb($app->plugin->translate('Protect'));
  	} elsif($type eq 'groups') {
		my(@typekey_users, @livejournal_users, @openid_users);
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
		require Protect::Groups;
		my $data = Protect::Groups->load({ id => $id });
		if($data) {
			$param->{is_typekey} = $data->typekey_users;
			$param->{is_livejournal} = $data->livejournal_users;
			$param->{is_openid} = $data->openid_users;
			push @typekey_users, {'tk_user' => $_ }
				foreach split /,/, $data->typekey_users;
			push @livejournal_users, {'lj_user' => $_ }
				foreach split /,/, $data->livejournal_users;	
			push @openid_users, {'oi_user' => $_ }
				foreach split /,/, $data->openid_users;	
            $param->{id} = $data->id;
            $param->{label} = $data->label;
            $param->{description} = $data->description;				
		}
		for my $author_id (split /,/, $q->param('author_id')) {
		 if($author_id ne 'undefined') {
		    my $commenter = MT::Author->load($author_id);
     	    push @typekey_users, {'tk_user' => $commenter->name};
		 }
		}
		
		$param->{typekey_users} = \@typekey_users;
		$param->{livejournal_users} = \@livejournal_users;
		$param->{openid_users} = \@openid_users;		
        $tmpl = 'tk_edit.tmpl';                
	    $app->add_breadcrumb($app->plugin->translate("MT Protect"),$app->{mtscript_url}.'?__mode=list_plugins');
        $app->add_breadcrumb($app->plugin->translate("Protection Groups"),'mt-protect.cgi?__mode=tk_groups');
        $app->add_breadcrumb($app->plugin->translate("Add New Group"))
 			if !$data;
        $app->add_breadcrumb($data->label)
			if $data;        
  }
    $param->{typekey_user_loop} = \@typekey_data;
    $param->{openid_user_loop} = \@openid_data;
    $param->{message} = $q->param('message');
    $app->build_page($tmpl, $param);
}

sub save {
    my $app = shift;
    my $q = $app->{query};
    my $blog_id = $q->param('blog_id'); 
    my($param,$tmpl,@typekey_data,$data,$uri,$message); 
    my $type = $q->param('_type');
	if($type eq 'blog') {
		my $blog = MT::Blog->load($blog_id);
		post_save($app, $blog);
		$app->redirect($app->uri.'?__more=edit&_type=blog&blog_id='.$blog_id.'&message='.$app->translate('Your changes have been saved'));
    }elsif($type eq 'groups') {
        my $id = $q->param('id');
        unless($data = Protect::Groups->load({ id   => $id })){
            $data = Protect::Groups->new;
        }        
        $data->label($q->param('label'));
        $data->description($q->param('description'));
		$data->typekey_users($q->param('typekey_users'));
		$data->livejournal_users($q->param('livejournal_users'));
		$data->openid_users($q->param('openid_users'));
		$data->save or
			die $data->errstr;
        $app->redirect($app->uri.'?__mode=edit&_type=groups&id='.$data->id.'&message='.$app->translate('Your changes have been saved').'&edit=1');                
    }
}

sub tk_groups {
    my $app = shift;
    my $q = $app->{query};
    my $iter = Protect::Groups->load_iter;
    my (@data,@count,$param);
    my $i         = 0; # loop iteration counter
    my $n_entries = 0; # the number of entries displayed on this page
    my $count     = 0; # the total number of (unpaginated) entries 
    while (my $entry = $iter->()) {
        $count++;
        $n_entries++;        
                        my $row = {
                                id => $entry->id,
                                label => $entry->label,
                                description => $entry->description,
                                entry_odd    => $n_entries % 2 ? 1 : 0,
    };
    
    my $users = $entry->data;
      for my $user (@$users) {       
          push @count, {user => $user};
      }
    	$row->{member_count} = scalar @count.' '.$app->translate('members');
         push @data, $row;
  }
      $i = 0;
    foreach my $e (@data) {
        $e->{entry_odd} = ($i++ % 2 ? 0 : 1);
    }
  $param->{loop} = \@data;
  $param->{empty} = !$n_entries;
  $param->{typekey_groups} = 1;
  $app->add_breadcrumb("MT Protect",$app->{mtscript_url}.'?__mode=list_plugins');
  $app->add_breadcrumb("Protection Groups");
  $app->build_page('tk_groups.tmpl',$param);
}

sub list_entries {
    my $app = shift;
    my $q = $app->{query};        
                my $blog_id = $q->param('blog_id');
                my $blog = MT::Blog->load($blog_id);
                my $param;
                my @data;
    my $limit   = $q->param('limit')   || 20;
    my $offset  = $q->param('offset')  || 0;                
    my %arg = (
    ($limit eq 'none' ? () : (limit => $limit + 1)),
    ($offset ? (offset => $offset) : ()),
    );        
    my %terms = (blog_id => $blog_id);    
                my $i         = 0; # loop iteration counter
    my $n_entries = 0; # the number of entries displayed on this page
    my $count     = 0; # the total number of (unpaginated) entries
    my @entry_data;
                my $iter = Protect::Protect->load_iter(\%terms, \%arg);
                while (my $ntry = $iter->()) {
      $count++;

      my $id = $ntry->entry_id;
      if($id != 0) {
      	      $n_entries++;
                        my $entry = MT::Entry->load($id);
                        my $row = {
                                id => $entry->id,
                                title => $entry->title,
                                date => format_ts("%Y.%m.%d", $entry->created_on),
                                author => $entry->author->name,
                                type => $ntry->type,
                                entry_odd    => $n_entries % 2 ? 1 : 0,
                        };
                        push @data, $row;
                } 
              }
    $i = 0;
    foreach my $e (@data) {
        $e->{entry_odd} = ($i++ % 2 ? 0 : 1);
    }        
    $param->{limit}    = $limit;
    $param->{paginate} = 0;
    if ($limit ne 'none') {
        ## We tried to load $limit + 1 entries above; if we actually got
        ## $limit + 1 back, we know we have another page of entries.
        my $have_next_entry = scalar @entry_data == $limit + 1;
        pop @entry_data if $have_next_entry;
        if ($offset) {
            $param->{prev} = 1;
            $param->{prev_offset} = $offset - $limit;
        }
        if ($have_next_entry) {
            $param->{next} = 1;
            $param->{next_offset} = $offset + $limit;
        }
    }
    
    my @limit_data;
    for (5, 10, 20, 50, 100) {
        push @limit_data, { limit       => $_,
        limit_label => $_ };
        $limit_data[-1]{limit_selected} = 1 if $limit == $_;
    }
    $param->{limit_loop} = \@limit_data;
    $param->{empty} = !$n_entries;
    $param->{offset}= $offset;        
    $param->{entry_loop} = \@data;
    $param->{entries} = 1;
    $app->add_breadcrumb('Entries', $app->{mtscript_url} . '?__mode=list_entries&blog_id=' . $blog->id);
    $app->add_breadcrumb($app->translate('Protected Entries'));                
        $app->build_page('list.tmpl',$param);    
}

sub list_blogs {
    my $app = shift;
    my $q = $app->{query};        
		my $param;
    my @data;
    my $limit   = $q->param('limit')   || 20;
    my $offset  = $q->param('offset')  || 0;                
    my %arg = (
    ($limit eq 'none' ? () : (limit => $limit + 1)),
    ($offset ? (offset => $offset) : ()),
    );        
    my %terms = (entry_id => 0);    
    my $i         = 0; # loop iteration counter
    my $n_entries = 0; # the number of entries displayed on this page
    my $count     = 0; # the total number of (unpaginated) entries
    my @entry_data;
                my $iter = Protect::Protect->load_iter(\%terms, \%arg);
                while (my $entry = $iter->()) {
      $count++;

      my $id = $entry->blog_id;
      my $blog = MT::Blog->load($id);
      	      $n_entries++;
                        my $row = {
                                id => $blog->id,
                                title => $blog->name,
                                type => $entry->type,
                                entry_odd    => $n_entries % 2 ? 1 : 0,
                        };
                        push @data, $row;
              }
    $i = 0;
    
    $param->{limit}    = $limit;
    $param->{paginate} = 0;
    if ($limit ne 'none') {
        ## We tried to load $limit + 1 entries above; if we actually got
        ## $limit + 1 back, we know we have another page of entries.
        my $have_next_entry = scalar @entry_data == $limit + 1;
        pop @entry_data if $have_next_entry;
        if ($offset) {
            $param->{prev} = 1;
            $param->{prev_offset} = $offset - $limit;
        }
        if ($have_next_entry) {
            $param->{next} = 1;
            $param->{next_offset} = $offset + $limit;
        }
    }
    
    my @limit_data;
    for (5, 10, 20, 50, 100) {
        push @limit_data, { limit       => $_,
        limit_label => $_ };
        $limit_data[-1]{limit_selected} = 1 if $limit == $_;
    }
    $param->{limit_loop} = \@limit_data;
    $param->{empty} = !$n_entries;
    $param->{offset}= $offset;        
                $param->{entry_loop} = \@data;
    $app->add_breadcrumb('System Overview', $app->{mtscript_url} . '?__mode=admin');
    $app->add_breadcrumb('Weblogs', $app->{mtscript_url} . '?__mode=system_list_blogs');
    $app->add_breadcrumb($app->translate('Protected Weblogs'));                
        $app->build_page('list_blogs.tmpl',$param);    
}

sub delete
{
    debug("Calling delete_entry...");
    my $app = shift;   
    my $q = $app->{query};
                my $type = $q->param('_type');
    if($type eq 'groups') {
        $q->param('message','Groups removed');
        foreach my $key ($q->param('id')) {
            my $data = Protect::Groups->load({ id    => $key });
            $data->remove or return $app->error("Error: " . $data->errstr);
        }
     tk_groups($app);        
    } elsif($type eq 'entries') {
        $q->param('message','Entries unprotected');
        foreach my $key ($q->param('id')) {
            my $data = Protect::Protect->load({ entry_id    => $key });
            $data->remove or return $app->error("Error: " . $data->errstr);
        }
     list_entries($app);        
    } elsif($type eq 'weblogs') {
        $q->param('message','Weblogs unprotected');
        foreach my $key ($q->param('id')) {
            my $data = Protect::Protect->load({ entry_id => 0, blog_id    => $key });
            $data->remove or return $app->error("Error: " . $data->errstr);
        }
     list_entries($app);        
    }    
}

sub confirm_delete {
    my $app = shift;
    my $q = $app->{query};
                my $type = $q->param('_type');    
    my @entry_data;
    my $param;
    if($type eq 'groups') {
    foreach my $id ($q->param('id')) {
        my $data = Protect::Groups->load({ id    => $id });
      my $row = {
                id          => $id,
                label   => $data->label,
                description    => $data->description,
        };
       push @entry_data, $row;
        }        
    $app->add_breadcrumb("MT Protect",'mt-protect.cgi?__mode=global_config');
        $app->add_breadcrumb("Typekey Groups",'mt-protect.cgi?__mode=tk_groups');        
        $app->add_breadcrumb("Confirm Delete");
    }
    $param->{entry_loop} = \@entry_data;
    $param->{type} = $q->param('_type');
        $app->build_page('delete.tmpl', $param);   
}   

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
<a href="#" onclick="return openManual('entries', 'item_tags')" class="help">?</a> <span class="hint"><TMPL_IF NAME=AUTH_PREF_TAG_DELIM_COMMA><MT_TRANS phrase="(comma-delimited list)"><TMPL_ELSE><TMPL_IF NAME=AUTH_PREF_TAG_DELIM_SPACE><MT_TRANS phrase="(space-delimited list)"><TMPL_ELSE><MT_TRANS phrase="(delimited by '[_1]')" params="<TMPL_VAR NAME=AUTH_PREF_TAG_DELIM>"></TMPL_IF></TMPL_IF></span>
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

<div class="field">
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

sub post_save {
	my ($eh, $obj, $original) = @_;
	my($data);
	my $app = MT->instance;
	my $q = $app->{query};
	my $blog_id = $q->param('blog_id');
	return
		if (!$q->param('protect_beacon'));
	require Protect::Object;
	unless($data = Protect::Object->load({ blog_id => $blog_id, object_id   => $obj->id, object_datasource => $obj->datasource })){
		$data = Protect::Object->new;
		$data->blog_id($blog_id);
		$data->object_id($obj->id);
		$data->object_datasource($obj->datasource);
	}
	$data->password($q->param('password'));
	$data->typekey_users($q->param('typekey_users'));
	$data->livejournal_users($q->param('livejournal_users'));
	$data->openid_users($q->param('openid_users'));
	$data->save or
		die $data->errstr; 
}

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub _load_link {
    my $link = shift;
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new ( GET => $link );
    $ua->timeout (15);
    $ua->agent( "MTBlogroll/$VERSION" );
    my $result = $ua->request( $req );
    return '' unless $result->is_success;
    return $result->content;
}

sub debug {
    my $err = shift;
    my $mark = shift || '>';
    print STDERR "$mark $err\n" if $DEBUG;
}

#sub brpath {
#    
#    my $app = shift;
#    return $app->{__brpath} if exists $app->{__brpath};
#    my $brpath = File::Spec->catdir($app->path,'plugins','Protect');
#    $app->{__brpath} = $brpath;
#    
#}
#
sub uri { my $app = shift; $app->app_path . $app->script; }
#
#sub brscript {
#    return 'mt-protect.cgi';
#}

sub plugin {
	return MT::Plugin::Protect->instance;
}

1; 
