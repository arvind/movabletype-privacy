# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::Auth;
use strict;

# Really just a placeholder so we can graft on the routines for
# MT::Auth classes below!

package MT::Auth::OpenID;
use strict;

sub handle_privacy {
	my $class = shift;
	my ($app, $cmntr) = @_;
	my $credential = $cmntr->url;
	if($class->can('url_for_userid')) {
		my $expr = $class->url_for_userid('(.*)');
		($credential) = $cmntr->url =~ m/$expr/;
	}
	
	my $key = $app->param('key');
	my $blog_id = $app->param('blog_id');
	my ($object_type, $object_id) = split '::', $app->param('static');

	require Privacy::Object;
	my $count = Privacy::Object->count({ blog_id => $blog_id, type => $key, object_datasource => $object_type, 
											object_id => $object_id, credential => $credential });
											
	return $count;	
}

package MT::Auth::Typekey;
use strict;

sub handle_privacy {
	my $class = shift;
	my ($app, $cmntr) = @_;
	
	my $key = $app->param('key') || 'TypeKey';
	my $blog_id = $app->param('blog_id');
	my ($object_type, $object_id) = split '::', $app->param('static');
	my $credential = $cmntr->name;
	
	require Privacy::Object;
	my $count = Privacy::Object->count({ blog_id => $blog_id, type => $key, object_datasource => $object_type, 
											object_id => $object_id, credential => $credential });
											
	return $count;	
	
}

1;