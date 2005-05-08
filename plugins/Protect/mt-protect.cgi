#!/usr/bin/perl

use strict;

my($MT_DIR, $PLUGIN_DIR, $PLUGIN_ENVELOPE);
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

# Need to be able to override app config vars in constructor

eval {
    use lib 'lib';
    require Protect::Protect;
    my $app = Protect::Protect->new( Config => $MT_DIR . '/mt.cfg' )
	|| die "the app couldn't be initialized because " . Protect::Protect->errstr();
    $app->run();
}; if ($@) {
    print "An internal error occurred: $@";
}