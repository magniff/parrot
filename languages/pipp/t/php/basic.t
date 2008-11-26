# Copyright (C) 2008, The Perl Foundation.
# $Id$

=head1 NAME

t/php/basic.t - Standard Library basic

=head1 SYNOPSIS

    % perl -I../lib pipp/t/php/basic.t

=head1 DESCRIPTION

Tests PHP Standard Library basic
(implemented in F<languages/pipp/src/common/php_basic.pir>).

See L<http://www.php.net/manual/en/ref.?.php>.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../../../lib", "$FindBin::Bin/../../lib";

use Parrot::Test  tests => 5;

language_output_is( 'Pipp', <<'CODE', <<'OUTPUT', 'whitespace after echo' );
<?php
  echo 'one space', "\n";
  echo  'two spaces', "\n";
  echo   'three spaces', "\n";
?>
CODE
one space
two spaces
three spaces
OUTPUT

language_output_is( 'Pipp', <<'CODE', <<'OUTPUT', 'constants' );
<?php
  echo SEEK_SET, "\n";
  echo SEEK_CUR, "\n";
  echo SEEK_END, "\n";
?>
CODE
0
1
2
OUTPUT

language_output_is( 'Pipp', <<'CODE', <<'OUTPUT', 'getenv()' );
<?php
  echo getenv('PARROT_TMP'), "\n";
?>
CODE

OUTPUT

$ENV{PARROT_TMP} = 'GETENV_PARROT';

language_output_is( 'Pipp', <<'CODE', <<'OUTPUT', 'getenv()' );
<?php
  echo getenv('PARROT_TMP'), "\n";
?>
CODE
GETENV_PARROT
OUTPUT

language_output_is( 'Pipp', <<'CODE', <<'OUTPUT', 'sleep()' );
<?php
  sleep(1);
?>
CODE
OUTPUT


# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
