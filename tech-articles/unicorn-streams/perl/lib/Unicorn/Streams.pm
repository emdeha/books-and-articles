package Unicorn::Streams;

use strict;
use warnings;
use v5.006;


=head1 NAME

Unicorn::Streams - Interface for working with pure, infinite streams in Perl.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

Unicorn::Streams provides a clean interface for handling infinite streams of
objects.  Currently, an object must be represented as a list and a $gen 
function which are both passed to make_stream.

Creating some natural numbers:

  my $natural_numbers = make_stream(
      from => [0],
      by => sub { shift() + 1 }
  );

Adding a negative number to the naturals:

  my $neg_nat = cons(-1, $natural_numbers);

Let's see the first 10 natural numbers.  unmake_stream converts a stream to a
list:
  
  say unmake_stream(take(10, $natural_numbers));

The next 10:

  say unmake_stream(take(10, drop(10, $natural_numbers)));

Try to evaluate all the natural numbers:

  say unmake_stream($natural_numbers); # Halts

Concatenate two infinite streams:

  my $double_inf = concat($natural_numbers, $neg_nat);

Remove 3 from $natural_numbers:

  my $without_three = dropAt(4, $natural_numbers); # We index from 1

Get the first natural number:

  say head($natural_numbers);

Get the first 10 natural numbers from 1 onwards:

  say unmake_stream(take(10, tail($natural_numbers))); # tail does the magic

Find the length of a _finite_ list:

  say slength(make_stream(from => [1, 2, 3]));

Get the even numbers out of the first ten natural numbers:

  filter(sub { $_[0] % 2 == 0 }, take(10, $natural_numbers));

Get the first ten even numbers:

  take(10, filter(sub { $_[0] % 2 == 0 }, $natural_numbers));

Generate all the even numbers:

  my $even = smap(sub { $_[0] * 2 }, $natural_numbers);
  say unmake_stream($even);

=cut


use Exporter qw/import/;


our @EXPORT_OK = qw/make_stream unmake_stream cons take drop dropAt concat smap
             slength filter head tail/;
our %EXPORT_TAGS = (all => [@EXPORT_OK]);


=head1 EXPORT

=head1 SUBROUTINES


=head2 make_stream

Creates a stream from a list.  If you want to create a stream where its next
element is generated by a function, pass it as a function reference, working
on the stream's head.

  my $nats = make_stream(from => [0], by = sub { $_[0] + 1 });

=cut

sub make_stream {
  my %maker = @_;

  my ($head, @rest);
  if (exists $maker{from}) {
    ($head, @rest) = @{$maker{from}};
  }

  my $gen = $maker{by};

  return sub {
    if (!defined $gen) {
      return ($head, make_stream(from => [@rest]));
    }

    return ($head, make_stream(from => [$gen->($head)], by => $gen));
  }
}

=head2 unmake_stream

Creates a list from a stream.

=cut

sub unmake_stream {
  my $stream = shift;
  my ($head, $rest) = $stream->();

  if (!defined $head) {
    return ();
  }

  my ($headD, undef) = $rest->();
  if (ref $headD eq 'CODE') {
    return ($head, unmake_stream($headD));
  }

  return ($head, unmake_stream($rest));
}

=head2 cons

Appends an element to a stream.

=cut

sub cons {
  my ($elem, $stream) = @_;

  return sub {
    return ($elem, $stream);
  }
}

=head2 take

Gets the first `n` elems from a stream.

=cut

sub take {
  my ($n, $stream) = @_;
  my ($head, $rest) = $stream->();

  if ($n <= 0 || !defined $head) {
    return make_stream(from => []);
  }

  return cons($head, take($n-1, $rest));
}

=head2 drop

Removes the first `n` elems from a stream.

=cut

sub drop {
  my ($n, $stream) = @_;
  my ($head, $rest) = $stream->();

  if (!defined $head) {
    return make_stream(from => []);
  }

  if ($n <= 1) {
    return $rest;
  }

  return drop($n-1, $rest);
}

=head2 concat

Concatenates two streams.

=cut

sub concat {
  my ($first, $second) = @_;
  my ($first_head, $first_rest) = $first->();

  if (!defined($first_head)) {
    return $second;
  }

  return sub {
    return ($first_head, concat($first_rest, $second));
  }
}

=head2 dropAt

Drops an element at index $i.

=cut

sub dropAt {
  my ($i, $stream) = @_;

  return concat(take($i, $stream), drop($i+1, $stream));
}

=head2 head

Gets the stream's head.

=cut

sub head {
  my $stream = shift;
  my ($head, undef) = $stream->();

  return $head;
}

=head2 tail

Gets the stream's tail.

=cut

sub tail {
  my $stream = shift;
  my (undef, $rest) = $stream->();

  return $rest;
}

=head2 slength

Computes the length of a stream.

=cut

sub slength {
  my $stream = shift;
  my ($head, $rest) = $stream->();

  if (!defined $head) {
    return 0;
  }

  return 1 + slength($rest);
}

=head2 filter

Creates a stream from another stream where its elements satisfy a predicate.

=cut

sub filter {
  my ($pred, $stream) = @_;
  my ($head, $rest) = $stream->();

  if (!defined $head) {
    return make_stream(from => []);
  }

  if ($pred->($head)) {
    return sub {
      return ($head, filter($pred, $rest));
    }
  }

  return filter($pred, $rest);
}

=head2 smap

Applies a function over a stream.

=cut

sub smap {
  my ($f, $stream) = @_;
  my ($head, $rest) = $stream->();

  if (!defined $head) {
    return make_stream(from => []);
  }

  return sub {
    return ($f->($head), smap($f, $rest));
  }
}


=head1 AUTHOR

Tsvetan Tsvetanov, C<< <tsvetan at camplight.net> >>

=head1 BUGS AND SUPPORT

Just drop me an email.

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 Tsvetan Tsvetanov.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1;
