my class Set does Setty {
    has Int $!total;
    has $!WHICH;
    has @!pairs;

    method total (--> Int) { $!total //= %!elems.elems }
    multi method WHICH (Set:D:) {
        $!WHICH := self.^name ~ '|' ~ %!elems.keys.sort if !$!WHICH.defined;
        $!WHICH
    }
    submethod BUILD (:%elems) {
        nqp::bindattr(self, Set, '%!elems', %elems);
    }

    method at_key($k --> Bool) {
        so %!elems.exists_key($k.WHICH);
    }

    method delete ($a --> Bool) {  # is DEPRECATED doesn't work in settings
        DEPRECATED('the :delete adverb with postcircumfix:<{ }>');
        self.delete_key($a);
    }
    method delete_key($k --> Bool) is hidden_from_backtrace {
        X::Immutable.new( method => 'delete_key', typename => self.^name ).throw;
    }
    method grab ($count = 1) {
        X::Immutable.new( method => 'grab', typename => self.^name ).throw;
    }
    method grabpairs ($count = 1) {
        X::Immutable.new( method => 'grabpairs', typename => self.^name ).throw;
    }

    method pairs() {
        @!pairs ||= %!elems.values.map: { Enum.new(:key($_),:value(True)) };
    }

    method Set { self }
    method SetHash { SetHash.new(self.keys) }
}

# vim: ft=perl6 expandtab sw=4
