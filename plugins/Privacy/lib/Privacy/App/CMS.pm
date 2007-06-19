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

# This is called after an object is saved in the CMS
# It takes into account any changes the user may have made manually
# that are different to the defaults set on post_insert
sub cms_post_save {
    my ($plugin, $cb, $app, $obj) = @_;
	my $q = $app->param;
	my $blog_id = $q->param('blog_id');
	
	 # If the user *had* manually changed the privacy, this would be set
	return if !$q->param('privacy_manual');
	
	# Lets start fresh
	require Privacy::Object;
	my @orig_privacy = Privacy::Object->load({ blog_id => $blog_id, 
												object_id => $obj->id, object_datasource => $obj->datasource });
	$_->remove or die $_->errstr foreach @orig_privacy;
	
	foreach ($q->param()) {
        if (m/^privacy_(.*?)$/) {
			next if $1 eq 'manual';
			
			my $key = $1;
			my @creds = split ', ', $q->param("privacy_$key");
			
			foreach my $cred (@creds) {
				my $privacy = Privacy::Object->new;
				$privacy->set_values({
					blog_id => $blog_id,
					object_id => $obj->id,
					object_datasource => $obj->datasource,
					type => $key,
					credential => $cred
				});
				$privacy->save or die $privacy->errstr;
			}
        }
    }
}

1;