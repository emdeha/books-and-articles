#!/usr/bin/env perl

use strict;
use warnings;
use v5.014;


use FindBin;
use lib "$FindBin::Bin/lib";

use Unicorn::Streams qw/:all/;
use Unicorn::Streams::NetUDP qw/simple_connection/;


# Streams out of Internet connections
my $text_stream = make_stream(by => simple_connection(port => 7337));

$, = ' ';

say unmake_stream(take(10, $text_stream));

# Shall return the same output as above. Streams are immutable.
# say unmake_stream(take(10, $text_stream));

exit(0);

# Streams out of lists
$, = ' ';

my $natural_numbers = make_stream(from => [0], by => sub { shift() + 1 });
my $neg_nat = cons(-1, $natural_numbers);

say unmake_stream(take(10, drop(10, concat($natural_numbers, $neg_nat))));

say unmake_stream(drop(2, 
      concat(make_stream(from => [1, 2, 3]), make_stream(from => [1, 2, 3, 4, 5, 6]))));

say unmake_stream(take(10, dropAt(4, $natural_numbers)));

say head($natural_numbers);

say unmake_stream(take(10, tail($natural_numbers)));

say slength(make_stream(from => [1, 2, 3]));

say unmake_stream(filter(sub { $_[0] % 2 == 0 }, take(10, $natural_numbers)));

say unmake_stream(take(10, filter(sub { $_[0] % 2 == 0 }, $natural_numbers)));

say unmake_stream(filter(sub { $_[0] == 2 || $_[0] == 4 }, 
      smap(sub { $_[0] * 2 }, take(20, $natural_numbers))));

say unmake_stream(take(10, smap(sub { $_[0] * 2 }, $natural_numbers)));

say unmake_stream(take(10, drop(10, filter(sub { $_[0] % 2 == 0 }, $natural_numbers))));
