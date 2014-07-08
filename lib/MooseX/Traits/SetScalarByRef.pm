package MooseX::Traits::SetScalarByRef;

use 5.016003;
use strict;
use warnings;
use Moose::Role;
use Moose::Util::TypeConstraints qw(find_type_constraint);

our $VERSION = '0.01';

# Supply a default for "is"
around _process_is_option => sub {
    my $next = shift;
    my $self = shift;
    my ($name, $options) = @_;

    if (not exists $options->{is}) {
        $options->{is} = "rw";
    }

    $self->$next(@_);
};

# Supply a default for "isa"
my $default_type;
around _process_isa_option => sub {
    my $next = shift;
    my $self = shift;
    my ($name, $options) = @_;

    if (not exists $options->{isa}) {
        if (not defined $default_type) {
            $default_type =
              find_type_constraint('ScalarRef')->create_child_constraint;
            $default_type->coercion('Moose::Meta::TypeCoercion'->new)
              ->add_type_coercions('Value', sub { my $r = $_; \$r });
        }
        $options->{isa} = $default_type;
    }

    $self->$next(@_);
};

# Automatically coerce
around _process_coerce_option => sub {
    my $next = shift;
    my $self = shift;
    my ($name, $options) = @_;

    if (    defined $options->{type_constraint}
        and $options->{type_constraint}->has_coercion
        and not exists $options->{coerce}) {
        $options->{coerce} = 1;
    }

    $self->$next(@_);
};

# This allows handles => 1
around _canonicalize_handles => sub {
    my $next = shift;
    my $self = shift;

    my $handles = $self->handles;
    if (!ref($handles) and $handles eq '1') {
        return ($self->init_arg, 'set_by_ref');
    }

    $self->$next(@_);
};

# Actually install the wrapper
around install_delegation => sub {
    my $next = shift;
    my $self = shift;

    my %handles = $self->_canonicalize_handles;
    for my $key (sort keys %handles) {
        $handles{$key} eq 'set_by_ref' or next;
        delete $handles{$key};
        $self->associated_class->add_method($key,
            $self->_make_set_by_ref($key));
    }

    # When we call $next, we're going to temporarily
    # replace $self->handles, so that $next cannot see
    # the set_by_ref bits which were there.
    my $orig = $self->handles;
    $self->_set_handles(\%handles);
    $self->$next(@_);
    $self->_set_handles($orig);    # and restore!
};

# This generates the coderef for the method that we're
# going to install
sub _make_set_by_ref {
    my $self = shift;
    my ($method_name) = @_;

    my $reader = $self->get_read_method;
    my $type   = $self->type_constraint;
    my $coerce = $self->should_coerce;

    return sub {
        my $obj = shift;
        if (@_) {
            my $new_ref =
                $coerce
              ? $type->assert_coerce(@_)
              : do { $type->assert_valid(@_); $_[0] };
            ${ $obj->$reader } = $$new_ref;
        }
        $obj->$reader;
    };
}

1;    # /MooseX::Traits::SetScalarByRef

__END__

=head1 NAME

MooseX::Traits::SetScalarByRef - Wrap a ScalarRef attribute's accessors to re-use a reference

=head1 SYNOPSIS

  use MooseX::Traits::SetScalarByRef;
  blah blah blah

=head1 DESCRIPTION

This module wraps a ScalarRef attribute's accessors to ensure that when the setter is called with a new ScalarRef
(or something that can be coerced into a ScalarRef),
rather that the usual set action happening,
you copy the string stored in the new scalar into the old scalar.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHORS

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 CONTRIBUTORS

Many thanks to tobyink. He basicaklly wrote all the code for this module and provided it on L<stackoverflow.com|http://stackoverflow.com/questions/23445500/automatically-generate-moose-attribute-wrapper-methods>.

Thanks to rsrchboy and @ether for the valuable feedback in #moose on L<irc.perl.org|http://www.irc.perl.org/>.

Thanks to Matt S Trout for the motivation of creating this module: I<Sufficiently encapsulated ugly is indistinguable from beautiful>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Alex Becker

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
