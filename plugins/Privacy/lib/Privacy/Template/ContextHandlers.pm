package Privacy::Template::ContextHandlers;

sub private {
	my ($type, $ctx, $args, $cond) = @_;
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $blog_id = $ctx->stash('blog_id');
    my $builder = $ctx->stash ('builder');
    my $tokens = $ctx->stash ('tokens');
    defined (my $out = $builder->build ($ctx, $tokens, $cond))
      or return $ctx->error ($builder->errstr);

	my $obj = $ctx->stash('private_obj');
	if(!$obj) {
		if($type eq 'category') {
			$obj = $ctx->stash('category') || $ctx->stash('archive_category');
		} else {
			$obj = $ctx->stash($type);
		}
		$ctx->stash('private_obj', $obj);
	}
	return $ctx->_no__obj('MT'.$ctx->stash('tag'), $type)
		if !$obj;
		
	require Privacy::Object;
	
	my $protected = Privacy::Object->count({ blog_id => $blog_id, object_id => $obj->id, object_datasource => $obj->datasource });

	return $out if !$protected;
	
	require MT::Template;
	my $tmpl = MT::Template->load({ blog_id => $blog_id, type => 'privacy_login'});
    my %cond;
    my $protect_text = $tmpl->build($ctx, \%cond);
    $protect_text = $tmpl->errstr unless defined $protect_text;	
	$ctx->stash('protect_text'.$type.$obj->id, $protect_text);

	# my $protect_text = $privacy_frame->get_config_value('protect_text', 'blog:'.$blog_id);
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

sub private_obj_id {
	my ($ctx) = @_;
	my $obj = $ctx->stash('private_obj');
	return $ctx->_no_private_obj('MTPrivacyObjectID')
		if !$obj;	
	return $obj->id;
}

sub private_obj_type {
	my ($ctx) = @_;	
	my $obj = $ctx->stash('private_obj');
	return $ctx->_no_private_obj('MTPrivacyObjectType')
		if !$obj;	
	return $obj->datasource;
}

sub privacy_types {
	my ($ctx, $args, $cond) = @_;
	my $privacy_frame = MT::Plugin::Privacy->instance;
	my $blog_id = $ctx->stash('blog_id');
	my $res = '';
	my %cond;
    my $builder = $ctx->stash ('builder');
    my $tokens = $ctx->stash ('tokens');
	my $obj = $ctx->stash('private_obj');
	return $ctx->_no_private_obj('MTPrivacyTypes')
		if !$obj;	
	
	require Privacy::Object;	
	foreach my $type (@{$privacy_frame->{privacy_types}}) {
		my $count = Privacy::Object->count({ blog_id => $blog_id, object_id => $obj->id, object_datasource => $obj->datasource, type => $type->{key} });
		next unless $count;
		
		$ctx->stash('privacy_type', $type);
		
        my $out = $builder->build($ctx, $tokens, %$cond);
        return $ctx->error( $builder->errstr ) unless defined $out;		
		$res .= $out;
	}	
	$res;
}

sub privacy_type_name {
	my ($ctx) = @_;	
	my $type = $ctx->stash('privacy_type');
	return $ctx->_no_private_obj('MTPrivacyTypeName')
		if !$type;	
		
	return $type->{key};	
}

sub privacy_type_fields {
	my ($ctx, $args, $cond) = @_;
	my $type = $ctx->stash('privacy_type');	
	my $res = '';
	my %cond;
    my $builder = $ctx->stash ('builder');
    my $tokens = $ctx->stash ('tokens');
	return $ctx->_no_private_obj('MTPrivacyTypeFields')
		if !$type;	
		
	foreach (keys (%{$type->{verification_fields}})) {
		$ctx->stash('privacy_type_field_name', $_);
		$ctx->stash('privacy_type_field_type', $type->{verification_fields}->{$_});
        my $out = $builder->build($ctx, $tokens, %$cond);
        return $ctx->error( $builder->errstr ) unless defined $out;		
		$res .= $out;
	}	
	$res;	
}

sub privacy_type_field_name {
	my ($ctx) = @_;	
	my $name = $ctx->stash('privacy_type_field_name');
	return $ctx->_no_private_obj('MTPrivacyTypeFieldName')
		if !$name;	
		
	return $name;	
}

sub privacy_type_field_type {
	my ($ctx) = @_;	
	my $type = $ctx->stash('privacy_type_field_type');
	return $ctx->_no_private_obj('MTPrivacyTypeFieldName')
		if !$type;	
		
	return $type;	
}

package MT::Template::Context;

sub _no__obj {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of an [_2]",
        $_[1], $_[2]));	
}

sub _no_private_obj {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of a protected asset; " .
        "perhaps you mistakenly placed it outside of an 'MTPrivacy' container?",
        $_[1]));	
}

1;