# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007 Arvind Satyanarayan.

package Privacy::Util;

use Exporter;
@Privacy::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( auth_loop get_credentials );

# This routine gives us an array of all the authenticators Privacy can use
sub auth_loop {
	my ($param) = @_;
	
	require MT::Blog;
	my $blog = MT::Blog->load($param->{blog_id});
	
	# Get all available commenter authentications (which will be used by Privacy)
	# and those enabled for this blog as those will be the only ones the user can
	# choose from. Mostly taken from MT::App::Comments::login
	my $ca_reg = MT->registry("commenter_authenticators");
	my @auths = split ',', $blog->commenter_authenticators;
	
	# Manually add Password and Group authenticators - these are only used by Privacy
	# P.S. Group defaults to Privacy::Group if MT::Group is not available
	unshift @auths, ('Password', 'Group');
	my $is_private;
	
	foreach my $key (@auths) {
		my $auth = $ca_reg->{$key};
		
		$param->{key} = $key;
		my @credentials = get_credentials($param);
		$is_private = 1 if scalar @credentials > 0;
		
		push @auth_loop, {
			label => $auth ? $auth->{label} : $key,
			key => $key,
			credentials => join ", ", @credentials
		};
	}

	return $param->{is_private} ? (@auth_loop, $is_private) : @auth_loop;
}

sub get_credentials {
	my ($param) = @_;
	
	my $blog_id = $param->{blog_id};
    my $obj_type = $param->{object_type};
    my $id = $param->{object_id};
	my $key = $param->{key};
	
	# This could be an expensive process, so don't run it unless we asked
	return ('') unless $param->{require_credentials};

	# We need to load the credentials ("allowed users") associated with this authenticator
	# First, pretend this is a new object and try to see if any privacy defaults have  
	# been set at the blog level
	my $terms = {
		blog_id => $blog_id,
		object_id => $blog_id,
		object_datasource => 'blog',
		type => $key
	};
	
	if($id) {
		# However, if it isn't a new object then there's no need to load blog level defaults
		# because this object will already have its own custom privacy settings 
		# (whether those be defaults or not)
		$terms->{object_id} = $id;
		$terms->{object_datasource} = $obj_type;
	}
	
	require Privacy::Object;
	my @creds = Privacy::Object->load($terms);
	my @credentials;
	
	push @credentials, $_->credential
		foreach @creds;
	
	return @credentials;
}


1;