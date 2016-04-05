#!/usr/bin/env perl

use strict;
use warnings;
use v5.014;


use FindBin;
use lib "$FindBin::Bin/lib";

use Unicorn::Streams qw/:all/;



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
