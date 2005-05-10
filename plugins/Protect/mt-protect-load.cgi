#!/usr/bin/perl -w
#
# Copyright 2005 Arvind Satyanarayan. 

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
print <<HTML;

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<meta http-equiv="content-language" content="en" />
	
	<title>MT-Protect Initialization script [mt-protect-load.cgi]</title>
	
	<style type=\"text/css\">
		<!--
		
			body {
				font-family : Trebuchet MS, Tahoma, Verdana, Arial, Helvetica, Sans Serif;
				font-size : smaller;
				padding-top : 0px;
				padding-left : 0px;
				margin : 0px;
				padding-bottom : 40px;
				width : 80%;
				border-right : 1px dotted #8faebe;
			}
			
			h1 {
				background : #8faebe;
				font-size: large;
				color : white;
				padding : 10px;
				margin-top : 0px;
				margin-bottom : 20px;
				text-align : center;
			}
			
			h2 {
				color: #fff;
				font-size: small;
				background : #8faebe;
				padding : 5px 10px 5px 10px;
				margin-top : 30px;
				margin-left : 40px;
				margin-right : 40px;
			}
			
			h3 {
				color: #333;
				font-size: small;
				margin-left : 40px;
				margin-bottom : 0px;
				padding-left : 20px;
			}
	
			p {
				padding-left : 20px;
				margin-left : 40px;
				margin-right : 60px;
				color : #666;
			}
			
			ul {
				padding-left : 40px;
				margin-left : 40px;
			}
			
			code {
				font-size : small;
			}
			.info {
				margin-left : 60px;
				margin-right : 60px;
				padding : 20px;
				border : 1px solid #666;
				background : #eaf2ff;
				color : black;
			}
		
			.alert {
				margin-left : 60px;
				margin-right : 60px;
				padding : 20px;
				border : 1px solid #666;
				background : #ff9;
				color : black;
			}
			

			.ready {
				color: #fff;
				background-color: #9C6;
			}

			.bad {
				padding-top : 0px;
				margin-top : 4px;
				border-left : 1px solid red;
				padding-left : 10px;
				margin-left : 60px;
			}
			
			.good {
				color: #93b06b;
				padding-top : 0px;
				margin-top : 0px;
			}
		
		//-->
	</style>

</head>

<body>

<h1>MT-Protect Initialization script [mt-protect-load.cgi]</h1>

<p class="info">This page configures the necessary database tables to run MT-Protect on your system. If all of the tasks needed to successfully complete setup on your server, you will see a notice to that effect at the bottom of this page. If there are any problems during setup, you will see them display on this page so that you can make the appropriate corrections.</p>

<h2>MT-Protect Initialization</h2>

HTML


use File::Spec;

eval {

print "<h3>Loading initial data into system...</h3>\n";

require MT;
my $mt;

unless ($mt = MT->new( Config => $MT_DIR . 'mt.cfg', Directory => $MT_DIR )) {

    my $err = MT->errstr;
    if ($err =~ m/Your DataSource directory .*does not exist./i) {

        my $cfg = MT::ConfigMgr->instance;
        my $datasource = $cfg->DataSource;
        die "Bad ObjectDriver config: You must use an absolute path for your DataSource directory setting in your mt.cfg. An absolute path is one that starts with a slash (/).\n<br />\n<br />Current Datasource directory: $datasource\n<br />Probable absolute path: $MT_DIR"."db\n";
    } else {
        die MT->errstr;
    }
}

if ($mt->{cfg}->ObjectDriver =~ /^DBI::(.*)$/) {
    my $type = $1;
    my $dbh = MT::Object->driver->{dbh};
    my $schema = File::Spec->catfile($MT_DIR, 'plugins','Protect','schemas', 'Protect_schema.'.$type);
    open FH, $schema or die "<p class=\"bad\">Can't open schema file '$schema': $!</p>";
    my $ddl;
    { local $/; $ddl = <FH> }
    close FH;
    my @stmts = split /;/, $ddl;
    print "<h3>Loading database schema...</h3>\n\n";
    for my $stmt (@stmts) {
        $stmt =~ s!^\s*!!;
        $stmt =~ s!\s*$!!;
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }
}

};


if ($@) {
    print <<HTML;

<p class="bad">An error occurred while loading data:</p>

<p class="alert">$@</p>

HTML
} else {
    print <<HTML, security_notice();

	<h2 class="ready">MT-Protect Initialization Complete</h2>
	
	<p>Done loading initial data! All went well. You can now <a href="mt-protect.cgi?__mode=global_config">start using MT-Protect</a>!</p>

HTML
}


sub security_notice {
    return <<TEXT;
    
<h2>Very Important:</h2>

<p class="alert">Now that you have run mt-protect-load.cgi, you will never need to run it again. You should now <strong>delete <code>mt-protect-load.cgi</code></strong> from your webserver.</p>

TEXT
}


print "</body>\n\n</html>\n";
                                  