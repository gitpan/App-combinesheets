#!perl -w

#use Test::More qw(no_plan);
use Test::More tests => 1;

BEGIN { require "t/commons.pl"; }

# test for the simplest invocation (using the --version option)
@command = ( '-version' );
($stdout, $stderr) = my_run (@command);
is ($stderr, '', msgcmd ("Unexpected STDERR output for ", @command));

__END__
