package Privacy::Template::ContextHandlers;

sub protect {
	my ($type, $ctx, $args, $cond) = @_;
	my $plugin = MT::Plugin::Privacy->instance;
	my $blog_id = $ctx->stash('blog_id');
    my $builder = $ctx->stash ('builder');
    my $tokens = $ctx->stash ('tokens');
    defined (my $out = $builder->build ($ctx, $tokens, $cond))
      or return $ctx->error ($builder->errstr);

	my $obj = $ctx->stash('protect_obj');
	if(!$obj) {
		if($type eq 'category') {
			$obj = $ctx->stash('category') || $ctx->stash('archive_category');
		} else {
			$obj = $ctx->stash($type);
		}
		$ctx->stash('protect_obj', $obj);
	}
	return $ctx->_no_protect_obj('MT'.$ctx->stash('tag'), $type)
		if !$obj;
		
	my $protected = $ctx->stash('protected_obj');
	if(!$protected) {
		require Privacy::Object;
		$protected = Privacy::Object->load({ blog_id => $blog_id, object_datasource => $type, object_id => $obj->id });
		$ctx->stash('protected_obj', $protected);
	}
	return $out if !$protected;
	
	my $protect_text = $ctx->stash('protect_text'.$type.$obj->id);
	
	if(!$protect_text) {
		require MT::Template;
		my $tmpl = MT::Template->load({ blog_id => $blog_id, type => 'privacy_login'});
	    my %cond;
	    $protect_text = $tmpl->build($ctx, \%cond);
	    $protect_text = $tmpl->errstr unless defined $protect_text;	
		$ctx->stash('protect_text'.$type.$obj->id, $protect_text);
	}
	# my $protect_text = $plugin->get_config_value('protect_text', 'blog:'.$blog_id);
	# $tokens = $builder->compile($ctx, $protect_text)
	#         or return $ctx->error($builder->errstr);
	# defined(my $protect_text_out = $builder->build($ctx, $tokens))
	#     	or die $builder->errstr;
	my $text = "<?php\n";
	$text .= 'if($_COOKIE[\''.$type.$obj->id.'\']) { ?>'."\n";
	$text .= $out;
	$text .= "\n<?php } else { ?>\n";
	$text .= $protect_text;
	$text .= "\n<?php } ?>";
	
	return $text;
}

sub protect_obj_id {
	my ($ctx) = @_;
	my $obj = $ctx->stash('protect_obj');
	return $ctx->_no_protect_obj('MTPrivacyObjectID')
		if !$obj;	
	return $obj->id;
}

sub protect_obj_type {
	my ($ctx) = @_;	
	my $obj = $ctx->stash('protect_obj');
	return $ctx->_no_protect_obj('MTPrivacyObjectType')
		if !$obj;	
	return $obj->datasource;
}

sub is_password {
	my ($ctx) = @_;
	my $protected = $ctx->stash('protected_obj') or
		return $ctx->_no_protected_obj('MTIfPasswordProtected');
	return $protected->password;		
}

sub is_typekey {
	my ($ctx) = @_;
	my $protected = $ctx->stash('protected_obj') or
		return $ctx->_no_protected_obj('MTIfPasswordProtected');
	return $protected->typekey_users;		
}

sub is_livejournal {
	my ($ctx) = @_;
	my $protected = $ctx->stash('protected_obj') or
		return $ctx->_no_protected_obj('MTIfPasswordProtected');
	return $protected->livejournal_users;		
}

sub is_openid {
	my ($ctx) = @_;
	my $protected = $ctx->stash('protected_obj') or
		return $ctx->_no_protected_obj('MTIfPasswordProtected');
	return $protected->openid_users;		
}

package MT::Template::Context;

sub _no_protect_obj {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of an [_2]",
        $_[1], $_[2]));	
}

sub _no_protected_obj {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of a protected asset; " .
        "perhaps you mistakenly placed it outside of an 'MTPrivacy' container?",
        $_[1]));	
}

1;