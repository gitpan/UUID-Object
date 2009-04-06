use strict;
use warnings;
use Test::More tests => 9;

use UUID::Object;

my $class = 'UUID::Object';

my $u0 = $class->create_from_base64('a6e4EJ2tEdGAtADAT9QwyA==');
my $u1 = $class->create_from_string('6ba7b810-9dad-11d1-80b4-00c04fd430c8');
my $u4 = $class->create_from_string('6ba7b814-9dad-11d1-80b4-00c04fd430c8');

# overload stringify
is( $u0, '6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'stringify' );

# overload comparator
ok( ($u0 <=> $u1) == 0, '<=> true' );
ok( ($u0 cmp $u1) == 0, 'cmp true' );
ok( ($u1 <=> $u4) != 0, '<=> false' );
ok( ($u1 cmp $u4) != 0, 'cmp false' );

ok( $u0 == $u1, '== from <=>' );
ok( $u0 eq $u1, 'eq from cmp' );
ok( $u1 < $u4, '< from <=>' );
ok( $u1 lt $u4, 'lt from cmp' );

