# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

package Privacy::Group;

use strict;
use MT::Object;
@Privacy::Group::ISA = qw(MT::Object);

__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'name' => 'string(255) not null',
        'description' => 'text',
    },
    indexes => {
		name => 1
    },
    datasource => 'privacy_group',
    primary_key => 'id'
});