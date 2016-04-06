# Manipulating streams with Perl

Streams are some thingies which are quite useful when one wants to get data on
demand.  Usually we don't know when they will end, so we just drain them byte
by byte until we take all we need.  We could boost them though by providing 
ways of making streams out of random objects, merging and transforming them,
and not let them drain.

In this post I'm going to show you some means to create infinite, immutable
streams using Perl.

Given the above requirements, our streams should:
  1. Provide a simple interface in order to create a stream from any type
       of object
  2. Be infinite
  3. Be immutable

Let's begin with the interface.  We need two functions -- one to create a 
stream from an object and another to create an object from a stream.  For the
sake of simplicity, our object will be a list.  `make_stream` should get a
list and provide a constructor which will let us explore the generated stream.
This constructor would be a function reference which, upon evaluation, would
return a `tuple` containing the first element (the head) and the rest of the 
stream (the tail).

    sub make_stream {
      my ($head, @rest) = @_;

      return sub {
        return ($head, make_stream(@rest));
      }
    }

    my $numbers = make_stream(1, 2, 3, 4, 5);

    # Exhaust our stream
    my ($first, $numbers) = $numbers->();
    while (defined $first) {
      say $first;
      ($first, $numbers) = $numbers->();
    }

In order to provide a robust handling of streams, we should prevent the user
from accessing the constructor directly.  A stream should be a something which
could only be manipulated via a set of library functions.  Thus, our next step
is to provide a stream unwrapper -- a function dual to `make_stream`.  It 
should deconstruct the stream into a head and a tail and return a tuple of the
head and the deconstructed tail.  It should stop the process when the head is
undefined.  Note that we never manipulate the passed stream -- immutability is
one of the properties we need with streams.

    sub unmake_stream {
      my $stream = shift;
      my ($head, $rest) = $stream->();

      if (!defined $head) {
        return ();
      }

      return ($head, unmake_stream($rest));
    }

    say unmake_stream($numbers);

Now, we have the means of creating and consuming streams.  The next function 
which we'll need is `cons`.  This function would prepend an element to the 
stream.  Our stream constructor is a function reference which returns a tuple
of the stream's head and the rest of the stream.  When prepending an element to
the stream, its head becomes the new element and its tail becomes the 
constructor of the old stream.

    sub cons {
      my ($elem, $stream) = @_;

      return sub {
        return ($elem, $stream);
      }
    }

    # Prepend one element
    $numbers = cons(0, $numbers);

    # Prepend several elements
    # It's easy to string functions which operate on streams
    $numbers = cons(-3, cons(-2, cons(-1, $numbers)));

Okay, so now we have finite streams in Perl.  But how do we handle infinity?
Basically, an infinite stream begins with some initial value and builds upon
it.  The natural numbers are a good example: they begin from 1 and each number
other than 1 is the previous number plus 1.  So we should be able to write code
like this:

    # $_[0] is the previous stream element
    my $nat_nums = make_stream(
      from => [0], 
      by => sub { $_[0] + 1 }
    );

Now, instead of getting the rest of the stream from the provided list, when
provided with a `by`, `make_stream` should generate it using this function on
the stream's head.

    sub make_stream {
      my %maker = @_;

      my ($head, @rest) = @{$maker{from}};
      my $gen = $maker{by};

      return sub {
        if (!defined $gen) {
          return ($head, make_stream(from => [@rest]));
        }

        # Here's the real deal \m/
        return ($head, make_stream(from => [$gen->($head)], by => $gen));
      }
    }

    # What happens here?
    say unmake_stream($nat_nums);

When provided with an infinite stream, `unmake_stream` would try to evaluate it
until it reaches the end of it.  The problem with infinities is, well..., they
are infinite.  So the evaluation of `unmake_stream` over an infinite list would
take quite some time (until it exhausts perl's stack space).

Therefore, now we need ways to `take` only a number of elements from an
infinite stream.  `take` is a function which takes `cnt` number of elements and
returns a new stream containing only `cnt` elements which is guaranteed to be
finite.

    sub take {
      my ($cnt, $stream) = @_;
      my ($head, $rest) = $stream->();

      if ($cnt <= 0 || !defined $head) {
        return make_stream(from => []);
      }

      return cons($head, take($cnt-1, $rest));
    }

    say unmake_stream(take(6, $nat_nums)) # 0, 1, 2, 3, 4, 5

Often we'd love to concatenate streams.  Let's make a function `concat` which
would take two streams and return a stream where the first stream is prepended
to the second.

    sub concat {
      my ($first, $second) = @_;
      my ($first_head, $first_rest) = $first->();

      if (!defined($first_head)) {
        # We no longer have what to concatenate with
        return $second;
      }

      return cons($first_head, concat($first_rest, $second));
    }

Now, stop for a while, examine this piece of beauty and try to figure out its
main flaw.

...

Flaws are best left unattended until they shine in immaculate destruction.

    my $three = make_stream(from => [1, 2, 3]);
    # Concat two finite streams
    say unmake_stream(concat(
          $three,
          make_stream(from => [4, 5, 6]))); # 1, 2, 3, 4, 5, 6

    # Concat a finite stream with an infinite one
    say unmake_stream(take(5, concat($three, $nat_nums))) # 1, 2, 3, 1, 2

    # Could a destruction be more pure than a stack overflow?
    # Concat an infinite stream to another stream
    say unmake_stream(take(5, concat($nat_nums, $three)));

The problem with the current implementation of `concat` is that it removes 
lazyness.  Despite the popular opinion, here lazyness is something we strive to
achieve.  Everything which prevents it, prevents us from doing work with
potential infinities.  How do we tackle this problem?  Remember that a stream
is just a constructor returning something and the rest of it in a state 
awaiting evaluation.  `concat` just forgot the second part of the definition
of what streams are.  How we create something that awaits evaluation?  We put
it in a function which gets evaluated upon call.

    sub concat {
      my ($first, $second) = @_;
      my ($first_head, $first_rest) = $first->();

      if (!defined($first_head)) {
        # We no longer have what to concatenate with
        return $second;
      }

      return cons($first_head, sub { concat($first_rest, $second) });
    }

But using `cons` in this way, means that, in a way, we've created a stream of a
stream.  And in the case when we've concatenated two streams, we'll have to
work with a stream of a stream instead.  Each time we try to use the stream's
elements, we'd have to remove one level of, let's say, streamity in order to 
reach the underlying stream.  This could be done, in the expense of making the
code harder to maintain:

    sub unmake_stream {
      my $stream = shift;
      my ($head, $rest) = $stream->();

      if (!defined $head) {
        return ();
      }

      # Check whether we're working with a stream of a stream
      my ($unstreamed, undef) = $rest->();
      if (ref $unstreamed eq 'CODE') { # A stream is just a CODE ref
        # Remove a level of streamity
        $rest = $unstreamed;
      }

      return ($head, unmake_stream($rest));
    }

And this kind of code should be put whenever we create a function which has
the potential of working on concatenated streams.

But why use `cons` in the first place?  To reuse code.  Often, however, there 
are times when code reuse is actually a bad thing.

    sub concat {
      my ($first, $second) = @_;
      my ($first_head, $first_rest) = $first->();

      if (!defined($first_head)) {
        # We no longer have what to concatenate with
        return $second;
      }

      return sub {
        return ($first_head, concat($first_rest, $second));
      }
    }

Now `concat` itself constructs the stream resulting from the concatenation of
the two streams.  We no longer need to do unmaintainability-foo in order to 
implement other valuable stream functions.  As a rule, each function which 
generates an infinite chain of recursive calls, should wrap them in a function
reference.

Having `take`, we could implement its opposite -- `drop`.

    sub drop {
      my ($n, $stream) = @_;
      my ($head, $rest) = $stream->();

      if (!defined $head) {
        return make_stram(from => []);
      }

      if ($n <= 1) {
        return $rest;
      }

      return drop($n-1, $rest);
    }

    say unmake_stream(take(10, drop(10, $nat_nums))); # 10, 11, ..., 19

How do we remove an element at an index `i`?  Well, if we `take` the first `i`
elements and concatenate them to the elements after `i+1`, the resulting stream
would have everything but its `i-th` element.

    sub dropAt {
      my ($i, $stream) = @_;

      return concat(take($i, $stream), drop($i+1, $stream));
    }

    say unmake_stream(take(10, dropAt(4, $nat_nums))); # 1, 2, 3, 4, 6, 7, 8, 9, 10

Let's make some other useful functions on streams.  `head` should return the
first element in a stream and `tail` should return a stream containing 
everything but the stream's head.

    sub head {
      my $stream = shift;
      my ($head, undef) = $stream->();

      return $head;
    }

    sub tail {
      my $stream = shift;
      my (undef, $rest) = $stream->();

      return $rest;
    }

    say head($nat_nums); # 1

    say unmake_stream(take(3, tail($nat_nums))); # 2, 3, 4

How do we get the length of a _finite_ stream?  The length of a stream is just
1 + the length of the rest of the stream.  The subtle problem with this
function is that it is useful only with finite streams.

    sub slength {
      my $stream = shift;
      my ($head, $rest) = $stream->();

      if (!defined $head) {
        return 0;
      }

      return 1 + slength($rest);
    }

    say slength(make_stream(from => [1, 2, 3, 4])); # 4

We created all the means of querying elements from streams, adding elements to
streams and dropping elements from streams.  How can we modify elements of a
stream?  Let's create the function `smap` which would go over a stream and
apply a function over each element of the stream.  This function should
preserve lazyness :)

    sub smap {
      my ($f, $stream) = @_;
      my ($head, $rest) = $stream->();

      if (!defined $head) {
        return make_stream(from => []);
      }

      return sub { # Be lazy!
        # Return a tuple of the modified element and $f applied to the rest of
        # the stream 
        return ($f->($head), smap($f, $rest));
      }
    }

    # Some voodoo time (and LISP-ness)
    say unmake_stream(
          take(10, # Take only 10 of them
            smap(
              sub { $_[0] * 2 }, # Create ALL even numbers
              $nat_nums
            )));

What's a map without `filter`?  The function `filter` should take a predicate
and a stream and return a stream containing only these elements satisfying the
predicate.  It should also preserve lazyness.

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

    # Take the next 10 even numbers
    say unmake_stream(
          take(10,
            drop(10,
              filter(
                sub { $_[0] % 2 == 0 },
                $nat_nums
              ))));

These functions give us the possibility to manipulate various kinds of streams
on objects which only provide a way to be streamed via `by => sub { ... }`, 
which generates the stream's next element.  In another post I'll show you how
to use this simple library to manipulate streamed data.  Meanwhile, you can 
check out the [code on github](https://github.com/emdeha/books-and-articles/tree/master/tech-articles/unicorn-streams/perl)
and play with it :)

[Camplight](https://camplight.net) made this possible.
