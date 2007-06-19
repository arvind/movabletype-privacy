# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::Template::ContextHandlers;
use strict;
use Privacy::Util qw( auth_loop );

sub _hdlr_app_privacy {
	my ($plugin, $ctx, $args, $cond) = @_;
	
	$args->{blog_id} = $ctx->var('blog_id');
	$args->{object_type} = $ctx->var('object_type');
	$args->{require_credentials} = 1;
	my @auth_loop = auth_loop($args);
	
	$ctx->var('auth_loop', \@auth_loop);

	my $privacy_tmpl = $args->{tmpl} || File::Spec->catdir($plugin->path,'tmpl','privacy_setting.tmpl');

    return $ctx->build(<<"EOT");
<mt:include name="$privacy_tmpl">
EOT
}


1;