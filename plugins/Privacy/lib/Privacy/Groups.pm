package Privacy::Groups;
use strict;

use MT::Serialize;

use MT::Object;
@Privacy::Groups::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    column_defs => {
	    'id' => 'integer not null auto_increment',
	    'label' => 'string(100) not null', 
	    'description' => 'text',
		'type' => 'string(10)',  
		'data' => 'blob'		
    },
    indexes => {
        id => 1,
        label => 1,
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

sub remove {
    my $group = shift;
    require Privacy::Object;
    my @objs = Privacy::Object->load({ object_id => $group->id, object_datasource => $group->datasource });
    for my $obj (@objs) {
        $obj->remove or die $obj->errstr;
    }
    $group->SUPER::remove;
}


1;