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

sub _hdlr_private {
	my ($plugin, $ctx, $args, $cond) = @_;
	my ($obj_type) = lc($ctx->stash('tag'))  =~ m/private(.*)/;
	my $blog_id = $ctx->stash('blog_id');
	
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    defined (my $contents = $builder->build($ctx, $tokens, $cond))
      or return $ctx->error ($builder->errstr);

	# Get the actual object that has been protected
	my $obj = ($obj_type eq 'category') ? $ctx->stash('category') || $ctx->stash('archive_category') : $ctx->stash($obj_type);
	local $ctx->{__stash}{private_obj} = $obj;
	
	return _no_private_obj($ctx, $ctx->stash('tag'))
		if !$obj;
		
	require Privacy::Object;
	my $protected = Privacy::Object->count({ blog_id => $blog_id, 
												object_id => $obj->id, object_datasource => $obj->datasource });
	
	# Return the contents of the block tag if the object hasn't been protected											
	return $contents if !$protected;
	
	my $signin = $ctx->build($plugin->get_config_value('signin', "blog:$blog_id"), undef);
	my $signout = $ctx->build($plugin->get_config_value('signout', "blog:$blog_id"), undef);
	my $use_php = $plugin->get_config_value('use_php', "blog:$blog_id");
	my $obj_id = $obj->id;
	
	my $out;
	if($use_php) {
		$out = <<OUT;
<?php if(\$_COOKIE['$obj_type$obj_id']) { ?>
	$signout
	$contents
<?php } else { ?>
	$signin
<?php } ?>
OUT
	} else {
		my $app = MT->instance;
		my $cookies = $app->{cookies};
		my $COOKIE_NAME = $obj_type.$obj_id;
		$out = $cookies->{$COOKIE_NAME} ? "$signout\n$contents" : $signin;
	}	
	return $out;
}

sub _hdlr_private_object_type {
	my $obj = $_[1]->stash('private_obj')
		or return _no_private_obj($_[1], $_[1]->stash('tag'));
	my $class = MT->model($obj->datasource);
	return lc($class->class_label);
}

sub _hdlr_privacy_signin_link {
	my ($plugin, $ctx, $args) = @_;
	my $cfg = $ctx->{config};
    my $path = $ctx->_hdlr_cgi_path;
	my $script = 'plugins/Privacy/mt-privacy.cgi';
	my $blog_id = $ctx->stash('blog_id');
	my $obj = $_[1]->stash('private_obj')
		or return _no_private_obj($ctx, $ctx->stash('tag'));
		
	return sprintf "%s%s?__mode=login&amp;blog_id=%d&amp;object_type=%s&amp;object_id=%d", $path, $script, $blog_id, $obj->datasource, $obj->id;		
}

sub _hdlr_privacy_signout_link {
	my ($plugin, $ctx, $args, $cond) = @_;
	$args->{static} = 1;
	return $ctx->_hdlr_remote_sign_out_link($args);
}

sub _no_private_obj {
	my $tag = $_[1];
    $tag = 'MT' . $tag unless $tag =~ m/^MT/i;
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of a private object; " .
        "perhaps you mistakenly placed it outside of an 'MTPrivate' container?",
        $tag));
}

1;