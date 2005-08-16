package Protect::Groups;
use strict;

use MT::Serialize;

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