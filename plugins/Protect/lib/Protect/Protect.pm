# Blogroll Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Arvind Satyanarayan
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# This program was based largely upon the plugin written by Byrne Reese.
# The original program can be found at the following URL:
# http://www.majordojo.com/projects/BookQueueToo/

package Protect::Protect;
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

sub init
{
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;
    $app->add_methods(
    'global_config'       => \&config_global,
    'install'             => \&install,
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

1;