#!/usr/bin/perl -w

use strict;

my ($MT_DIR);
BEGIN {
    my $programpath = $ENV{SCRIPT_FILENAME} || $0;
# Windows support -- possible drive leter.  Shouldn't 
# really get here of course, but if we do then windows will hang
# Changed:
#    while ($programpath !~ m|^[/\\]?$|) {
# To:
    while ($programpath !~ m|^(?:[a-z]+:)?[/\\]?$|) {
        if (-r "$programpath/lib/MT.pm") {
        $MT_DIR = $programpath;
        last;
        }
        $programpath =~ s|[/\\][^/\\]*[/\\]?$||;
    }
    $MT_DIR = "$MT_DIR/";

    unshift @INC, $MT_DIR . 'lib';
    unshift @INC, $MT_DIR . 'extlib';
}


use lib './lib';
use lib './plugins/Protect/lib';

local $| = 1;
print "Content-Type: text/html\n\n";
print "<pre>\n\n";

sub has_column
{
    my ($dbh, $table, $column) = @_;

    my $sth = $dbh->prepare("describe $table");
    if ($sth && $sth->execute()) {
	my $ddl = $sth->fetchall_arrayref();

	my @columns = map { $$_[0] } @$ddl;

	return (grep { $_ =~ /$column/ } @columns) ? 1 : 0;
    } else {
	$sth = $dbh->prepare("select $column from $table");
	$sth->execute() or return 0;
	return 1;
    }
}

eval {
    local $SIG{__WARN__} = sub { print "**** WARNING: $_[0]\n" };
    require MT;
    my $mt = MT->new( Config => $MT_DIR . 'mt-config.cgi')
        or die MT->errstr;

    print "Upgrading your databases:\n";
    

    my $dbh = MT::Object->driver->{dbh};

    my @stmts;
    if ($mt->{cfg}->ObjectDriver =~ /mysql/) {

	push @stmts, <<CREATE,
create table mt_protect_groups (
	protect_groups_id integer not null auto_increment primary key,
	protect_groups_label varchar(100) not null,
	protect_groups_description varchar(255),
	protect_groups_data mediumtext,
	index (protect_groups_label),
	unique(protect_groups_label)
	)
CREATE
 } else {
	print "Hm; I don't recognize your ObjectDriver setting. " 
	    . "Please set it to one of DBM, DBI::mysql, DBI::sqlite, "
	    . "or DBI::postgres";
    }
    
    for my $sql (@stmts) {
        print "Running '$sql'\n";
        $dbh->do($sql) or die $dbh->errstr . " on $sql";
    }

};
if ($@) {
    print <<HTML;

An error occurred while upgrading the schema:

$@

HTML
} else {
    print <<HTML;

Done upgrading your schema! All went well.

HTML
}

print "</pre>\n";
