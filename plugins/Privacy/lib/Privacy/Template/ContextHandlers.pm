# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::Template::ContextHandlers;
use strict;
use Privacy::Util qw( auth_loop );

sub _hdlr_app_privacy {
	my ($plugin, $ctx, $args, $cond) = @_;
	
	$args->{blog_id} = $ctx->var('blog_id');
	$args->{object_type} = $ctx->var('object_type');
	$args->{object_id} = $ctx->var('id');
	$args->{require_credentials} = 1;
	$args->{is_private} = 1;
	
	my (@auth_loop) = auth_loop($args);

	$ctx->var('is_private', pop @auth_loop);
	$ctx->var('auth_loop', \@auth_loop);
	
	if($ctx->var('object_type') eq 'entry') {
		require Privacy::Object;
		# Populate category privacy defaults
		my $cat_tree = $ctx->var('category_tree');
		my @category_defaults;
		foreach my $cat (@$cat_tree) {
			my $id = $cat->{id};
			my $privacy = { id => $id };
			my $iter = Privacy::Object->load_iter({ object_id => $id, object_datasource => 'category' });
			while (my $cred = $iter->()) {
				my $key = $cred->type;
				$privacy->{$key} ||= [];
				push @{$privacy->{$key}}, $cred->credential;
			}
			push @category_defaults, $privacy;
		}	
		$ctx->var('category_defaults', \@category_defaults);	
	}

	my $privacy_tmpl = $args->{tmpl} || File::Spec->catdir($plugin->path,'tmpl','privacy_setting.tmpl');

    return $ctx->build(<<"EOT");
<mt:include name="$privacy_tmpl">
EOT
}


1;