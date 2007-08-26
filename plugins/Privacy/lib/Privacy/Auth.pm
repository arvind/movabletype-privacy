# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::Auth;
use strict;

# Really just a placeholder so we can graft on the routines for
# MT::Auth classes below!

package MT::Auth::OpenID;
use strict;

sub get_credential {
	my $class = shift;
	my ($app, $cmntr) = @_;
	my $credential = $cmntr->url;
	if($class->can('url_for_userid')) {
		my $expr = $class->url_for_userid('(.*)');
		($credential) = $cmntr->url =~ m/$expr/;
	}
			
	return $credential;	
}

package MT::Auth::Typekey;
use strict;

sub get_credential {
	my $class = shift;
	my ($app, $cmntr) = @_;

	return $cmntr->name;	
	
}

1;