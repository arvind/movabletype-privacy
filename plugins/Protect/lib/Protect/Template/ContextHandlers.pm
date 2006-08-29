package Protect::Template::ContextHandlers;

sub protect {
	my ($ctx, $args, $cond) = @_;
	my $plugin = MT::Plugin::Protect->instance;
	my $blog_id = $ctx->stash('blog_id');
    my $builder = $ctx->stash ('builder');
    my $tokens = $ctx->stash ('tokens');
    defined (my $out = $builder->build ($ctx, $tokens, $cond))
      or return $ctx->error ($ctx->errstr);
	
	my $obj = $ctx->stash('entry') || $ctx->stash('category') || $ctx->stash('blog');

	return $ctx->error(MT->translate("The '[_1]' tag can only be used within the context of an entry, category or blog", 'MTProtect'))
		if !$obj;
	my $type = $obj->datasource;
	
	require Protect::Object;
	my $protected = Protect::Object->load({ blog_id => $blog_id, object_datasource => $type, object_id => $obj->id });
	return $out if !$protected;
	
	my $protect_text = $plugin->get_config_value('protect_text', 'blog:'.$blog_id);
	$tokens = $builder->compile($ctx, $protect_text)
        or return $ctx->error($build->errstr);
	defined(my $protect_text_out = $builder->build($ctx, $tokens))
    	or die $builder->errstr;
	my $text = "<?php\n";
	$text .= 'if($_COOKIE[\''.$type.$obj->id.'\']) { ?>'."\n";
	$text .= $out;
	$text .= "\n<?php } else { ?>\n";
	$text .= $protect_text_out;
	$text .= "\n<?php } ?>";
}

sub protect_obj_id {
	my ($ctx) = @_;
	my $obj = $ctx->stash('entry') || $ctx->stash('category') || $ctx->stash('blog');
	return $ctx->error(MT->translate("The '[_1]' tag can only be used within the context of an entry, category or blog", 'MTProtectObjectID'))
		if !$obj;	
	return $obj->id;
}

sub protect_obj_type {
	my ($ctx) = @_;	
	my $obj = $ctx->stash('entry') || $ctx->stash('category') || $ctx->stash('blog');
	return $ctx->error(MT->translate("The '[_1]' tag can only be used within the context of an entry, category or blog", 'MTProtect'))
		if !$obj;	
	return $obj->datasource;
}

1;