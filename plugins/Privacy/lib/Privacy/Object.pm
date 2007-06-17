# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::Object;

use strict;

use MT::Blog;
use MT::Object;
@Privacy::Object::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'blog_id' => 'integer',
        'object_id' => 'integer not null',
        'object_datasource' => 'string(50) not null',
		'type' => 'string(50) not null',
		'credential' => 'string(255) not null'
    },
    indexes => {
        blog_id => 1,
        object_id => 1,
        object_datasource => 1,
		type => 1,
		credential => 1
    },
    child_of => 'MT::Blog',
    datasource => 'privacy_object',
    primary_key => 'id',
});

1;
