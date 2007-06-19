# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::App::CMS;
use strict;

use Privacy::Util qw( auth_loop );

# This routine creates the Privacy Editor (dialog box)
sub edit_privacy {
	my ($plugin, $app) = @_;
	
	my @auth_loop = auth_loop({ blog_id => $app->param('blog_id') });
	
	return $app->build_page($plugin->load_tmpl('privacy_editor.tmpl'), 
												{ auth_loop => \@auth_loop,
													object_type => $app->param('_type') });
}

1;