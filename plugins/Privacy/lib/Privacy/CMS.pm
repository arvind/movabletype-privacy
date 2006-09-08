# Protect Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Arvind Satyanarayan
#

package Privacy::CMS;
use strict;

use vars qw( $DEBUG @ISA );
@ISA = qw(MT::App::CMS);

use MT::Util qw( format_ts offset_time_list );
use MT::ConfigMgr;
use MT::App::CMS;
use MT;
use MT::Permission;

sub init
{
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;
    $app->add_methods(
    'edit'   => \&edit,
    'save'   => \&save,
    'groups' => \&groups,
    'delete' => \&delete,
  
    );
    $app->{state_params} = [
        '_type', 'id', 'blog_id', 'from'
    ];    
    $app->{plugin_template_path} = File::Spec->catdir('plugins','Privacy','tmpl');
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
    $param->{plugin_name} =  "Protect";
    $param->{blog_id} = $q->param('blog_id');
	$param->{system_overview_nav} = 1
		if !$q->param('blog_id');
    $param->{plugin_version} =  $app->plugin->version;
    $param->{plugin_author} =  "Arvind Satyanarayan";
    $param->{mtscript_url} =  $app->{mtscript_url};
    $param->{script_full_url} =  $app->base . $app->uri;
    $param->{mt_version} =  MT->VERSION;
    $param->{language_tag} =  $app->current_language;
    $app->SUPER::build_page($page, $param);
}

sub edit {
    my $app = shift;
    my $q = $app->{query};
    my ($param, $tmpl, $entry, @typekey_data,@openid_data, $datasource, $group);
    my $blog_id = $q->param('blog_id');
    my $blog = MT::Blog->load($blog_id);
    my $id = $q->param('id');
    my $type = $q->param('_type') || $q->param('from');
	if($type eq 'blog' || $type eq 'blog_home'){
		$tmpl = 'protect_blog.tmpl';
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
		require Privacy::Groups;
		if($id && ($group = Privacy::Groups->load($id))) {
			$param->{is_typekey} = $group->typekey_users;
			$param->{is_livejournal} = $group->livejournal_users;
			$param->{is_openid} = $group->openid_users;
			push @typekey_users, {'tk_user' => $_ }
				foreach split /,/, $group->typekey_users;
			push @livejournal_users, {'lj_user' => $_ }
				foreach split /,/, $group->livejournal_users;	
			push @openid_users, {'oi_user' => $_ }
				foreach split /,/, $group->openid_users;	
		          $param->{id} = $group->id;
		          $param->{label} = $group->label;
		          $param->{description} = $group->description;				
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
		$param->{nav_groups} = 1;
	    $tmpl = 'edit_group.tmpl';                
	    $app->add_breadcrumb($app->plugin->translate("Protection Groups"),$app->uri(mode => 'groups'));
	    $app->add_breadcrumb($app->plugin->translate("Add New Group"))
			if !$id;
	    $app->add_breadcrumb($group->label)
			if $id;        
	}
	$param->{saved} = $q->param('saved');
	$param->{return_args} ||= $app->make_return_args;
    $app->build_page($tmpl, $param);
}

sub groups {
    my $app = shift;
    my $q = $app->{query};
	require Privacy::Groups;
    my $iter = Privacy::Groups->load_iter(undef, { 'sort' => 'label', direction => 'ascend'});
    my (@data,$param);
    my $n_entries = 0; # the number of entries displayed on this page
    while (my $group = $iter->()) {
        $n_entries++;        
        my $row = {
        	id => $group->id,
          	label => $group->label,
          	description => $group->description,
			typekey_users => $group->typekey_users,
			livejournal_users => $group->livejournal_users,
			openid_users => $group->openid_users,
          	entry_odd    => $n_entries % 2 ? 1 : 0,
			member_count => scalar split ',', join ',', $group->typekey_users,$group->livejournal_users,$group->openid_users
	    };
		push @data, $row;
  	}
	$param->{loop} = \@data;
	$param->{empty} = !$n_entries;
	$param->{nav_groups} = 1;
	$param->{saved_deleted} = $q->param('saved_deleted');
	$app->add_breadcrumb($app->plugin->translate('Privacy Groups'));
	$app->build_page('groups.tmpl', $param);
}

sub save {
    my $app = shift;
    my $q = $app->{query};
    my $blog_id = $q->param('blog_id'); 
    my $type = $q->param('_type');
    my $id = $q->param('id');

	if($type eq 'blog') {
		my $blog = MT::Blog->load($blog_id);
		require Privacy::App;
		Privacy::App::post_save($app, $blog);
    } elsif($type eq 'groups') {
		require Privacy::Groups;
 		my $group = Privacy::Groups->load($id);
		if(!$group) {
			$group = Privacy::Groups->new;
		}
    	my $names = $group->column_names;
		my %values = map { $_ => scalar $q->param($_) } @$names;
		$group->set_values(\%values);
		$group->save or
			die $group->errstr;
    }
    $app->add_return_arg(saved => 1);
    $app->call_return;
}

sub delete
{
    debug("Calling delete_entry...");
    my $app = shift;   
    my $q = $app->{query};

 	return unless $app->validate_magic;

    my $type = $q->param('_type');
    if($type eq 'groups') {
		require Privacy::Groups;
        foreach my $id ($q->param('id')) {
            my $group = Privacy::Groups->load($id);
            $group->remove or return $app->error("Error: " . $group->errstr);
        }       
    } 
    $app->add_return_arg(saved_deleted => 1);
    $app->call_return;   
}

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub debug {
    my $err = shift;
    my $mark = shift || '>';
    print STDERR "$mark $err\n" if $DEBUG;
}

sub uri { my $app = shift; $app->app_path . $app->script . $app->uri_params(@_); }

sub plugin {
	return MT::Plugin::Privacy->instance;
}


1;