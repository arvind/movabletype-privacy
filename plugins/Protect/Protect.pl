#!/usr/bin/perl
package MT::Plugin::Protect;
use strict;
use MT;
use MT::Plugin;
use vars qw($VERSION);
$VERSION = '1.0b1';
my $about = {
	dir => 'Protect',
  name => 'MT Protect v'.$VERSION,
  config_link => 'mt-protect.cgi?__mode=global_config',
  description => 'Adds the ability to protect entires either by password or using Typekey authentication.',
  doc_link => 'http://www.movalog.com/cgi-bin/trac.cgi/wiki/MtProtect'
}; 
MT->add_plugin(new MT::Plugin($about));

MT->add_plugin_action ('entry', 'mt-protect.cgi?__mode=edit', "Protect this entry");

# MT->add_plugin_action ('list_entries', 'mt-protect.cgi?__mode=list_entries', "List Protected Entries");

MT->add_plugin_action ('blog', 'mt-protect.cgi?__mode=edit', 'Edit Protection Options');