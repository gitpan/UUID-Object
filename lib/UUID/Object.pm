package UUID::Object;

use strict;
use warnings;
use 5.006;

our $VERSION = '0.03';

use Exporter 'import';

our @EXPORT = qw(
    uuid_nil
    uuid_ns_dns
    uuid_ns_url
    uuid_ns_oid
    uuid_ns_x500
);

use POSIX qw( floor );
use MIME::Base64;
use Carp;

use overload (
    q{""}  => sub { $_[0]->as_string },
    q{<=>} => \&_compare,
    q{cmp} => \&_compare,
    fallback => 1,
);

sub _compare {
    my ($a, $b) = @_;
    return $$a cmp $$b;
}

sub clone {
    my $self = shift;

    my $data = $$self;
    my $result = \$data;
    return bless $result, ref $self;
}

sub create_nil {
    my ($class) = @_;
    $class = ref $class if ref $class;

    my $data = chr(0) x 16;
    my $self = \$data;

    return bless $self, $class;
}

sub create {
    my $class = shift;
    my $self = $class->create_nil();
    $self->assign(@_);
    return $self;
}
*new = *create;

sub create_from_binary {
    my ($class, $arg) = @_;
    my $self = \$arg;
    return bless $self, $class;
}

sub create_from_binary_np {
    my $class = shift;
    my $self = $class->create_nil();
    $self->assign_with_binary_np(@_);
    return $self;
}

sub create_from_hex {
    my $class = shift;
    my $self = $class->create_nil();
    $self->assign_with_hex(@_);
    return $self;
}

sub create_from_string {
    my $class = shift;
    my $self = $class->create_nil();
    $self->assign_with_string(@_);
    return $self;
}

sub create_from_base64 {
    my $class = shift;
    my $self = $class->create_nil();
    $self->assign_with_base64(@_);
    return $self;
}

sub create_from_base64_np {
    my $class = shift;
    my $self = $class->create_nil();
    $self->assign_with_base64_np(@_);
    return $self;
}

sub create_from_hash {
    my $class = shift;
    my $self = $class->create_nil();
    $self->assign_with_hash(@_);
    return $self;
}

sub assign {
    my $self = shift;
    my $arg  = shift;

    if (! defined $arg) {
        $self->assign_with_object($self->create_nil);
    }
    elsif (eval { $arg->isa(ref $self) }) {
        $self->assign_with_object($arg);
    }
    elsif (! ref $arg && ! @_) {
        if (length $arg == 16) {
            $self->assign_with_binary($arg);
        }
        elsif ($arg =~ m{ \A [0-9a-f]{32} \z }ixmso) {
            $self->assign_with_hex($arg);
        }
        elsif ($arg =~ m{ \A [0-9a-f]{8} (?: - [0-9a-f]{4} ){3}
                                             - [0-9a-f]{12} \z }ixmso) {
            $self->assign_with_string($arg);
        }
        elsif ($arg =~ m{ \A [+/0-9A-Za-z]{22} == \z }xmso) {
            $self->assign_with_base64($arg);
        }
        else {
            croak "invalid format";
        }
    }
    else {
        unshift @_, $arg;
        $self->assign_with_hash(@_);
    }

    return $self;
}

sub assign_with_object {
    my ($self, $arg) = @_;

    if (! eval { $arg->isa(ref $self) }) {
        croak "argument must be UUID::Object";
    }

    $$self = $$arg;

    return $self;
}

sub assign_with_binary {
    my ($self, $arg) = @_;

    $$self = q{} . $arg;

    return $self;
}

sub assign_with_binary_np {
    my ($self, $arg) = @_;

    substr $arg, 0, 4,
           pack('N', unpack('I', substr($arg, 0, 4)));

    substr $arg, 4, 2,
           pack('n', unpack('S', substr($arg, 4, 2)));

    substr $arg, 6, 2,
           pack('n', unpack('S', substr($arg, 6, 2)));

    $$self = q{} . $arg;

    return $self;
}

sub assign_with_hex {
    my ($self, $arg) = @_;

    if ($arg !~ m{ \A [0-9a-f]{32} \z }ixmso) {
        croak "invalid format";
    }

    return $self->assign_with_binary(pack 'H*', $arg);
}

sub assign_with_string {
    my ($self, $arg) = @_;

    $arg =~ tr{-}{}d;

    return $self->assign_with_hex($arg);
}

sub assign_with_base64 {
    my ($self, $arg) = @_;

    if ($arg !~ m{ \A [+/0-9A-Za-z]{22} == \z }xmso) {
        croak "invalid format";
    }

    return $self->assign_with_binary(decode_base64($arg));
}

sub assign_with_base64_np {
    my ($self, $arg) = @_;

    if ($arg !~ m{ \A [+/0-9A-Za-z]{22} == \z }xmso) {
        croak "invalid format";
    }

    return $self->assign_with_binary_np(decode_base64($arg));
}

sub assign_with_hash {
    my $self = shift;
    my $arg  = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };

    if (my $variant = delete $arg->{variant}) {
        $self->variant($variant);
    }

    foreach my $key (qw( version
                         time time_low time_mid time_hi
                         clk_seq node              )) {
        if (exists $arg->{$key}) {
            $self->$key($arg->{$key});
        }
    }

    return $self;
}

sub as_binary {
    return ${$_[0]};
}

sub as_binary_np {
    my $self = shift;

    my $r = $self->as_binary;

    substr $r, 0, 4,
           pack('I', unpack('N', substr($r, 0, 4)));

    substr $r, 4, 2,
           pack('S', unpack('n', substr($r, 4, 2)));

    substr $r, 6, 2,
           pack('S', unpack('n', substr($r, 6, 2)));

    return $r;
}

sub as_hex {
    return scalar unpack 'H*', ${$_[0]};
}

sub as_string {
    my $u = $_[0]->as_binary;
    return join q{-}, map { unpack 'H*', $_ }
                      map { substr $u, 0, $_, q{} }
                          ( 4, 2, 2, 2, 6 );
}

sub as_base64 {
    my $r = encode_base64(${$_[0]});

    $r =~ s{\s+}{}gxmso;

    return $r;
}

sub as_base64_np {
    my $data = ${$_[0]};

    substr $data, 0, 4,
           pack('I', unpack('N', substr($data, 0, 4)));

    substr $data, 4, 2,
           pack('S', unpack('n', substr($data, 4, 2)));

    substr $data, 6, 2,
           pack('S', unpack('n', substr($data, 6, 2)));

    my $r = encode_base64($data);
    $r =~ s{\s+}{}gxmso;

    return $r;
}

sub as_hash {
    my $self = shift;

    my $r = {};
    foreach my $key (qw( variant version
                         time_low time_mid time_hi
                         clk_seq node              )) {
        $r->{$key} = $self->$key();
    }

    return $r;
}

sub as_urn {
    my $self = shift;

    return 'urn:uuid:' . $self->as_string;
}

sub variant {
    my $self = shift;

    if (@_) {
        my $var = shift;

        if ($var !~ m{^\d+$}o || ! grep { $var == $_ } qw( 0 2 6 7  4 )) {
            croak "invalid parameter";
        }
        $var = 2  if $var == 4;

        if ($var == 0) {
            substr $$self, 8, 1,
                   chr(ord(substr $$self, 8, 1) & 0x7f);
        }
        elsif ($var < 3) {
            substr $$self, 8, 1,
                   chr(ord(substr $$self, 8, 1) & 0x3f | $var << 6);
        }
        else {
            substr $$self, 8, 1,
                   chr(ord(substr $$self, 8, 1) & 0x1f | $var << 5);
        }

        return $var;
    }

    my $var = (ord(substr $$self, 8, 1) & 0xe0) >> 5;

    my %varmap = ( 1 => 0, 2 => 0, 3 => 0, 4 => 2, 5 => 2, );
    if (exists $varmap{$var}) {
        $var = $varmap{$var};
    }

    return $var;
}

sub version {
    my $self = shift;

    if (@_) {
        my $ver = shift;

        if ($ver !~ m{^\d+$}o || $ver < 0 || $ver > 15) {
            croak "invalid parameter";
        }

        substr $$self, 6, 1,
               chr(ord(substr($$self, 6, 1)) & 0x0f | $ver << 4);

        return $ver;
    }

    return (ord(substr($$self, 6, 1)) & 0xf0) >> 4;
}

sub time_low {
    my $self = shift;

    if (@_) {
        my $arg = shift;

        substr $$self, 0, 4, pack('N', $arg);

        return $arg;
    }

    return unpack 'N', substr($$self, 0, 4);
}

sub time_mid {
    my $self = shift;

    if (@_) {
        my $arg = shift;

        substr $$self, 4, 2, pack('n', $arg);

        return $arg;
    }

    return unpack 'n', substr($$self, 4, 2);
}

sub time_hi {
    my $self = shift;

    if (@_) {
        my $arg = shift;

        if ($arg >= 0x1000) {
            croak "invalid parameter";
        }

        substr $$self, 6, 2,
               pack('n', unpack('n', substr($$self, 6, 2)) & 0xf000
                         | $arg);

        return $arg;
    }

    return unpack('n', substr($$self, 6, 2)) & 0x0fff;
}

sub clk_seq {
    my $self = shift;

    my $r = unpack 'n', substr($$self, 8, 2);

    my $v = $r >> 13;
    my $w = ($v >= 6) ? 3   # 11x
          : ($v >= 4) ? 2   # 10-
          :             1;  # 0--

    $w = 16 - $w;

    if (@_) {
        my $arg = shift;

        if ($arg < 0) {
            croak "invalid parameter";
        }

        $arg &= ((1 << $w) - 1);

        substr $$self, 8, 2,
               pack('n', $r & (0xffff - ((1 << $w) - 1)) | $arg);

        return $arg;
    }

    return $r & ((1 << $w) - 1);
}

sub node {
    my $self = shift;

    if (@_) {
        my $arg = shift;

        if (length $arg == 6) {
        }
        elsif (length $arg == 12) {
            $arg = pack 'H*', $arg;
        }
        elsif (length $arg == 17) {
            if ($arg !~ m{ \A (?: [0-9A-F]{2} ) ([-:]) [0-9A-F]{2}
                                             (?:  \1   [0-9A-F]{2} ){4}
                           \z }ixmso) {
                croak "invalid parameter";
            }

            $arg =~ tr{-:}{}d;
            $arg = pack 'H*', $arg;
        }
        else {
            croak "invalid parameter";
        }

        substr $$self, 10, 6, $arg;
    }

    return join q{:}, map { uc unpack 'H*', $_ }
                          split q{}, substr $$self, 10, 6;
}

sub _set_time {
    my ($self, $arg) = @_;

    # hi = time mod (1000000 / 0x100000000)
    my $hi = floor($arg / 65536.0 / 512 * 78125);
    $arg -= $hi * 512.0 * 65536 / 78125;
    
    my $low = floor($arg * 10000000.0 + 0.5);

    # MAGIC offset: 01B2-1DD2-13814000
    if ($low < 0xec7ec000) {
        $low += 0x13814000;
    }
    else {
        $low -= 0xec7ec000;
        $hi ++;
    }

    if ($hi < 0x0e4de22e) {
        $hi += 0x01b21dd2;
    }
    else {
        $hi -= 0x0e4de22e;  # wrap around
    }

    $self->time_low($low);
    $self->time_mid($hi & 0xffff);
    $self->time_hi(($hi >> 16) & 0x0fff);

    return $self;
}

sub time {
    my $self = shift;

    if (@_) {
        $self->_set_time(@_);
    }

    my $low = $self->time_low;
    my $hi  = $self->time_mid | ($self->time_hi << 16);

    # MAGIC offset: 01B2-1DD2-13814000
    if ($low >= 0x13814000) {
        $low -= 0x13814000;
    }
    else {
        $low += 0xec7ec000;
        $hi --;
    }

    if ($hi >= 0x01b21dd2) {
        $hi -= 0x01b21dd2;
    }
    else {
        $hi += 0x0e4de22e;  # wrap around
    }

    $low /= 10000000.0;
    $hi  /= 78125.0 / 512 / 65536;  # / 1000000 * 0x100000000

    return $hi + $low;
}

sub is_v1 {
    my $self = shift;
    return $self->variant == 2 && $self->version == 1;
}

sub is_v2 {
    my $self = shift;
    return $self->variant == 2 && $self->version == 2;
}

sub is_v3 {
    my $self = shift;
    return $self->variant == 2 && $self->version == 3;
}

sub is_v4 {
    my $self = shift;
    return $self->variant == 2 && $self->version == 4;
}

sub is_v5 {
    my $self = shift;
    return $self->variant == 2 && $self->version == 5;
}

{
    my %uuid_const;

    my %uuid_const_map = (
        uuid_nil     => '00000000-0000-0000-0000-000000000000',
        uuid_ns_dns  => '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        uuid_ns_url  => '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
        uuid_ns_oid  => '6ba7b812-9dad-11d1-80b4-00c04fd430c8',
        uuid_ns_x500 => '6ba7b814-9dad-11d1-80b4-00c04fd430c8',
    );

    while (my ($id, $uuid) = each %uuid_const_map) {
        my $sub
            = sub {
                if (! defined $uuid_const{$id}) {
                    $uuid_const{$id}
                        = __PACKAGE__->create_from_string($uuid);
                }

                return $uuid_const{$id}->clone();
            };

        no strict 'refs';
        *{__PACKAGE__ . '::' . $id} = $sub;
    }
}

1;
__END__

=head1 NAME

UUID::Object - Universally Unique IDentifier (UUID) Object Class

=head1 SYNOPSIS

  use UUID::Object;
  
  $u1 = UUID::Object->create_from_hex("6ba7b8119dad11d180b400c04fd430c8");
  $u1->as_string;     #=> 6ba7b811-9dad-11d1-80b4-00c04fd430c8
  
  $u2 = UUID::Object->create_from_base64("a6e4EJ2tEdGAtADAT9QwyA==");
  $u2->as_string;     #=> 6ba7b810-9dad-11d1-80b4-00c04fd430c8
  
  if ($u1 != $u2) {
      print "UUIDs are different.";
  }
  
  uuid_ns_oid->as_hex;    #=> 6ba7b8129dad11d180b400c04fd430c8

=head1 DESCRIPTION

UUID::Object is an implementation of UUID
(Universally Unique IDentifier; described in RFC 4122) class.

This class does only represent UUIDs,
does not "generate" unique UUIDs (with algorithms as described in RFC 4122).
If you want to acquire suitable UUIDs for your application,
see other generator classes,
such as L<Data::UUID>, L<UUID::Generator::PurePerl>.

=head1 PROPERTIES

Following properties are defined with standard Perl module manner.
For setting property, specify that value as argument for the method.
For getting property, call the method without argument.
e.g.

  $version = $uuid->version();    # getter
  $uuid->version(3);              # setter

=head2 variant

Variant field of UUID.
(part of C<clock-seq-and-reserved> octet field)

Bit field length of variant is distributed from 1 to 3;
Valid values of variant are 0, 2, 6 and 7, actually.

Variant of UUID defined in RFC 4122 would be 2.

=head2 version

Version field of UUID.
(part of C<time-high-and-version> octet field)

This field represent an algorithm used for generating UUID.

Version of UUID defined in RFC 4122 would be from 1 to 5.

=head2 time_low

Time-low field of UUID.

With some algorithms, time-stamp of genesis is stored in UUID.
Time-stamps is a 60-bit value,
represented as count of 100 nanoseconds intervals
since 00:00:00.00 UTC, 15 October 1582,
the date of Gregorian reform to the Christian calendar.
(For further account, please refer to RFC 4122)

This field is the lowest 16-bit field of 60-bit time-stamp.

=head2 time_mid

Time-mid field of UUID.

This field is the middle 8-bit field of 60-bit time-stamp.

=head2 time_hi

Time-high field of UUID.
(part of C<time-high-and-version> octet field)

This field is the highest 4-bit field of 60-bit time-stamp.

=head2 clk_seq

Clock-seq field of UUID.

This field may be used to help avoid duplicates on same time-stamp.
Normally this has 14-bit width bit field of RFC 4122.

=head2 node

Node field of UUID.

Occasionally this field consists of an IEEE 802 MAC address.
You will get node property as C<"01:23:DE:AD:BE:AF"> form.
You can set node property in C<"01-23-de-ad-be-af"> form also.

=head2 time

This property is specific to this class, not described in RFC 4122.

As written in above, the time-stamp of UUID is 60-bit unsigned integer.
But the content of time-stamp is inconvenient
because that style is not used on other systems.

This C<time> property represents the time-stamp in form of UNIX time,
the number of seconds since the epoch, 00:00:00 UTC, 1 January 1970.
Usually UNIX time is represented in integer form,
but this property has floating point value
as C<time()> function in L<Time::HiRes>,
preferable for precision under one second.

Getting and setting time property with this method may cause
lost of information, see L<IMPLEMENTATION> section.

=head1 METHODS FOR GENERATION

=head2 __PACKAGE__-E<gt>create_from_binary($binary_string)

A UUID is 128 bits long,
so you can create UUIDs from 16 octets binary string with this method.

=head2 __PACKAGE__-E<gt>create_from_string($string)

Ordinarily a UUID is represented in string of separated fields form such as
C<"6ba7b811-9dad-11d1-80b4-00c04fd430c8">.
You can create UUIDs from strings in these forms with this method.

=head2 __PACKAGE__-E<gt>create_from_hex($hexadecimal_string)

UUIDs are also able to be created from hexadecimal string form, such as
C<"6ba7b8119dad11d180b400c04fd430c8">.
(You can specify hexadecimal string in either lower or upper case.)

=head2 __PACKAGE__-E<gt>create_from_base64($base64_string)

You can create UUIDs from a string represented in Base64 form.

=head2 __PACKAGE__-E<gt>create_from_hash(\%hash or %hash)

You can create UUIDs from an hash that represents properties you want
described in L</PROPERTIES> section.

=head2 __PACKAGE__-E<gt>create($any)

This C<create()> method can be used for all above methods.
Suitable constructor will be called from type and format of an argument.

=head2 __PACKAGE__-E<gt>new($any)

Of course you can use C<new()> instead of
L<C<create()>|/__PACKAGE__-E<gt>create($any)> as usual.

=head2 $uuid-E<gt>clone()

Instance of this class is an "object", not a primitive value.
If you wish to touch any properties of an instance
came from other instance, you should do C<clone()> it as a first step.

  $u1 = UUID::Object->new(...);
  $u2 = $u1;
  $u2->time_low(...);         # this affects $u1 also
  
  $u2 = $u1->clone();
  $u2->time_low(...);         # now, this doesn't affect $u1

=head1 METHODS FOR ASSIGNMENT

=head2 $uuid-E<gt>assign_with_*($argument)

You can assign any value in any form to the instance.
Following methods are corresponding to methods
C<create_from_*($argument)> described in L</METHODS FOR GENERATION>,
so please refer to the document of them for argument specification.

=over 2

=item $uuid-E<gt>assign_with_binary($binary_string)

=item $uuid-E<gt>assign_with_string($string)

=item $uuid-E<gt>assign_with_hex($hexadecimal_string)

=item $uuid-E<gt>assign_with_base64($base64_string)

=item $uuid-E<gt>assign_with_hash(\%hash or %hash)

=back

=head2 $uuid-E<gt>assign_with_object($other_uuid_object)

This method assigns value of other instance to the instance.
So,

  $u2 = $u1->clone();
  
  # has same meanings as:
  $u2 = UUID::Object->new();
  $u2->assign_with_object($u1);

=head2 $uuid-E<gt>assign($any)

You can use C<assign()> methods as one-stop assignment method,
similar to the L<C<create()>|/__PACKAGE__-E<gt>create($any)> method.

=head1 METHODS FOR REPRESENTATION

=head2 $uuid-E<gt>as_*

You can get representation of a UUID in some forms.
Representation form of result of following methods
conforms the specification described in above
L</METHODS FOR GENERATION> section.

=over 2

=item $uuid-E<gt>as_binary

=item $uuid-E<gt>as_string

=item $uuid-E<gt>as_hex

=item $uuid-E<gt>as_base64

=item $uuid-E<gt>as_string

=item $uuid-E<gt>as_hash

=back

=head2 $uuid-E<gt>as_urn

With this method, you can get the string representation of a UUID as a URN;
looks like
C<"urn:uuid:6ba7b811-9dad-11d1-80b4-00c04fd430c8">.

=head1 OVERLOADS

=head2 stringify

Stringify operation is overloaded by
L<C<as_string()>|/$uuid-E<gt>as_*> method,
so you can use an instance as normal string in some conditions.

  $uuid = UUID::Object->create_from_string(...);
  print $uuid;        #=> 6ba7b811-9dad-11d1-80b4-00c04fd430c8

=head2 comparison

Spaceship operator (C<E<lt>=E<gt>>) and C<cmp> are overloaded,
so you can compare one UUID object with other.

  $u1 = UUID::Object->create_from_string(...);
  $u2 = UUID::Object->create_from_string(...);
  
  if ($u1 == $u2) {
    # $u1 eqauls to $u2.
  }
  
  if ($u1 lt $u2) {
    # $u1 is less than $u2.
    # Of course, you can use '<' operator instead.
  }

=head1 CONSTANTS

Following constants (some of them represent namespace UUIDs)
are exported as default.

=over 2

=item C<uuid_nil>

The nil UUID;
C<00000000-0000-0000-0000-000000000000>.

=item C<uuid_ns_dns>

Namespace UUID for FQDN names;
C<6ba7b810-9dad-11d1-80b4-00c04fd430c8>.

=item C<uuid_ns_url>

Namespace UUID for URLs;
C<6ba7b811-9dad-11d1-80b4-00c04fd430c8>.

=item C<uuid_ns_oid>

Namespace UUID for ISO OIDs;
C<6ba7b812-9dad-11d1-80b4-00c04fd430c8>.

=item C<uuid_ns_x500>

Namespace UUID for X.500 DNs;
C<6ba7b814-9dad-11d1-80b4-00c04fd430c8>.

=back

=head1 NOTICE ABOUT PORTABILITY

This class stores UUID octets internally in network byte order,
so UUIDs created by this class do not have portability issue.

But in L<Data::UUID>,
those octets are stored in the way depending on architectures
(big-endian or little-endian).

Following (non-portable) methods behave
as if an internal structure of UUID is in machine dependent byte order.

=over 2

=item create_from_binary_np()

=item assign_with_binary_np()

=item as_binary_np()

=item create_from_base64_np()

=item assign_with_base64_np()

=item as_base64_np()

=back

In L<Data::UUID>, C<*_hex()> methods behave like C<*_string()>.
The only difference is,
the format of the former has field separator '-',
whereas one of the latter has prefix '0x' and doesn't have field separator.
So currently non-portable version of C<*_hex()> such as C<as_hex_np()>
are not implemented.

=head1 IMPLEMENTATION

An instance of UUID::Object is a reference to scalar,
which represents 16 octets (128-bits) binary string.
So, as written in L<C<clone()>|/$uuid-E<gt>clone()> section,
naive assignment is not safe for manipulation.
Use L<C<clone()>|/$uuid-E<gt>clone()> method for assignment instead.

The L<time> property of UUID::Object handles floating point value,
but UUID itself represents its time-stamps as 60-bit unsigned integer value.
Some type of loss may occur because of floating point precision.
(ex. fraction section of IEEE 754 double precision floating point value is
52-bit width, which is smaller than 60-bit.)
Setting that property is not recommended.

=head1 MOTIVATION

Already several modules that handles UUIDs are on CPAN.
Why did I develop yet another module?

Problems:

=over 2

=item Some variants of UUIDs are defined in specification (as L<version>),
each of them has suitable role in some scenes.
But some of precede modules implement only some part of them.

=item Most of UUID modules are written in XS codes.

=back

So at first, I decided to split functionality of UUID module
into two domains.
The one is representation of UUID, and the other is generation of UUIDs.
This module is for the former (and also has parsing functionality).
For the latter functionality, I wrote L<UUID::Generator::PurePerl>.

=head1 AUTHOR

ITO Nobuaki E<lt>banb@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<UUID::Generator::PurePerl>.

RFC 4122: "A Universally Unique IDentifier (UUID) URN Namespace", 2005, L<http://www.ietf.org/rfc/rfc4122.txt>.

=cut
