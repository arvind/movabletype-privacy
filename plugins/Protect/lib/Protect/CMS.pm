# Protect Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Arvind Satyanarayan
#

package Protect::CMS;
use strict;

use vars qw( $DEBUG $VERSION @ISA $USE_SEARCH_PATH_HACK );
@ISA = qw(MT::App::CMS);
$VERSION = '1.0b1';

use MT::PluginData;
use MT::Util qw( format_ts offset_time_list );
use MT::ConfigMgr;
use MT::App::CMS;
use MT;
use MT::Permission;
use Protect::Protect;

sub init
{
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;
    $app->add_methods(
    'global_config'       => \&config_global,
    'install'             => \&install,
    'edit'                => \&edit,
    'save'                => \&save,
    'list_entries'        => \&list,
    );
    
    
    $app->{plugin_template_path} = File::Spec->catdir('plugins','Protect','tmpl');
    $app->{default_mode}   = 'edit';
    $app->{user_class}     = 'MT::Author';
    $app->{requires_login} = 1;
    $app->{mtscript_url}   = $app->{cfg}->CGIPath . $app->{cfg}->AdminScript;
    $app;
}

sub build_page {
    
    my $app = shift;
    my $q = $app->{query};
    my($page, $param) = @_;
    $param->{plugin_name       } =  "Protect";
    $param->{plugin_version    } =  $VERSION;
    $param->{plugin_author     } =  "Arvind Satyanarayan";
    $param->{mtscript_url      } =  $app->{mtscript_url};
    $param->{script_full_url   } =  $app->base . $app->uri;
    $param->{mt_version        } =  MT->VERSION;
    $param->{language_tag      } =  $app->current_language;
    $param->{author_name       } =  $app->{author}->name;
    $app->SUPER::build_page($page, $param);
}

sub config_global {
    my $app = shift;
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
    $app->build_page('config.tmpl', $param);
}

sub install {
    my $app = shift;
    my $q = $app->{query};
    my $blog_id = $q->param('cblog_id');
    my $type = $q->param('_type');
    my $blog = MT::Blog->load($blog_id);
    my $auth_typekey = $blog->site_path . "/Auth_TypeKey.php";
    my $typekey_lib = $blog->site_path . "/typekey_lib.php";
    my $mt_pass = $blog->site_path . "/mt-protect.php";
    if($type eq 'install') {
        my $url = 'http://www.movalog.com/archives/plugins/protect/Auth_Typekey.txt';
        my $auth_tk_text = _load_link ( $url );
        
        if (open(TARGET, ">$auth_typekey")) {
            print TARGET $auth_tk_text;
            close TARGET;
            } else {
            die;
        }
        
        $url = 'http://www.movalog.com/archives/plugins/protect/typekey_lib.txt';
        $auth_tk_text = _load_link ( $url );
        
        if (open(TARGET, ">$typekey_lib")) {
            print TARGET $auth_tk_text;
            close TARGET;
            } else {
            die;
        }
        
        $url = 'http://www.movalog.com/archives/plugins/protect/mt-pass.txt';
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
                $app->log("Deleted Auth_Typeky.php");
            }
        }
        my $pdblog = MT::PluginData->load({ plugin => 'Protect', key    => $blog_id });
        $pdblog->remove;
        $q->param('uninstalled', 1);
    }
    config_global($app);
}

sub edit {
    my $app = shift;
    my $q = $app->{query};
    my $param;
    my $tmpl;
    my @data;
    my $blog_id = $q->param('blog_id');
    my $entry_id = $q->param('id');
    my $blog = MT::Blog->load($blog_id);
    my $entry = MT::Entry->load($entry_id);
    $param->{entry_title} = $entry->title;
    $param->{entry_id} = $entry_id;
    my $type = $q->param('_type');
    if($type eq 'entry') {
        $tmpl = 'edit_entry.tmpl';
        my $data = Protect::Protect->load({entry_id    => $entry_id });
        if($data){
            my $data_type = $data->type;
            if($data_type eq 'Password'){
                $param->{is_password} = 1;
                my $password = $data->password;
                $param->{password} = $password;
            }
            elsif($data_type eq 'Typekey'){
                $param->{is_typekey} = 1;
                my $users = $data->data;
                for my $user (@$users) {
                    my $row = {
                        user => $user
                    };
                    
                    push @data, $row;
                }
            }
        }
        for (my $i = 1; $i <= 5; $i++) {
            push @data, $i;
        }
        $param->{message} = $q->param('message');
        $param->{typekey_user_loop} = \@data;
        $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
        $app->add_breadcrumb($app->translate('Entries'), $app->{mtscript_url} . '?__mode=list_entries&blog_id=' . $blog_id);
        $app->add_breadcrumb($entry->title || $app->translate('(untitled)'), $app->{mtscript_url} . '?__mode=view&_type=entry&id=' . $entry_id . '&blog_id=' . $blog_id);
        $app->add_breadcrumb("Password Protect");
  }
    $app->build_page($tmpl, $param);
}

sub save {
    my $app = shift;
    my $q = $app->{query};
    my $param;
    my $tmpl;
    my @data;
    my $type = $q->param('_type');
    if($type eq 'entry') {
        my $blog_id = $q->param('blog_id');
        my $entry_id = $q->param('id');
        my $protection = $q->param('protection');
        my $data;
    unless($data = Protect::Protect->load({ entry_id   => $entry_id })){
            $data = Protect::Protect->new;
            $data->blog_id($blog_id);
            $data->entry_id($entry_id);
            $data->created_by($app->{author}->id);
        }
        if($protection eq 'Password') {
            $data->type($protection);
            my $password = $q->param('password');
            $data->password($password);
            $q->param('message', 'Entry now password protected');
          } 
          elsif($protection eq 'Typekey') {
            $q->param('message', 'Entry now Typekey protected');            	
            $data->type($protection);
            my @users;
            for my $user ($q->param('typekey_users')) {
                if($user && $user ne ""){
                    push (@users, $user);
                }
            }
            $data->data(\@users);
        }
        $data->save;
        edit($app);
    }
    
}

sub list_entries {
    my $app = shift;
    my $q = $app->{query};	
		my $blog_id = $q->param('blog_id');
		my $param;
#		my $iter = Protect::Protect->load_iter({ blog_id = $blog_id });
#		while (my $ntry = $iter->()) {
#			my $entry = MT::Entry->load($ntry->id);
#		} 
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

1; 