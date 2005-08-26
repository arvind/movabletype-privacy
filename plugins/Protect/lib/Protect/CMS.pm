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
$VERSION = '1.2';
$SCHEMA_VERSION = 1.2;

use MT::PluginData;
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
    'tk_groups'           => \&tk_groups,
    'delete'              => \&delete,
    'notice' => \&notice,
    'upgrade' => \&doinstallupgrade,
    'install' => \&doinstallupgrade,
    'run_upgrade' => \&run_upgrade,
    'run_install' => \&run_install,    
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

sub config_global {
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }	        
    my $q = $app->{query};
    my $param;
    my $cblog_id = $q->param('cblog_id');
    if($cblog_id){
        my $cblog = MT::Blog->load($cblog_id);
        $param->{cblog} = $cblog->name;
        $param->{installed} = $q->param('installed');
        $param->{uninstalled} = $q->param('uninstalled');
    }
    $app->add_breadcrumb("MT Protect",'mt-protect.cgi?__mode=global_config');
    $app->add_breadcrumb("Global Config");
    #    $param->{breadcrumbs} = $app->{breadcrumbs};
    #    $param->{breadcrumbs}[-1]{is_last} = 1;
if (my $auth = $app->{author}) {
        my @perms = MT::Permission->load({ author_id => $auth->id });
        my @data;
        for my $perms (@perms) {
            next unless $perms->role_mask;
            my $blog = MT::Blog->load($perms->blog_id);
            my $pdblog = MT::PluginData->load({ plugin => 'Protect', key    => $perms->blog_id });
            push @data, { blog_id   => $blog->id,
                blog_name => $blog->name,
            blog_installed => $pdblog };
        }
        $param->{blog_loop} = \@data;
    }
    $param->{global_config} = 1;
    $app->build_page('config.tmpl', $param);
}

sub load_files {
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }    
    my $q = $app->{query};
    my $blog_id = $q->param('cblog_id');
    my $type = $q->param('_type');
    my $blog = MT::Blog->load($blog_id);
    my $auth_typekey = $blog->site_path . "/Auth_TypeKey.php";
    my $typekey_lib = $blog->site_path . "/typekey_lib.php";
#    my $typekey_lib_dynamic = $blog->site_path . "/typekey_lib_dynamic.php";
    my $mt_pass = $blog->site_path . "/mt-password.php";
    my $openid = $blog->site_path . "/openid.php";
    if($type eq 'install') {
        my $url = 'http://www.movalog.com/downloads/MT-Protect/Auth_Typekey.txt';
        my $auth_tk_text = _load_link ( $url );
        
        if (open(TARGET, ">$auth_typekey")) {
            print TARGET $auth_tk_text;
            close TARGET;
            } else {
            die;
        }
        
        $url = 'http://www.movalog.com/downloads/MT-Protect/typekey_lib.txt';
        $auth_tk_text = _load_link ( $url );
        
        if (open(TARGET, ">$typekey_lib")) {
            print TARGET $auth_tk_text;
            close TARGET;
            } else {
            die;
        }
        
        $url = 'http://www.movalog.com/downloads/MT-Protect/openid.php.txt';
        $auth_tk_text = _load_link ( $url );
        
        if (open(TARGET, ">$openid")) {
            print TARGET $auth_tk_text;
            close TARGET;
            } else {
            die;
        }        
        
#        $url = 'http://www.movalog.com/downloads/MT-Protect/typekey_lib_dynamic.txt';
#        $auth_tk_text = _load_link ( $url );
#        
#        if (open(TARGET, ">$typekey_lib_dynamic")) {
#            print TARGET $auth_tk_text;
#            close TARGET;
#            } else {
#            die;
#        }        
        
        $url = 'http://www.movalog.com/downloads/MT-Protect/mt-pass.txt';
        $auth_tk_text = _load_link ( $url );
        
                    require MT::Builder;
                    require MT::Template::Context;
                
                    my $build = MT::Builder->new;
                    my $ctx = MT::Template::Context->new;
                                $ctx->{__stash}{blog} = $blog;
                    my $tokens = $build->compile($ctx, $auth_tk_text)
                        or die $build->errstr;
                    defined(my $out = $build->build($ctx, $tokens))
                        or die $build->errstr;
                        
        if (open(TARGET, ">$mt_pass")) {
            print TARGET $out;
            close TARGET;
            } else {
            die;
        }                    
                    
        my $data = MT::PluginData->new;
        $data->plugin('Protect');
        $data->key($blog_id);
        $data->data({ status => "Installed" });
        $data->save or
        return $app->error("Error: " . $data->errstr);
        $q->param('installed', 1);
        } elsif($type eq 'uninstall') {
        if (-f $auth_typekey) {
            if (unlink $auth_typekey) {
                $app->log("Deleted Auth_Typeky.php");
            }
        }
        if (-f $typekey_lib) {
            if (unlink $typekey_lib) {
                $app->log("Deleted typekey_lib.php");
            }
        }
#        if (-f $typekey_lib_dynamic) {
#            if (unlink $typekey_lib_dynamic) {
#                $app->log("Deleted typekey_lib_dynamic.php");
#            }
#        }    
        if (-f $mt_pass) {
            if (unlink $mt_pass) {
                $app->log("Deleted mt-pass.php");
            }
        } 
        if (-f $openid) {
            if (unlink $openid) {
                $app->log("Deleted openid.php");
            }
        }                     
        my $pdblog = MT::PluginData->load({ plugin => 'Protect', key    => $blog_id });
        $pdblog->remove;
        $q->param('uninstalled', 1);
    }
    $app->redirect($app->{mtscript_url}.'?__mode=list_plugins');
}

sub edit {
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }    
    my $q = $app->{query};
    my ($param, $tmpl, $entry, @typekey_data,@openid_data);
    my $blog_id = $q->param('blog_id');
    my $id = $q->param('id');
    my $type = $q->param('_type') || $q->param('from');

    if($type eq 'entry' || $type eq 'edit_entry') {  	
    	my $entry_ids = $q->param('entry_ids');
	    $param->{entry_id} = $id || $entry_ids;   
	    $app->add_breadcrumb($app->translate('Entries'), $app->{mtscript_url} . '?__mode=list_entries&blog_id=' . $blog_id); 	
        $tmpl = 'entry.tmpl';
        if($id) {
        	$param->{is_single} = 1;
        	
		    my $entry = MT::Entry->load($id);
		    $app->add_breadcrumb($entry->title || $app->translate('(untitled)'), $app->{mtscript_url} . '?__mode=view&_type=entry&id=' . $id . '&blog_id=' . $blog_id);
		    $param->{entry_title} = $entry->title;        	
        my $data = Protect::Protect->load({entry_id    => $id });
        if($data){
            my $data_type = $data->type;
            if($data_type eq 'Password'){
                $param->{is_password} = 1;
                my $password = $data->data;
                $param->{password} = $password;
            }
            elsif($data_type eq 'Typekey'){
                $param->{is_typekey} = 1;
                my $users = $data->data;
                for my $user (@$users) {               
                    push @typekey_data, {
                        user => $user
                    };
                }
            }
            elsif($data_type eq 'OpenID'){
                $param->{is_openid} = 1;
                my $users = $data->data;
                for my $user (@$users) {               
                    push @openid_data, {
                        user => $user
                    };
                }
            }            
        }
      }
				for (my $i = 1; $i <= 5; $i++) {push @typekey_data, {user => ''};}
				for (my $i = 1; $i <= 5; $i++) {push @openid_data, {user => ''};}

        
        
        $app->add_breadcrumb("Protect");
  } elsif($type eq 'blog' || $type eq 'blog_home'){
  			my $blog_ids = $q->param('blog_ids');
  			$param->{blog_ids} = $blog_ids;
        $tmpl = 'blog.tmpl';
        if($blog_id) {
        	$param->{is_single} = 1;
        my $blog = MT::Blog->load($blog_id);	
        $param->{blog_name} = $blog->name;	
        my $data = Protect::Protect->load({entry_id    => '0', blog_id => $blog_id });
        if($data){
            my $data_type = $data->type;
            if($data_type eq 'Password'){
                $param->{is_password} = 1;
                my $password = $data->data;
                $param->{password} = $password;
            }
            elsif($data_type eq 'Typekey'){
                $param->{is_typekey} = 1;
                my $users = $data->data;

                for my $user (@$users) {                  
                    push @typekey_data, {user => $user};
                }
            }
            elsif($data_type eq 'OpenID'){
                $param->{is_openid} = 1;
                my $users = $data->data;

                for my $user (@$users) {                  
                    push @openid_data, {user => $user};
                }
            }            
        }
      }
      for (my $i = 1; $i <= 5; $i++) {push @typekey_data, {user => ''};}
      for (my $i = 1; $i <= 5; $i++) {push @openid_data, {user => ''};}

    $app->add_breadcrumb("Protect Blog");        
  } elsif($type eq 'groups') {
                my $author_ids = $q->param('author_id');
                my @authors_list = split(/,/,$author_ids);
                shift @authors_list;
      for my $author_id (@authors_list) {
        if($author_id ne 'undefined') {
                my $commenter = MT::Author->load($author_id);
       
          push @typekey_data, {user => $commenter->name};
        }
      }
                        $param->{add} = 1 if $q->param('add') == 1;
                        $param->{edit} = 1 if $q->param('edit') == 1;
                        my $data = Protect::Groups->load({id => $id });
                        if($data){
                        $param->{id} = $data->id;
                        $param->{label} = $data->label;
                        $param->{description} = $data->description;
                        my $grouptype = $data->type;
                        $param->{"$grouptype"} = 1;
                        my $users = $data->data;
      for my $user (@$users) {       
          push @typekey_data, {user => $user};
      }
    
   }
			for (my $i = 1; $i <= 5; $i++) {push @typekey_data, {user => ''};}
			

      $tmpl = 'tk_edit.tmpl';                
      $app->add_breadcrumb("MT Protect",$app->{mtscript_url}.'?__mode=list_plugins');
                $app->add_breadcrumb("Typekey Groups",'mt-protect.cgi?__mode=tk_groups');
                $app->add_breadcrumb("Add New Group") if $q->param('add') == 1;
                $app->add_breadcrumb("Edit Group") if $q->param('edit') == 1;        
  }
    $param->{typekey_user_loop} = \@typekey_data;
    $param->{openid_user_loop} = \@openid_data;
    $param->{message} = $q->param('message');
    $app->build_page($tmpl, $param);
}

sub save {
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }    
    my $q = $app->{query};
    my $blog_id = $q->param('blog_id'); 
    my($param,$tmpl,@typekey_data,$data,$uri,$message); 
    my $type = $q->param('_type');
    if($type eq 'entry') {
    	my $entryid = $q->param('id');
	   my $entry_ids = $q->param('entry_ids');
	   my @entry_list = split(/,/,$entry_ids);
	   shift @entry_list; 
	   push @entry_list, $entryid
	   	if !$entry_ids; 
        my $protection = $q->param('protection');
   for my $entry_id (@entry_list) {
   	if($entry_id ne 'undefined') {  
    unless($data = Protect::Protect->load({ entry_id   => $entry_id })){
            $data = Protect::Protect->new;
            $data->blog_id($blog_id);
            $data->entry_id($entry_id);
            $data->created_by($app->{author}->id);
        }
        if($protection eq 'Password') {
            $data->type($protection);
            my $password = $q->param('password');
            $data->data($password);
            $message = $app->translate('Entry now password protected');
            $app->log("'" . $app->{author}->name . "' password protected entry #".$entry_id);
          } 
          elsif($protection eq 'Typekey') {
            $message = $app->translate('Entry now Typekey protected');  
            $app->log("'" . $app->{author}->name . "' Typekey protected entry #".$entry_id);              
            $data->type($protection);
            my @users;
            for my $user ($q->param('typekey_users')) {
                if($user && $user ne ""){
                    push (@users, $user);
                }
            }
            $data->data(\@users);
        }
          elsif($protection eq 'OpenID') {
            $message = $app->translate('Entry now OpenID protected');  
            $app->log("'" . $app->{author}->name . "' OpenID protected entry #".$entry_id);              
            $data->type($protection);
            my @users;
            for my $user ($q->param('openid_users')) {
                if($user && $user ne ""){
                    push (@users, $user);
                }
            }
            $data->data(\@users);
        }        
        if($protection eq 'None') {
                $data->remove or
            return $app->error("Error: " . $data->errstr);
          $message = $app->translate('Protection Removed');  
          $app->log("'" . $app->{author}->name . "' removed protection on entry #".$entry_id);
        } else {      
        $data->save or
            return $app->error("Error: " . $data->errstr);        	
        }
           
        
      }
      }
    if($entryid) {  
		$uri = $app->uri.'?__mode=edit&_type=entry&blog_id='.$blog_id.'&id='.$entryid.'&message='.$message;      
	} else {
		$uri = $app->mt_uri.'?__mode=list_entries&blog_id='.$blog_id.'&saved=1';
	}
    } elsif($type eq 'blog') {
        my $entry_id = '0';
        my $protection = $q->param('protection');
    	my $blogid = $q->param('blog_id');
	   my $blog_ids = $q->param('blog_ids');
	   my @blog_list = split(/,/,$blog_ids);
	   shift @blog_list; 
	   push @blog_list, $blogid
	   	if !$blog_ids;   
   for my $blid (@blog_list) {
   	if($blid ne 'undefined') {  	   	      
    unless($data = Protect::Protect->load({ entry_id   => $entry_id, blog_id => $blid })){
            $data = Protect::Protect->new;
            $data->blog_id($blid);
            $data->entry_id($entry_id);
            $data->created_by($app->{author}->id);
        }
        if($protection eq 'Password') {
            $data->type($protection);
            my $password = $q->param('password');
            $data->data($password);
            $message = $app->translate('Blog now password protected');
            $app->log("'" . $app->{author}->name . "' password protected blog #".$blid);
          } 
          elsif($protection eq 'Typekey') {
            $message = $app->translate('Blog now Typekey protected'); 
            $app->log("'" . $app->{author}->name . "' Typekey protected blog #".$blid);               
            $data->type($protection);
            my @users;
            for my $user ($q->param('typekey_users')) {
                if($user && $user ne ""){
                    push (@users, $user);
                }
            }
            $data->data(\@users);
        }
          elsif($protection eq 'OpenID') {
            $message = $app->translate('Blog now OpenID protected'); 
            $app->log("'" . $app->{author}->name . "' OpenID protected blog #".$blid);               
            $data->type($protection);
            my @users;
            for my $user ($q->param('openid_users')) {
                if($user && $user ne ""){
                    push (@users, $user);
                }
            }
            $data->data(\@users);
        }        
        $data->save or
            return $app->error("Error: " . $data->errstr);
        if($protection eq 'None') {
                $data->remove or
            return $app->error("Error: " . $data->errstr);
          $message = $app->translate('Protection Removed'); 
          $app->log("'" . $app->{author}->name . "' removed protection on blog #".$blid); 
        } else {
        $data->save or
            return $app->error("Error: " . $data->errstr);        	
        }
       } } 
    if($blogid) {  
		$uri = $app->uri.'?__mode=edit&_type=blog&blog_id='.$blog_id.'&message='.$message;      
	} else {
		$uri = $app->mt_uri.'?__mode=system_list_blogs&saved=1';
	}          
			
    }elsif($type eq 'groups') {
        my $label = $q->param('label');
        my $description = $q->param('desc');
        my $grouptype = $q->param('type');
        my $id = $q->param('id');
            unless($data = Protect::Groups->load({ id   => $id })){
                    $data = Protect::Groups->new;
                }        
                $data->label($label);
                $data->description($description);
                $data->type($grouptype);
            my @users;
            for my $user ($q->param('users')) {
                if($user && $user ne ""){
                    push (@users, $user);
                }
            }
            $data->data(\@users);
            $data->save or
            return $app->error("Error: " . $data->errstr);
            $message = $app->translate('Typekey group saved');
            $id = $data->id;
            $q->param('edit',1);
            $uri = $app->uri.'?__mode=edit&_type=groups&id='.$id.'&message='.$message.'&edit=1';                
    }
   $app->redirect($uri); 
}

sub tk_groups {
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }    
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
                                type => $entry->type,
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
  $app->add_breadcrumb("Typekey Groups");
  $app->build_page('tk_groups.tmpl',$param);
}

sub list_entries {
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }    
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
    $app->add_breadcrumb('Entries', $app->{mtscript_url} . '?__mode=list_entries&blog_id=' . $blog->id);
    $app->add_breadcrumb($app->translate('Protected Entries'));                
        $app->build_page('list.tmpl',$param);    
}

sub delete
{
    debug("Calling delete_entry...");
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }    
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
        $q->param('message','Groups removed');
        foreach my $key ($q->param('id')) {
            my $data = Protect::Protect->load({ entry_id    => $key });
            $data->remove or return $app->error("Error: " . $data->errstr);
        }
     list_entries($app);        
    }
    
}

sub confirm_delete {
    my $app = shift;
   unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
			schema_check($app);
   }    
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

sub notice {
	my $app = shift;
	my $q = $app->{query};
	my $tmpl = $q->param('do').'.tmpl';
	my $param;
	$param->{instup} = 1;
	$param->{blog_id} = $q->param('blog_id');
	$param->{id} = $q->param('id');
	$param->{type} = $q->param('_type');
  unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
   	
	$param->{schema_version} = $app->{schema_version};
	$app->add_breadcrumb("MT Protect");		
	if($q->param('do') eq 'install') {
	$app->add_breadcrumb("Install");
	$param->{blogroll_install} = 1;
	$param->{install_mode} = 1;
} elsif($q->param('do') eq 'upgrade') {
$app->add_breadcrumb("Upgrade")};		
	$app->build_page($tmpl,$param);
	} else {
	$param->{up_to_date} = 1;
	$app->build_page('upgrade_runner.tmpl',$param);
	}
} 

sub doinstallupgrade {
	my $app = shift;
	my $q = $app->{query};
  my $install_mode = $q->param('install_mode');	
  my $dbh = MT::Object->driver->{dbh};

  $q->param('DryRun',1);
  if($install_mode) {
  run_install($app);
} else {
	run_upgrade($app);
}

  my $steps = $app->response->{steps};  
  my $json_steps;  
    if ($steps && @$steps) {
        $json_steps = objToJson($steps);
    }

    my $param = {
        installing => $install_mode,
        up_to_date => $json_steps ? 0 : 1,
        initial_steps => $json_steps,
        blog_id => $q->param('blog_id'),
        id => $q->param('id'),
        type => $q->param('_type'),
    };

    return $app->build_page('upgrade_runner.tmpl', $param);
  } 

sub run_upgrade {
	my $app = shift;
	$app->{upgrading} = 1;
	my $q = $app->{query};
  my $dbh = MT::Object->driver->{dbh};	
  my $driver = MT::Object->driver;
  my $schema_version;
	$schema_version = 1.0
			unless(has_column($dbh, 'mt_protect_groups', 'protect_groups_id'));	
	$schema_version = 1.1
			unless(has_column($dbh, 'mt_protect_groups', 'protect_groups_type'));			
  my @stmts;	
	my $param;
  unless (MT::PluginData->load({ plugin => 'MT Protect', key => 'setup_'.$SCHEMA_VERSION })) {
  if($schema_version == 1.0) {
	push @stmts, <<CREATE,
create table mt_protect_groups (
	protect_groups_id integer not null auto_increment primary key,
	protect_groups_label varchar(100) not null,
	protect_groups_description varchar(255),
	protect_groups_data mediumtext,
	index (protect_groups_label),
	unique(protect_groups_label)
	)
CREATE
  }
  
   if($schema_version <= 1.1) { 
   	if(!$q->param('DryRun')) {
   my $iter = Protect::Protect->load_iter;
   while (my $entry = $iter->()) {    
   	if($entry->type eq 'Typekey') {
      my $users = $entry->data;
      my @data;
      for my $user (@$users) {               
				push (@data, $user);
      }
      $entry->data(\@data);
    } elsif($entry->type eq 'Password') {
    	my $pass = $entry->password;
    	$entry->data($pass);
    }
      $entry->save or $app->upgrade_error($entry->errstr);   		
  }
   $iter = Protect::Groups->load_iter;
   while (my $entry = $iter->()) {    
      my $users = $entry->data;
      my @data;      
      for my $user (@$users) {               
				push (@data, $user);
      }
      $entry->data(\@data);
      $entry->save or $app->upgrade_error($entry->errstr);   		
  }
    
   my $data = MT::PluginData->new;
   $data->plugin('MT Protect');
   $data->key('setup_'.$SCHEMA_VERSION);
   $data->data(\1);
   $data->save or $app->upgrade_error("Unable to save setup confirmation $data->errstr");
 }
  
	@stmts = add_once(\@stmts, $dbh, 'mt_protect_groups', 'protect_groups_type', 'varchar(10) not null');	
}
  if(!$q->param('DryRun')) {
  	$app->{no_print_body} = 1;
		$app->send_http_header('text/plain');
    for my $sql (@stmts) {
        $dbh->do($sql) or $app->print($dbh->errstr . " on $sql");
        $app->print($sql."\n"); 
    } 
  }
}
 $app->response->{steps} = \@stmts
 	if($q->param('DryRun'));
	$app->json_response;
	return $app->upgrade_finish;
}   

sub run_install {
	my $app = shift; 
	my $q = $app->{query};
	my @stmts;
if ($app->{cfg}->ObjectDriver =~ /^DBI::(.*)$/) {
    my $type = $1;
    my $dbh = MT::Object->driver->{dbh};
    my $schema = File::Spec->catfile($app->{mt_dir}, 'plugins','Protect','schemas', 'Protect_schema.'.$type);
    open FH, $schema or $app->upgrade_error("Can't open schema file '$schema': $!\n");
    my $ddl;
    { local $/; $ddl = <FH> }
    close FH;
    @stmts = split /;/, $ddl;
  if(!$q->param('DryRun')) {
  	$app->{no_print_body} = 1;
  		$app->send_http_header('text/plain');    
    for my $stmt (@stmts) {
        $stmt =~ s!^\s*!!;
        $stmt =~ s!\s*$!!;
        next unless $stmt =~ /\S/;
        $app->print($stmt."\n");        
        $dbh->do($stmt) or $app->upgrade_error($dbh->errstr."\n");
    }
      
	$app->print("Saving setup configuration and schema settings\n");	
		  
   my $data = MT::PluginData->new;
   $data->plugin('MT Protect');
   $data->key('setup_'.$SCHEMA_VERSION);
   $data->data(\1);
   $data->save or $app->upgrade_error("Unable to save setup confirmation", $data->errstr);    

	$app->print("Installed MT Protect v".$VERSION." schema version ".$SCHEMA_VERSION."\n");    
  }
}

 $app->response->{steps} = \@stmts
 	if($q->param('DryRun'));
	$app->json_response;

	return $app->upgrade_finish;
}

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub schema_check {
	my $app = shift;
	my $dbh = MT::Object->driver->{dbh};
  my $sversion = $SCHEMA_VERSION; 
  my $driver = MT::Object->driver;
  my $type = $app->{query}->param('_type') || $app->{query}->param('from');
  my $uri = $app->uri.'?__mode=notice&do=install&blog_id='.$app->{query}->param('blog_id');
  if ($app->{cfg}->ObjectDriver =~ /mysql/) {
		$sversion = 1.0
			unless(has_column($dbh, 'mt_protect_groups', 'protect_groups_id'));
			
		$sversion = 1.1
			unless(has_column($dbh, 'mt_protect_groups', 'protect_groups_type'));
    
    $uri = $app->uri.'?__mode=notice&do=upgrade&blog_id='.$app->{query}->param('blog_id').'&id='.$app->{query}->param('id').'&_type='.$type
    	if($sversion < $SCHEMA_VERSION);     	
} 
$app->redirect($uri)
	if $uri;    	
}

sub add_once {
    my ($stmts, $dbh, $table, $col, $type) = @_;
    
    push @$stmts, "alter table $table add $col $type"
        unless has_column($dbh, $table, $col);
    return @$stmts;
}

sub has_column
{
    my ($dbh, $table, $column) = @_;

    my $sth = $dbh->prepare("describe $table");
    if ($sth && $sth->execute()) {
	my $ddl = $sth->fetchall_arrayref();

	my @columns = map { $$_[0] } @$ddl;

	return (grep { $_ =~ /$column/ } @columns) ? 1 : 0;
    } else {
	$sth = $dbh->prepare("select $column from $table");
	$sth->execute() or return 0;
	return 1;
    }
}

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

sub json_response {
    my $app = shift;
    $app->print(' JSON:' . objToJson($app->response));
}

sub response {
    my $self = shift || MT->instance;
    if (!$self->{response}) {
        $self->{response} = { steps => [], progress => [], error => undef };
    }
    $self->{response};
}

sub upgrade_error {
    my $app = shift;
    my ($msg) = @_;
    $app->SUPER::error(@_);
    $app->response->{steps} = $msg;
    $app->response->{error} = $msg;
	die $app->json_response;
}

sub upgrade_finish {
    my $app = shift;

    $app->login;
    if ($app->{author}) {
        require MT::Author;
        my $author = MT::Author->load($app->{author}->id);
        my $cookie_obj = $app->start_session($author);
        my $response = $app->response;
        $response->{cookie} = { map { $_ => $cookie_obj->{$_} } (keys %$cookie_obj) };
        $app->log("User " . $app->{author}->name .
                  " upgraded MT Protect to version " . $VERSION);
    }    
}
1; 
