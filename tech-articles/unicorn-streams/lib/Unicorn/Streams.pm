package Unicorn::Streams;


use strict;
use warnings;
use v5.014;

use Exporter qw/import/;


our @EXPORT_OK = qw/make_stream unmake_stream cons take drop dropAt concat smap
             slength filter head tail/;
our %EXPORT_TAGS = (all => [@EXPORT_OK]);


# Creates a stream from a list
sub make_stream {
  my %maker = @_;

  my ($head, @rest) = @{$maker{from}};
  my $gen = $maker{by};

  return sub {
    if (!defined $gen) {
      return ($head, make_stream(from => [@rest]));
    }

    return ($head, make_stream(from => [$gen->($head)], by => $gen));
  }
}

# Creates a list from a stream
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

# Appends an element to the stream
sub cons {
  my ($elem, $stream) = @_;

  return sub {
    return ($elem, $stream);
  }
}

# Gets the first `n` elems from a stream
sub take {
  my ($n, $stream) = @_;
  my ($head, $rest) = $stream->();

  if ($n <= 0 || !defined $head) {
    return make_stream(from => []);
  }

  return cons($head, take($n-1, $rest));
}

# Removes the first `n` elems from a stream
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

# Concatenates two streams
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

# Drops an element at index $i
sub dropAt {
  my ($i, $stream) = @_;

  return concat(take($i, $stream), drop($i+1, $stream));
}

# Gets the stream's head
sub head {
  my $stream = shift;
  my ($head, undef) = $stream->();

  return $head;
}

# Gets the stream's tail
sub tail {
  my $stream = shift;
  my (undef, $rest) = $stream->();

  return $rest;
}

# Computes the length of the stream
sub slength {
  my $stream = shift;
  my ($head, $rest) = $stream->();

  if (!defined $head) {
    return 0;
  }

  return 1 + slength($rest);
}

# Creates a stream from another stream where its elements satisfy a
# predicate
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

# Applies a function over a stream
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

1;
