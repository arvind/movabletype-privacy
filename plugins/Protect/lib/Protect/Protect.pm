package Protect::Protect;
use strict;

use Storable qw( freeze thaw );

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
        data => 'blob',
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