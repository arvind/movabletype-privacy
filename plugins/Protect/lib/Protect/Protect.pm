package Protect::Protect;
use strict;

use vars qw( $DEBUG $VERSION @ISA );
@ISA = qw(MT::App::CMS);
$VERSION = 1.0b1;
$DEBUG = 0;

use MT::PluginData;
use MT::ConfigMgr;
use MT::App::CMS;
use MT;

sub init
{
    my $app = shift;
    my %param = @_;
    debug("Initializing Protect");
    $app->SUPER::init(%param) or return;
    $app->add_methods(
    	'edit' 					=> \&edit,
    	'global_config' => \&global,
    	'save'          => \&save,
    	'delete'        => \&delete,
    );
    $app->{plugin_template_path} = File::Spec->catdir('plugins','Protect','tmpl');
    $app->{default_mode}   = 'edit';
    $app->{user_class}     = 'MT::Author';
    $app->{requires_login} = 1;
    $app->{mtscript_url}   = $app->{cfg}->CGIPath . $app->{cfg}->AdminScript;
    debug("Finished initializing Protect.");
    $app;
}    