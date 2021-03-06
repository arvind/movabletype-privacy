# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::App::Authenticate;
use strict;

use MT::App::Comments;
@Privacy::App::Authenticate::ISA = qw( MT::App::Comments );

sub id { 'privacy' }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
       login            => \&login,
	   do_login			=> \&do_login,
       handle_sign_in   => \&handle_sign_in
    );
    $app->{plugin_template_path} = File::Spec->catdir('plugins','Privacy','tmpl');
    $app->init_commenter_authenticators;
    $app;
}

sub login {
	my $app = shift;
	my $q = $app->param;
	my $blog_id = $q->param('blog_id');
	my $object_type = $q->param('object_type');
	my $object_id = $q->param('object_id');
	
	require MT::Blog;
	my $blog = MT::Blog->load($blog_id);
	
	my @auth_loop;
    my $ca_reg = $app->registry("commenter_authenticators");
    my @auths = split ',', $blog->commenter_authenticators;
	unshift @auths, 'Password';
	# Since we're using commenter_authenticators, we need to hack a way to transport
	# this information for Privacy
	$q->param('static', "${object_type}::${object_id}"); 
	my $param = {
		blog_id => $blog_id,
		static => $q->param('static')
	};

	require Privacy::Object;
	foreach my $key (@auths) {
		my $count = Privacy::Object->count({ blog_id => $blog_id, type => $key, object_id => $object_id,
												object_datasource => $object_type });
		# next if !$count;
		
		if ( $key eq 'MovableType' ) {
            $param->{enabled_MovableType} = 1;
			# I don't think users should be allowed to register from Privacy
            require MT::Auth;
            $param->{can_recover_password} = MT::Auth->can_recover_password;
            next;
        } elsif($key eq 'Password') {
			$param->{enabled_Password} = 1;
		}
        my $auth = $ca_reg->{$key};
        next unless $auth;
		push @auth_loop,
           {
             name       => $auth->{label},
             key        => $auth->{key},
             login_form => $app->_get_options_html($key),
           };
	}
	$param->{auth_loop} = \@auth_loop;

	return $app->build_page($app->plugin->load_tmpl('login.tmpl'), $param);
}

# This is for MT logins. Mostly copied from MT::App::Comments but added handle_privacy routine
sub do_login {
    my $app     = shift;
    my $q       = $app->param;
    my $name    = $q->param('username');
    my $blog_id = $q->param('blog_id');
    my $blog    = MT::Blog->load($blog_id);
    my $auths   = $blog->commenter_authenticators;
    if ( $auths !~ /MovableType/ ) {
        $app->log(
            {
                message => $app->translate(
'Invalid commenter login attempt from [_1] to blog [_2](ID: [_3]) which does not allow Movable Type native authentication.',
                    $name, $blog->name, $blog_id
                ),
                level    => MT::Log::WARNING(),
                category => 'login_commenter',
            }
        );
        return $app->login( error => $app->translate('Invalid login.') );
    }

    require MT::Auth;
    my $ctx = MT::Auth->fetch_credentials( { app => $app } );
    $ctx->{blog_id} = $blog_id;
    my $result = MT::Auth->validate_credentials($ctx);
    my $message;
    if (   ( MT::Auth::NEW_LOGIN() == $result )
        || ( MT::Auth::NEW_USER() == $result )
        || ( MT::Auth::SUCCESS() == $result ) )
    {
        my $commenter = $app->user;
        if ( $q->param('external_auth') && !$commenter ) {
            $app->param( 'name', $name );
            if ( MT::Auth::NEW_USER() == $result ) {
                $commenter =
                  $app->_create_commenter_assign_role( $q->param('blog_id') );
                return $app->login( error => $app->translate('Invalid login') )
                  unless $commenter;
            }
            elsif ( MT::Auth::NEW_LOGIN() == $result ) {
                my $registration = $app->config->CommenterRegistration;
                unless ( $registration && $registration->{Allow} && $blog->allow_commenter_regist ) {
                    return $app->login( error => $app->translate('Successfully authenticated but signing up is not allowed.  Please contact system administrator.') )
                      unless $commenter;
                }
                else {
                    return $app->signup( error => $app->translate('You need to sign up first.') )
                      unless $commenter;
                }
            }
        }
        MT::Auth->new_login( $app, $commenter );
        if ( $app->_check_commenter_author( $commenter, $blog_id ) ) {
            $app->_make_commenter_session( $app->make_magic_token,
                $commenter->email, $commenter->name,
                ($commenter->nickname || 'User#' . $commenter->id),
                $commenter->id, undef, $ctx->{permanent} ? '+10y' : 0 );
            #$app->start_session( $commenter, $ctx->{permanent} ? 1 : 0 );
            # return $app->redirect_to_target;

			return $app->handle_privacy($commenter, $commenter->name);
        }
        $message =
          $app->translate( "Login failed: permission denied for user '[_1]'",
            $name );
    }
    elsif ( MT::Auth::INVALID_PASSWORD() == $result ) {
        $message =
          $app->translate( "Login failed: password was wrong for user '[_1]'",
            $name );
    }
    elsif ( MT::Auth::INACTIVE() == $result ) {
        $message =
          $app->translate( "Failed login attempt by disabled user '[_1]'",
            $name );
    }
    else {
        $message =
          $app->translate( "Failed login attempt by unknown user '[_1]'",
            $name );
    }
    $app->log(
        {
            message  => $message,
            level    => MT::Log::WARNING(),
            category => 'login_commenter',
        }
    );
    $ctx->{app} ||= $app;
    MT::Auth->invalidate_credentials($ctx);
    return $app->login( error => $app->translate('Invalid login.') );
}


# This actually handles a UI-level sign-in or sign-out request.
sub handle_sign_in {
    my $app = shift;
    my $q   = $app->param;

    my ($result, $credential);
    if ( $q->param('logout') ) {
        my ( $s, $commenter ) = $app->_get_commenter_session();
        if ($commenter) {
            require MT::Auth;
            my $ctx = MT::Auth->fetch_credentials( { app => $app } );
            my $cmntr_sess =
              $app->session_user( $commenter, $ctx->{session_id},
                permanent => $ctx->{permanent} );
            if ($cmntr_sess) {
                $app->user($commenter);
                MT::Auth->invalidate_credentials( { app => $app } );
            }
        }

        my %cookies = $app->cookies();
        $app->_invalidate_commenter_session( \%cookies );
        $result = 1;
    }
    else {
		if($q->param('key') eq 'Password') {
			$credential = $q->param('password');
		} else {
	        my $authenticator = MT->commenter_authenticator( $q->param('key') );
	        my $auth_class    = $authenticator->{class};
	        eval "require $auth_class;";
	        if ( my $e = $@ ) {
	            return $app->handle_error( $e, 403 );
	        }
	        $result = $auth_class->handle_sign_in($app);

			return $app->handle_error(
		        $app->errstr() || $app->translate(
		            "The sign-in attempt was not successful; please try again."),
		        403
		    ) unless $result;

			require Privacy::Auth;

			$credential = $auth_class->get_credential($app, $result);			
		}
		return $app->handle_privacy($result, $credential);
    }

    # $app->redirect_to_target;
}

sub handle_privacy {
	my $app = shift;
	my ($cmntr, $credential) = @_;
	my $key = $app->param('key');
	my $blog_id = $app->param('blog_id');
	my ($object_type, $object_id) = split '::', $app->param('static');
	require MT::Blog;
	my $blog = MT::Blog->load($blog_id);
	
	# Populate $ctx to use template tags and build no_perms message later on
	require MT::Template::Context;
	my $ctx = MT::Template::Context->new;
	local $ctx->{__stash}{blog_id} = $blog_id;
	local $ctx->{__stash}{blog} = $blog;
	
	my $class = MT->model($object_type);
	my $obj = $class->load($object_id);
	local $ctx->{__stash}{private_obj} = $obj;
	local $ctx->{__stash}{$object_type} = $obj;
	
	# $redirect is where the user will return to after a successful authentication
	my $redirect = $blog->site_url;
	if($object_type eq 'entry') {
		$redirect = $obj->permalink;
	} elsif($object_type eq 'category') {
		my $at = $blog->archive_type;
		if($at =~ /Category/) {
			require MT::Category;
			require MT::Util;
		    my $arch = $blog->archive_url;
		    $arch .= '/' unless $arch =~ m!/$!;
		    $arch = $arch . MT::Util::archive_file_for(undef, $blog, 'Category', $obj);
		    $arch = MT::Util::strip_index($arch, $blog);	
			$redirect = $arch;
		}
	}

	require Privacy::Object;
	my $has_credential = Privacy::Object->count({ blog_id => $blog_id, type => $key, object_datasource => $object_type, 
											object_id => $object_id, credential => $credential });
	
	# If the user hasn't been explicitly added, perhaps they're in a group?
	if(!$has_credential && $key ne 'Password') {
		my $mt_group = $app->registry('object_types', 'group') ? 1 : 0;
		my $group_key = $mt_group ? 'group' : 'privacy_group';
		my $group_class = $app->model($group_key);
		
		my @groups = Privacy::Object->load({ blog_id => $blog_id, type => 'Group', object_datasource => $object_type,
												object_id => $object_id });
		require MT::Association;
		require Privacy::Group;
		
		foreach my $gname (@groups) {
			my $group = $group_class->load({ name => $gname->credential });
			next if !$group;
			
			if($mt_group) {
				$has_credential = MT::Association->count({ author_id => $cmntr->id, group_id => $group->id, type => MT::Association::USER_GROUP() });
			} else {				
				$has_credential = Privacy::Object->count({ blog_id => $blog_id, type => $key, object_datasource => 'privacy_group', object_id => $group->id, credential => $credential });							
			}
			
			last if $has_credential;
		}
	}

	if($has_credential) {
		my $cgihost = $ctx->_hdlr_cgi_host;
		my $bloghost = $ctx->_hdlr_blog_host;
		if($cgihost eq $bloghost) {
			$app->bake_cookie(
				-name => $object_type.$object_id, 
				-value => 1,
				-path => '/'
			);
			return $app->redirect($redirect);
		} else {
			my $rand = $app->_rand;
			$app->plugin->set_config_value('rand', $rand);
			my $url = $ctx->_hdlr_blog_url;
			return $app->redirect($url."privacy.php?object_type=$object_type&object_id=$object_id&blog_id=$blog_id&redirect=$redirect");
		}
	} else {
		require MT::Builder;
		local $ctx->{__stash}{builder} = MT::Builder->new;
		
		my $no_perms_text = $app->plugin->get_config_value('no_perms', "blog:$blog_id");
		my $error = $ctx->build($no_perms_text, undef);
		return $app->error($error);
	}
}

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub plugin { return MT::Plugin::Privacy->instance; }

sub _rand {
    my ($app) = @_;
    $app->{__have_md5} = (eval { require Digest::MD5; 1 } ? 1 : 0)
        unless exists $app->{__have_md5};
    $app->{__have_md5} ? substr(rand(), 2) :
        Digest::MD5::md5_hex(Digest::MD5::md5_hex(time() . {} . rand() . $$));
}

1;