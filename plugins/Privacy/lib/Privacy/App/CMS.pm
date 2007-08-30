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
	return 1 if !$q->param('privacy_manual');
	
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
	1;
}

# Transformer Callbacks

## First a general routine that includes app:privacy before/after a node or ID'd field
sub add_privacy_setting {
	my $plugin = shift;
	my ($cb, $app, $param, $tmpl, $marker, $where) = @_;
	

	# Where should include the DOM method to insert privacy_setting relative to the marker
	$where ||= 'insertAfter';
	
	# Marker can contain either a node or an ID of a node
	unless(ref $marker eq 'MT::Template::Node') {
		$marker = $tmpl->getElementById($marker);
	}
	
	my $appprivacy = $tmpl->createElement('app:privacy');
	$tmpl->$where($appprivacy, $marker);	
}

sub edit_entry_param {
	my $plugin = shift;
	my ($cb, $app, $param, $tmpl) = @_;
	
	# Add privacy setting after basename
	&add_privacy_setting($plugin, $cb, $app, $param, $tmpl, 'status', 'insertAfter');
}

# This adds an onclick to the OK link of the category selector
# which adds any category privacy settings
sub edit_entry_src {
	my $plugin = shift;
	my ($cb, $app, $tmpl) = @_;
	
	my $old = q{class="add-category-ok-link"};
	$old = quotemeta($old);
	my $new = q{class="add-category-ok-link" onclick="addCatPrivacy();"};
	$$tmpl =~ s/$old/$new/;
}

sub edit_category_param {
	my $plugin = shift;
	my ($cb, $app, $param, $tmpl) = @_;
	
	# Add privacy setting after basename
	&add_privacy_setting($plugin, $cb, $app, $param, $tmpl, 'description', 'insertAfter');	
}

sub cfg_prefs_param {
	my $plugin = shift;
	my ($cb, $app, $param, $tmpl) = @_;
	
	# Add privacy setting after basename
	&add_privacy_setting($plugin, $cb, $app, $param, $tmpl, 'server_offset', 'insertBefore');	
}

sub users_content_nav_src {
	my $plugin = shift;
	my ($cb, $app, $tmpl) = @_;
	
	# return 1 unless $app->registry('object_types', 'privacy_group');
	
	my $old = qq{<a href="<mt:var name="SCRIPT_URL">?__mode=list_authors"><__trans phrase="Users"></a></li>};
	$old = quotemeta($old);
	my $new = qq{<li><a href="<mt:var name="script_url">?__mode=list_privacy_groups"><__trans phrase="Privacy Groups"></a></li>};
	$$tmpl =~ s/($old)/$1\n$new/gi;
}

sub list_objects_param {
	my $plugin = shift;
	my ($cb, $app, $param, $tmpl) = @_;
	
	require Privacy::Object;
	my $object_loop = $param->{object_loop};
	foreach my $obj (@$object_loop) {
		$obj->{id} ||= $app->mode =~ /cat/ ? $obj->{category_id} : undef;
		$obj->{is_private} = Privacy::Object->count({ object_id => $obj->{id}, object_datasource => $param->{object_type} });
	}
}

sub list_objects_src {
	my $plugin = shift;
	my ($cb, $app, $tmpl) = @_;
	my ($old, $new);
	
	$old = q{<input type="checkbox" name="id-head" value="all" class="select" /></th>};
	$old = quotemeta($old);
	$new = <<HTML;
<mt:unless name="object_type" eq="entry"><mt:setvar name="show_privacy" value="1"></mt:unless>	
<mt:unless name="is_power_edit"><mt:setvar name="show_privacy" value="1"></mt:unless>

<mt:if name="show_privacy"><th class="privacy si"><img src="<mt:var name="static_uri">plugins/Privacy/images/privacy-header.gif" alt="<__trans phrase="Privacy Status">" title="<__trans phrase="Privacy Status">" width="9" height="9" /></th></mt:if>	
HTML

	$$tmpl =~ s/($old)/$1\n$new/;
	
	if($app->mode =~ /entry/ || $app->mode =~ /page/) {
		$old = q{<td class="status si<mt:if name="status_draft"> status-draft</mt:if><mt:if name="status_publish"> status-publish</mt:if><mt:if name="status_future"> status-future</mt:if>">};
	} elsif($app->mode =~ /cat/) {		
		$old = q{<td class="move-col" id="move-col-<mt:var name="category_id">">};
	} elsif($app->mode =~ /blog/) {
		$old = q{<td><a href="?__mode=dashboard&amp;blog_id=<mt:var name="id">"><mt:var name="name" escape="html"></a></td>};
	}
	$old = quotemeta($old);
	
	$new = q{<mt:if name="show_privacy"><td class="si"><img src="<mt:var name="static_uri">plugins/Privacy/images/privacy-<mt:if name="is_private">enabled<mt:else>disabled.gif</mt:if>"/></td></mt:if>};
	$$tmpl =~ s/($old)/$new\n$1/g;
	
}

1;