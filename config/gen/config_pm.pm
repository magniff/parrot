# Copyright (C) 2001-2010, Parrot Foundation.

=head1 NAME

config/gen/config_pm.pm - Record configuration data

=head1 DESCRIPTION

Writes the C<Parrot::Config::Generated> Perl module, the
F<runtime/parrot/library/config.fpmc> generator program, and the F<myconfig>
file.

=cut

package gen::config_pm;

use strict;
use warnings;

use base qw(Parrot::Configure::Step);
use Parrot::Configure::Utils ':gen';

use Cwd qw(cwd);
use File::Spec::Functions qw(catdir);

sub _init {
    my $self = shift;
    my %data;
    $data{description} = q{Record configuration data for later retrieval};
    $data{result}      = q{};
    $data{templates}    = {
        myconfig        => 'config/gen/config_pm/myconfig.in',
        config_pir      => 'config/gen/config_pm/config_pir.in',
        Config_pm       => 'config/gen/config_pm/Config_pm.in',
        config_lib      => 'config/gen/config_pm/config_lib_pir.in',
    };
    return \%data;
}

sub runstep {
    my ( $self, $conf ) = @_;

    $conf->data->clean;

    my $template = $self->{templates}->{myconfig};
    $conf->genfile($template, 'myconfig' );

    $template = $self->{templates}->{config_pir};
    my $gen_pir = q{runtime/parrot/library/config.pir};
    $conf->append_configure_log($gen_pir);
    $conf->genfile($template, $gen_pir );

    $template = $self->{templates}->{Config_pm};
    open( my $IN, "<", $template )
        or die "Can't open $template: $!";

    my $configdir = catdir(qw/lib Parrot Config/);
    unless ( -d $configdir ) {
        mkdir $configdir
            or die "Can't create dir $configdir: $!";
    }
    my $gen_pm = q{lib/Parrot/Config/Generated.pm};
    $conf->append_configure_log($gen_pm);
    open( my $OUT, ">", $gen_pm )
        or die "Can't open $gen_pm: $!";

    # escape spaces in current directory
    my $cwd = cwd();
    $cwd =~ s{ }{\\ }g;

    # Build directory can have non ascii characters
    # Maybe not the better fix, but allows keep working on the issue.
    # See TT #1717
    my $cwdcharset = q{};
    if ($cwd =~ /[^[:ascii:]]/) {
        $cwdcharset = 'binary:';
    }

    my $pkg = __PACKAGE__;
    print {$OUT} <<"END";
# ex: set ro:
# DO NOT EDIT THIS FILE
# Generated by $pkg from $template

END

    while (<$IN>) {
        s/\@PCONFIG\@/$conf->data->dump(q{c}, q{*PConfig})/e;
        s/\@PCONFIGTEMP\@/$conf->data->dump(q{c_temp}, q{*PConfig_Temp})/e;
        print {$OUT} $_;
    }

    close $IN  or die "Can't close $template: $!";
    close $OUT or die "Can't close $gen_pm: $!";

    $template = $self->{templates}->{config_lib};
    open( $IN,  "<", $template ) or die "Can't open '$template': $!";
    my $c_l_pir = q{config_lib.pir};
    $conf->append_configure_log($c_l_pir);
    open( $OUT, ">", $c_l_pir ) or die "Can't open $c_l_pir: $!";

    print {$OUT} <<"END";
# ex: set ro:
# DO NOT EDIT THIS FILE
# Generated by $pkg from $template and \%PConfig
# This file should be the last thing run during
# the make process, after Parrot is built.

END

    my %p5_keys = map { $_ => 1 } $conf->data->keys_p5();
    # A few of these keys are still useful.
    my @p5_keys_whitelist = qw(archname ccflags longsize optimize);
    foreach my $key (@p5_keys_whitelist) {
        delete($p5_keys{$key});
    }

    while (<$IN>) {
        if (/\@PCONFIG\@/) {
            for my $k ( sort { lc $a cmp lc $b || $a cmp $b } $conf->data->keys ) {
                next if exists $p5_keys{$k};
                next if $k =~ /_provisional$/;

                my $v = $conf->data->get($k);
                if ( defined $v ) {
                    my $type = ref $v;
                    if ( $type ) {
                        die "type of '$k' is not supported : $type\n";
                    }
                    # String
                    $v =~ s/\\/\\\\/g;
                    $v =~ s/\\\\"/\\"/g;
                    # escape unescaped double quotes
                    $v =~ s/(?<!\\)"/\\"/g;
                    $v =~ s/\n/\\n/g;
                    my $charset = q{};
                    if ($v =~ /[^[:ascii:]]/) {
                        $charset = 'binary:';
                    }
                    print {$OUT} qq(    set \$P0["$k"], $charset"$v"\n);
                }
                else {
                    # Null
                    print {$OUT} qq(    set \$P0["$k"], \$S2\n);
                }
            }
        }
        elsif (s/\"\@PWD\@\"/$cwdcharset\"$cwd\"/) {
            print {$OUT} $_;
        }
        else {
            print {$OUT} $_;
        }
    }

    close $IN  or die "Can't close $template: $!";
    close $OUT or die "Can't close $c_l_pir: $!";

    return 1;
}

1;

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
