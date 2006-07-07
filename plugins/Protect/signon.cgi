#!/usr/bin/perl -w

use strict;

my($MT_DIR, $PLUGIN_DIR, $PLUGIN_ENVELOPE);
BEGIN {
eval {
    require File::Basename; import File::Basename qw( dirname );
    require File::Spec;

    $MT_DIR = $ENV{PWD};
    $MT_DIR = dirname($0)
        if !$MT_DIR || !File::Spec->file_name_is_absolute($MT_DIR);
    $MT_DIR = dirname($ENV{SCRIPT_FILENAME})
        if ((!$MT_DIR || !File::Spec->file_name_is_absolute($MT_DIR))
            && $ENV{SCRIPT_FILENAME});
    unless ($MT_DIR && File::Spec->file_name_is_absolute($MT_DIR)) {
        die "Plugin couldn't find own location";
    }
};
if ($@) {
    print "Content-type: text/html\n\n$@";
    exit(0);
}

$PLUGIN_DIR = $MT_DIR;
($MT_DIR, $PLUGIN_ENVELOPE) = $MT_DIR =~ m|(.*[\\/])(plugins[\\/].*)$|i;

unshift @INC, $MT_DIR . 'lib';
unshift @INC, $MT_DIR . 'extlib';
unshift @INC, $PLUGIN_DIR . '/lib';
};


package MT::App::OpenIDSignOn;

use MT;
use MT::App;
use MT::App::Comments;
use base qw( MT::App::Comments );

use Net::OpenID::Consumer;
use XML::XPath;

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;

    $app->add_methods(
        oops   => \&oops,
        signon => \&signon,
        verify => \&verify,
    );

    $app->{default_mode} = 'oops';
    $app;
}

sub oops {
    "<h1>Here be dragons.</h1>";
}

sub _get_csr {
    my $ua = eval { require LWPx::ParanoidAgent; LWPx::ParanoidAgent->new; };
    $ua ||= LWP::UserAgent->new;
    Net::OpenID::Consumer->new(
        ua => $ua,
        args => $_[0]->{query},
        consumer_secret => 'HELLO HAPPY SECRET SECRET',
    );
}

sub signon {
    my $app = shift;
    my $csr = $app->_get_csr;
    my $q = $app->{query};

    my $identity = $q->param('openid_url');
    if(!$identity && $q->param('lj_user')) {
        $identity = 'http://www.livejournal.com/users/' . $q->param('lj_user');
    }

    my $claimed_identity = $csr->claimed_identity($identity)
        or return $app->error("Could not discover claimed identity: ". $csr->err);

    my $root = MT::ConfigMgr->instance->CGIPath;
    my $return_to = $app->base . $app->uri . '?__mode=verify&entry_id=' . $q->param('entry_id');
    my $check_url = $claimed_identity->check_url(
        return_to => $return_to,
        trust_root => $root,
    );

    return $app->redirect($check_url);
}

sub _rand {
    my ($app) = @_;
    $app->{__have_md5} = (eval { require Digest::MD5; 1 } ? 1 : 0)
        unless exists $app->{__have_md5};
    $app->{__have_md5} ? substr(rand(), 2) :
        Digest::MD5::md5_hex(Digest::MD5::md5_hex(time() . {} . rand() . $$));
}

sub add_step {
    my ($app, @step) = @_;
    push @{ $app->{__upgrade_steps} }, \@step;
}

sub progress { 1 }

sub do_upgrade {
    my $app = shift;
    my $pl = MT::Plugin::OpenIDComment->instance;
    my $schema = $pl->get_config_value('schema_version', 'system') || 0;
    my $real_version = MT::Plugin::OpenIDComment->schema_version;
    if($schema < $real_version) {
        ## Make schema changes with MT::Upgrade.
        {
            require MT::Upgrade;  # feel the burn
            my $upg = MT::Upgrade->new;
            local $MT::Upgrade::App = $app;
            $MT::Upgrade::App if 0;  # stupid warning
            $upg->check_class('MT::Plugin::OpenIDIdentity');
            $upg->run_step($_) for @{ $app->{__upgrade_steps} };
        };

        ## Make data changes.
        if($schema < 1) {
            ## Delete duplicate OpenIDIdentities that don't contain a real URL.
            my $id_iter = MT::Plugin::OpenIDIdentity->load_iter;
            my @to_delete;
            IDENTITY:
            while(my $id = $id_iter->()) {
                next IDENTITY if $id->url =~ m{ \A http }xms;
                push @to_delete, $id;
            }
            $_->remove for @to_delete;
            
            ## Make OpenIDIdentities for any openid Author who successfully
            ## left a comment and doesn't already have one.
            my $au_iter = MT::Author->load_iter({ type => MT::Author::COMMENTER });
            AUTHOR:
            while(my $author = $au_iter->()) {
                $author->name =~ m{ \A openid \n (.*) }xms;
                my $url = $1;

                next AUTHOR if !$url;
                next AUTHOR if $url !~ m{ \A http }xms;
                next AUTHOR if !MT::Comment->count({ commenter_id => $author->id });
                next AUTHOR if MT::Plugin::OpenIDIdentity->load({
                    author_id => $author->id });

                my $id = MT::Plugin::OpenIDIdentity->new;
                $id->url($url);
                $id->author_id($author->id);
                $id->save or return $app->error($id->errstr);
            }
        }

        ## All done! Record the upgrade.
        $pl->set_config_value('schema_version', $real_version, 'system');
        MT::log('OpenID Comments upgraded its database schema to schema version ' .
            $pl->get_config_value('schema_version') .' (plugin version '.
            MT::Plugin::OpenIDComment->instance->version . ')');
    }
}

sub _get_profile_data {
    my ($app, $vident, $blog_id) = @_;

    my $ua = eval { require LWPx::ParanoidAgent; 1; }
           ? LWPx::ParanoidAgent->new
           : LWP::UserAgent->new
           ;

    my $profile = {};
           
    ## FOAF
    if(my $foaf_url = $vident->declared_foaf) {
        my $resp = $ua->get($foaf_url);
        if($resp->is_success) {
            my $xml = XML::XPath->new( xml => $resp->content );
            $xml->set_namespace('RDF', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');
            $xml->set_namespace('FOAF', 'http://xmlns.com/foaf/0.1/');
            if(my ($name_el) = $xml->findnodes('/RDF:RDF/FOAF:Person/FOAF:name')) {
                $profile->{nickname} = $name_el->string_value;
            }
            my $pic_el;
            if(($pic_el) = $xml->findnodes('/RDF:RDF/FOAF:Person/FOAF:depiction/@RDF:resource')) {
                $profile->{pic_url} = $pic_el->string_value;
            } elsif(($pic_el) = $xml->findnodes('/RDF:RDF/FOAF:Person/FOAF:img/@RDF:resource')) {
                $profile->{pic_url} = $pic_el->string_value;
            }
            $xml->cleanup;
        }
        
        return $profile if $profile->{nickname} && $profile->{pic_url};
    }
    
    ## Atom
    if(my $atom_url = $vident->declared_atom) {
        my $resp = $ua->get($atom_url);
        if($resp->is_success) {
            my $xml = XML::XPath->new( xml => $resp->content );
            if(!$profile->{nickname}) {
                if(my ($name_el) = $xml->findnodes('/feed/author/name')) {
                    $profile->{nickname} = $name_el->string_value;
                }
            }
            $xml->cleanup;
        }

        return $profile if $profile->{nickname};
    }
    
    ## LJ username
    if(MT::Plugin::OpenIDComment->instance->get_config_value('special_lj',
        'blog:' . $blog_id)
    ) {
        my $url = $vident->url;
        if( $url =~ m(^https?://www\.livejournal\.com\/users/([^/]+)/$) ||
            $url =~ m(^https?://www\.livejournal\.com\/~([^/]+)/$) ||
            $url =~ m(^https?://([^\.]+)\.livejournal\.com\/$)
        ) {
            $profile->{nickname} = $1;
        }

        return $profile if $profile->{nickname};
    }

    $profile->{nickname} ||= $vident->display;
    return $profile;
}

sub verify {
    my $app = shift;
    my $q = $app->{query};
    my $entry = MT::Entry->load($q->param('entry_id'))
        or return $app->error('Invalid entry id '. $q->param('entry_id') .' in verification');
    return $app->error('OpenID signons are not available on this blog')
        unless MT::Plugin::OpenIDComment->instance->get_config_value('enable',
            'blog:' . $entry->blog_id);
    my $fake_email = 0;
    if(MT::Blog->count({ id => $entry->blog_id, require_comment_emails => 1 })) {
        if(MT::Plugin::OpenIDComment->instance->get_config_value('fake_email')) {
            $fake_email = 1;
        } else {
            return $app->error('This blog requires email addresses from commenters, which are not available when signing in with OpenID. Please inform the owner of the blog that the "Require E-mail Address" option should be disabled to allow OpenID sign-ins.');
        }
    }

    ## Uh-oh, no errors. We have to do real work. First make sure we can.
    $app->do_upgrade;

    my $csr = $app->_get_csr;

    if(my $setup_url = $csr->user_setup_url( post_grant => 'return' )) {
        return $app->redirect($setup_url);
    } elsif(my $vident = $csr->verified_identity) {
        ## Verified, so set up the commenter obj and session.
        my ($author);
        
        ## Discern nickname.
        my $profile = $app->_get_profile_data($vident, $entry->blog_id);

        require MT::Plugin::OpenIDIdentity;
        my $id = MT::Plugin::OpenIDIdentity->load({ url => $vident->url });
        if($id) {
            $author = $id->author;
            if($author->nickname ne $profile->{nickname}) {
                $author->nickname($profile->{nickname});
                $author->save or return $app->error($author->errstr);
            }

            if(!defined $id->pic_url || $id->pic_url ne $profile->{pic_url}) {
                $id->pic_url($profile->{pic_url});
                $id->save or return $app->error($id->errstr);
            }
        } else {
            require MT::Author;
            ## Find an unused name.
            my $name = "openid\n" . $app->_rand;
            $name = "openid\n" . $app->_rand while MT::Author->count({ name => $name });
            
            $author = MT::Author->new;
            $author->set_values({
                type => MT::Author::COMMENTER,
                name => $name,
                ## TODO: fake email to circumvent requirement
                email => '',
                nickname => $profile->{nickname},
                password => '(none)',
                url => $vident->url,
            });
            $author->save or return $app->error($author->errstr);

            $id = MT::Plugin::OpenIDIdentity->new;
            $id->url($vident->url);
            $id->author_id($author->id);
            $id->pic_url($profile->{pic_url});
            $id->save or return $app->error($id->errstr);
        }
        
        my $session_id = $app->_rand;
        ## TODO: fake email to circumvent requirement
        $app->_make_commenter_session($session_id, '', $author->name, $profile->{nickname});

        return $app->redirect($entry->permalink);
    } elsif($q->param('openid.mode') eq 'cancel') {
        ## Cancelled!
        return $app->redirect($entry->permalink);
    }

    return $app->error("Error validating identity: ". $csr->err);
}

1;


package main;

eval {
    my $app = MT::App::OpenIDSignOn->new( Config => $MT_DIR . 'mt.cfg',
                                          Directory => $MT_DIR )
        or die MT::App::OpenIDSignOn->errstr;
    local $SIG{__WARN__} = sub { $app->trace($_[0]) };
    $app->run;
};
if($@) {
    print "Content-Type: text/html\n\n";
    print "An error occurred: $@";
}

