package Protect::Protect;
use strict;

use YAML qw( freeze thaw );

use MT::Object;
@Protect::Protect::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'blog_id', 'entry_id', 'type', 'password', 'data',
    ],
    indexes => {
        blog_id => 1,
        entry_id => 1,
        type => 1,
    },
    column_defs => {
    		'id' => 'integer not null auto_increment',
    		'blog_id' => 'integer not null',
    		'entry_id' => 'integer not null',
    		'type' => 'varchar(10) not null',
    		'password' => 'varchar(200)',
        'data' => 'blob',
    },
    datasource => 'protect',
    primary_key => 'id',
});

sub data {
    my $data = shift;
    $data->column('data', freeze(shift)) if @_;
    thaw($data->column('data'));
} 

1;