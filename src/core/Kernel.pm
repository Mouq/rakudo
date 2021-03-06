# The Kernel class and its methods, underlying $*KERNEL, are a work in progress.
# It is very hard to capture data about a changing universe in a stable API.
# If you find errors for your hardware or OS distribution, please report them
# with the values that you expected and how to get them in your situation.

class Kernel does Systemic {
    has Str $.release;
    has Str $!hardware;
    has Str $!arch;
    has Int $!bits;

    submethod BUILD (:$!auth = "unknown") {}

    method name {
        $!name //= do {
            given $*DISTRO.name {
                when any <linux macosx> { # needs adapting
                    qx/uname -s/.chomp.lc;
                }
                default {
                    "unknown";
                }
            }
        }
    }

    method version {
        $!version //= Version.new( do {
            given $*DISTRO.name {
                when 'linux' { # needs adapting
                    qx/uname -v/.chomp;
                }
                when 'macosx' {
                    my $unamev = qx/uname -v/;
                    $unamev ~~ m/^Darwin \s+ Kernel \s+ Version \s+ (<[\d\.]>+)/
                      ?? ~$0
                      !! $unamev.chomp;
                }
                default {
                    "unknown";
                }
            }
        } );
    }

    method release {
        $!release //= do {
            given $*DISTRO.name {
                when any <linux macosx> { # needs adapting
                    qx/uname -v/.chomp;
                }
                default {
                    "unknown";
                }
            }
        }
    }

    method hardware {
        $!hardware //= do {
            given $*DISTRO.name {
                when any <linux macosx> { # needs adapting
                    qx/uname -m/.chomp;
                }
                default {
                    "unknown";
                }
            }
        }
    }

    method arch {
        $!arch //= do {
            given $*DISTRO.name {
                when any <linux macosx> { # needs adapting
                    qx/uname -p/.chomp;
                }
                default {
                    "unknown";
                }
            }
        }
    }

    method bits {
        $!bits //= $.hardware ~~ m/_64|w/ ?? 64 !! 32;  # naive approach
    }

#?if moar
    has @!signals;  # Signal
    method signals (Kernel:D:) {
        once {
            my @names = "",qx/kill -l/.words;
            @names.splice(1,1) if @names[1] eq "0";  # Ubuntu fudge

            for Signal.^enum_value_list -> $signal {
                my $name = $signal.key.substr(3);
                if @names.first-index( * eq $name ) -> $index {
                    @!signals[$index] = $signal;
                }
            }
        }
        @!signals
    }
#?endif
}

PROCESS::<$KERNEL> := Proxy.new(
    FETCH => -> $       { PROCESS::<$KERNEL> := my $ = Kernel.new; },
    STORE => -> $, $val { PROCESS::<$KERNEL> := my $ = $val;       });

# vim: ft=perl6 expandtab sw=4
