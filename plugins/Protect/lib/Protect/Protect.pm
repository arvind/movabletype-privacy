package Protect::Protect;
use strict;

use MT::Serialize;

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
    column_defs => {
    		'id' => 'integer not null auto_increment',
    		'blog_id' => 'integer not null',
    		'entry_id' => 'integer not null',
    		'type' => 'varchar(10) not null',
        'data' => 'blob',
    },
    datasource => 'protect',
    primary_key => 'id',
});

{
    my $ser;
    sub data {
        my $self = shift;
        $ser ||= MT::Serialize->new('MT');  # force MT serialization for plugins
        if (@_) {
            my $data = shift;
            $self->column('data', $ser->serialize( \$data ));
            $data;
        } else {
            my $data = $self->column('data');
            return undef unless defined $data;
            if (substr($data, 0, 4) eq 'SERG') {
                my $thawed = $ser->unserialize( $data );
                defined $thawed ? $$thawed : undef;
            } else {
                # signature is not a match, so the data must be stored
                # using YAML...
                require YAML;
                my $thawed = eval { YAML::thaw( $data ) };
                if ($@ =~ m/byte order/i) {
                    $YAML::interwork_56_64bit = 1;
                    $thawed = eval { YAML::thaw( $data ) };
                }
                return undef if $@;
                return $thawed;
            }
        }
    }
}

1;