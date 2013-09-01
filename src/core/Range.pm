my class X::Range::InvalidArg { ... }

my class Range is Iterable is Cool does Positional {
    has $.min;
    has $.max;
    has $.excludes_min;
    has $.excludes_max;

    proto method new(|) { * }
    # The order of "method new" declarations matters here, to ensure
    # appropriate candidate tiebreaking when mixed type arguments 
    # are present (e.g., Range,Whatever or Real,Range).
    multi method new(Range $min, $max, :$excludes_min, :$excludes_max) {
        X::Range::InvalidArg.new(:got($min)).throw;
    }
    multi method new($min, Range $max, :$excludes_min, :$excludes_max) {
        X::Range::InvalidArg.new(:got($max)).throw;
    }
    multi method new(Whatever $min, Whatever $max, :$excludes_min, :$excludes_max) {
        fail "*..* is not a valid range";
    }
    multi method new(Whatever $min, $max, :$excludes_min, :$excludes_max) {
        nqp::create(self).BUILD(-$Inf, $max, $excludes_min, $excludes_max)
    }
    multi method new($min, Whatever $max, :$excludes_min, :$excludes_max) {
        nqp::create(self).BUILD($min, $Inf, $excludes_min, $excludes_max)
    }
    multi method new(Real $min, $max, :$excludes_min, :$excludes_max) {
        nqp::create(self).BUILD($min, $max.Real, $excludes_min, $excludes_max)
    }
    multi method new($min, $max, :$excludes_min, :$excludes_max) {
        nqp::create(self).BUILD($min, $max, $excludes_min, $excludes_max)
    }

    submethod BUILD($min, $max, $excludes_min, $excludes_max) {
        $!min = $min;
        $!max = $max;
        $!excludes_min = $excludes_min.Bool;
        $!excludes_max = $excludes_max.Bool;
        self;
    }

    method flat()     { nqp::p6list(nqp::list(self), List, Bool::True) }
    method infinite() { nqp::p6bool(nqp::istype($!max, Num)) && $!max eq 'Inf' }
    method iterator() { self }
    method list()     { self.flat }

    method bounds()   { ($!min, $!max) }

    multi method ACCEPTS(Range:D: Mu \topic) {
        (topic cmp $!min) > -(!$!excludes_min)
            and (topic cmp $!max) < +(!$!excludes_max)
    }

    multi method ACCEPTS(Range:D: Range \topic) {
        (topic.min > $!min
         || topic.min == $!min
            && !(!topic.excludes_min && $!excludes_min))
        &&
        (topic.max < $!max
         || topic.max == $!max
            && !(!topic.excludes_max && $!excludes_max))
    }

    method reify($n = 10) {
        my $value = $!excludes_min ?? $!min.succ !! $!min;
        # Iterating a Str range delegates to iterating a sequence.
        if Str.ACCEPTS($value) {
            return $value after $!max
                     ?? ()
                     !! SEQUENCE($value, $!max, :exclude_end($!excludes_max)).iterator.reify($n)
        } 
        my $count;
        if nqp::istype($n, Whatever) {
            $count = self.infinite ?? 10 !! $Inf;
        }
        else {
            $count = $n.Num;
            fail "request for infinite elements from range"
              if $count == $Inf && self.infinite;
        }
        my $cmpstop = $!excludes_max ?? 0 !! 1;
        my $realmax = nqp::istype($!min, Numeric) && !nqp::istype($!max, Callable) && !nqp::istype($!max, Whatever)
                      ?? $!max.Numeric
                      !! $!max;
        
        # Pre-size the buffer, to avoid reallocations.
        my Mu $rpa := nqp::list();
        nqp::setelems($rpa, $count == $Inf ?? 256 !! $count.Int);
        nqp::setelems($rpa, 0);
        
        if nqp::istype($value, Int) && nqp::istype($!max, Int) && !nqp::isbig_I(nqp::decont $!max)
           || nqp::istype($value, Num) {
            # optimized for int/num ranges
            $value = $value.Num;
            my $max = $!max.Num;
            my $box_int = nqp::p6bool(nqp::istype($!min, Int));
            my num $nvalue = $value;
            my num $ncount = $count;
            my num $nmax = $max;
            my int $icmpstop = $cmpstop;
            my int $ibox_int = $box_int;
            nqp::while(
                (nqp::isgt_n($ncount, 0e0) && nqp::islt_i(nqp::cmp_n($nvalue, $nmax), $icmpstop)),
                nqp::stmts(
                    nqp::push($rpa, $ibox_int
                        ?? nqp::p6box_i($nvalue)
                        !! nqp::p6box_n($nvalue)),
                    ($nvalue = nqp::add_n($nvalue, 1e0)),
                    ($ncount = nqp::sub_n($ncount, 1e0))
                ));
            $value = nqp::p6box_i($nvalue);
        }    
        else {
          (nqp::push($rpa, $value++); $count--)
              while $count > 0 && ($value cmp $realmax) < $cmpstop;
        }
        if ($value cmp $!max) < $cmpstop {
            nqp::push($rpa,
                ($value.succ cmp $!max < $cmpstop)
                   ?? nqp::create(self).BUILD($value, $!max, 0, $!excludes_max)
                   !! $value);
        }
        nqp::p6parcel($rpa, nqp::null());
    }

    method at_pos($pos) { self.flat.at_pos($pos) }

    multi method perl(Range:D:) { 
        $.min.perl
          ~ ('^' if $.excludes_min)
          ~ '..'
          ~ ('^' if $.excludes_max)
          ~ $.max.perl
    }

    proto method roll(|) { * }
    multi method roll(Range:D: Whatever) {
        gather loop { take self.roll }
    }
    multi method roll(Range:D:) {
        return self.list.roll unless nqp::istype($!min, Int) && nqp::istype($!max, Int);
        my Int:D $least = $!excludes_min ?? $!min + 1 !! $!min;
        my Int:D $elems = 1 + ($!excludes_max ?? $!max - 1 !! $!max) - $least;
        $elems ?? ($least + nqp::rand_I(nqp::decont($elems), Int)) !! Any;
    }
    multi method roll(Cool $num as Int) {
        return self.list.roll($num) unless nqp::istype($!min, Int) && nqp::istype($!max, Int);
        return self.roll if $num == 1;
        my int $n = nqp::unbox_i($num);
        gather loop (my int $i = 0; $i < $n; $i = $i + 1) {
            take self.roll;
        }
    }

    proto method pick(|)        { * }
    multi method pick()          { self.roll };
    multi method pick(Whatever)  { self.list.pick(*) };
    multi method pick(Cool $n as Int) {
        return self.list.pick($n) unless nqp::istype($!min, Int) && nqp::istype($!max, Int);
        return self.roll if $n == 1;
        my Int:D $least = $!excludes_min ?? $!min + 1 !! $!min;
        my Int:D $elems = 1 + ($!excludes_max ?? $!max - 1 !! $!max) - $least;
        return self.list.pick($n) unless $elems > 3 * $n;
        my %seen;
        my int $i_n = nqp::unbox_i($n);
        gather while $i_n > 0 {
            my Int $x = $least + nqp::rand_I(nqp::decont($elems), Int);
            unless %seen{$x} {
                %seen{$x} = 1;
                $i_n = $i_n - 1;
                take $x;
            }
        }
    }

    multi method Numeric (Range:D:) {
        nextsame unless $.max ~~ Numeric and $.min ~~ Numeric;

        my $diff := $.max - $.min - $.excludes_min;

        # empty range
        return 0 if $diff < 0;

        my $floor := $diff.floor;
        return $floor + 1 - ($floor == $diff ?? $.excludes_max !! 0);
    }
}

sub infix:<..>($min, $max) { 
    Range.new($min, $max) 
}
sub infix:<^..>($min, $max) { 
    Range.new($min, $max, :excludes_min) 
}
sub infix:<..^>($min, $max) { 
    Range.new($min, $max, :excludes_max) 
}
sub infix:<^..^>($min, $max) is pure {
    Range.new($min, $max, :excludes_min, :excludes_max) 
}
sub prefix:<^>($max) is pure {
    Range.new(0, $max.Numeric, :excludes_max) 
}
