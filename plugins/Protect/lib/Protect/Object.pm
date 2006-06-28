package Protect::Object;

use strict;

use MT::Blog;
use MT::Object;
@MT::ObjectTag::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'blog_id' => 'integer',
        'object_id' => 'integer not null',
        'object_datasource' => 'string(50) not null',
        'password' => 'string(255)',
		'typekey_users' => 'text',
		'openid_users' => 'text'
    },
    indexes => {
        blog_id => 1,
        object_id => 1,
        object_datasource => 1,
    },
    child_of => 'MT::Blog',
    datasource => 'protect_object',
    primary_key => 'id',
});

1;
