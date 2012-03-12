
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for testing by the author');
  }
}

# This test is generated by Dist::Zilla::Plugin::Test::PodSpelling
use strict;
use warnings;
use Test::More;
use Test::Requires {
    'Test::Spelling'  => 0.12,
    'Pod::Wordlist::hanekomu' => 0,
};


add_stopwords(<DATA>);
all_pod_files_spelling_ok('bin', 'lib');
__DATA__
CSV
TSV
AnnoCPAN
PROG
PROGS
ignorecases
tsv
Martin
Senger
CBRC
KAUST
Computational
Biology
Research
Center
King
Abdullah
University
of
Science
and
Technology
All
Rights
Reserved
lib
App
combinesheets
