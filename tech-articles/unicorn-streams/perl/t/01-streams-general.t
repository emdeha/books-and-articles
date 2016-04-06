#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;


use Test::More tests => 11;
use Unicorn::Streams qw/:all/;

use experimental qw/smartmatch/;


my $natural_numbers = make_stream(from => [0], by => sub { $_[0] + 1 });
my $neg_nat = cons(-1, $natural_numbers);

my $next_ten = take(10, drop(10, concat($natural_numbers, $neg_nat)));
ok([unmake_stream($next_ten)] ~~ [10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    'Next 10 natural numbers after concat');

my $concat_finite = drop(2,
  concat(make_stream(from => [1, 2, 3]), make_stream(from => [1, 2, 3, 4, 5, 6])));
ok([unmake_stream($concat_finite)] ~~ [3, 1, 2, 3, 4, 5, 6],
    'Concat finite streams');

my $first_ten_drop = take(10, dropAt(4, $natural_numbers));
ok([unmake_stream($first_ten_drop)] ~~ [0, 1, 2, 3, 5, 6, 7, 8, 9, 10],
    'Drop 4th elem');

ok(head($natural_numbers) == 0,
    'Head of stream');

my $first_ten_tail = take(10, tail($natural_numbers));
ok([unmake_stream($first_ten_tail)] ~~ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    'First ten of tail');

ok(slength(make_stream(from => [1, 2, 3])) == 3,
    'Length of finite stream');

my $filter_take = filter(sub { $_[0] % 2 == 0 }, take(10, $natural_numbers));
ok([unmake_stream($filter_take)] ~~ [0, 2, 4, 6, 8],
    'Filter over take');

my $take_filter = take(10, filter(sub { $_[0] % 2 == 0 }, $natural_numbers));
ok([unmake_stream($take_filter)] ~~ [0, 2, 4, 6, 8, 10, 12, 14, 16, 18],
    'Take over filter');

my $filter_smap = filter(sub { $_[0] == 2 || $_[0] == 4 }, 
                      smap(sub { $_[0] * 2 }, take(20, $natural_numbers)));
ok([unmake_stream($filter_smap)] ~~ [2, 4],
    'Filter over smap');

my $take_smap = take(10, smap(sub { $_[0] * 2 }, $natural_numbers));
ok([unmake_stream($take_smap)] ~~ [0, 2, 4, 6, 8, 10, 12, 14, 16, 18],
    'Take over smap');

my $take_drop_filter = take(10, drop(10, filter(sub { $_[0] % 2 == 0 }, $natural_numbers)));
ok([unmake_stream($take_drop_filter)] ~~ [20, 22, 24, 26, 28, 30, 32, 34, 36, 38],
    'Take over drop over filter');
