package Protect::Protect;
use strict;

use MT::Object;
@Protect::Protect::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'blog_id', 'entry_id', 'type', 'data',
    ],
    indexes => {
        blog_id => 1,
        entry_id => 1,
        type => 1,
    },
    datasource => 'protect',
    primary_key => 'id',
});

1;