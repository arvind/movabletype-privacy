package Protect::Groups;
use strict;

use YAML qw( freeze thaw );

use MT::Object;
@Protect::Groups::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'label', 'description', 'data',
    ],
    indexes => {
        id => 1,
        label => 1,
    },
    column_defs => {
        'id' => 'integer not null auto_increment',
        'description' => 'text',
        'label' => 'string(100) not null',    	
        'data' => 'blob',
    },
    datasource => 'protect_groups',
    primary_key => 'id',
});

sub data {
    my $data = shift;
    $data->column('data', freeze(shift)) if @_;
    thaw($data->column('data'));
} 

1;