#!perl -w

#use Test::More qw(no_plan);
use Test::More tests => 98;

use IO::CaptureOutput qw(capture_exec);
use FindBin qw( $Bin );
use File::Spec;
use File::Basename;
use Cwd;
use File::Which;
use lib "$Bin/../lib";

#-----------------------------------------------------------------
# Return a fully qualified name of the given file in the test
# directory "t/data" - if such file really exists. With no arguments,
# it returns the path of the test directory itself.
# -----------------------------------------------------------------
sub test_file {
    my $file = File::Spec->catfile ('t', 'data', @_);
    return $file if -e $file;
    $file = File::Spec->catfile ($Bin, 'data', @_);
    return $file if -e $file;
    return File::Spec->catfile (@_);
}

# -----------------------------------------------------------------
# Return a fully qualified path of the tested program, or die if such
# script does not exists.
# -----------------------------------------------------------------
sub tested_prg {
    my $prgname = shift;
    my $full_name;

    # 1) try the environment variable with a path
    if (exists $ENV{TESTED_PRG_PATH}) {
        $full_name = File::Spec->catfile ($ENV{TESTED_PRG_PATH}, $prgname);
        return maybe_die ($full_name);
    }

    # 2) try to find it on system PATH
    # $full_name = which ($prgname);
    # return $full_name if $full_name;

    # 3) try to find it in the current directory
    $full_name = File::Spec->catfile ('./', $prgname);
    return $full_name if -e $full_name and -x $full_name;

    # 4) try to find it in the ./bin directory
    $full_name = File::Spec->catfile ('./', 'bin', $prgname);
    return File::Spec->rel2abs ($full_name) if -e $full_name and -x $full_name;

    # 5) try to find it in the ../bin directory
    $full_name = File::Spec->catfile ('..', 'bin', $prgname);
    return File::Spec->rel2abs ($full_name) if -e $full_name and -x $full_name;

    # 6) try to find it in the parent directory
    $full_name = File::Spec->catfile ('..', $prgname);
    return maybe_die (File::Spec->rel2abs ($full_name));
}
sub maybe_die {
    my $prg = shift;
    die "'$prg' not found or is not executable.\n"
        unless -e $prg and -x $prg;
    return $prg;
}

# -----------------------------------------------------------------
sub check_bad_exit_code {
    ok (shift, msgcmd ("Non-zero exit code expected for ", @_));
}

# -----------------------------------------------------------------
sub check_good_exit_code {
    is (shift, 0, msgcmd ("Zero exit code expected for ", @_));
}

# -----------------------------------------------------------------
sub msgcmd {
    return shift() . join (" ", @_);
}

# -----------------------------------------------------------------
# Tests start here...
# -----------------------------------------------------------------
ok(1);
my $prg = tested_prg ('combinesheets');
diag( "Testing script $prg" );
diag ("Perl: $^V from $^X\n\t" . join ("\n\t", @INC));

# because we will be calling an external script
my $perl5lib = $ENV{PERL5LIB} || '';
$ENV{PERL5LIB} .= ':lib';
#$ENV{PERL5LIB} = join (":", @INC);

# test for the simplest invocation (using the -h option)
my @command = ( $^X, $prg, '-h' );
my ($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
is ($stderr, '', msgcmd ("Unexpected STDERR output", @command));

# test for error conditions
my $config_file = File::Spec->catfile (test_file(), 'errors.cfg');

@command = ( $^X, $prg, '-config', $config_file, '-inputs', 'dummy' );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_bad_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[ER01\]},
    msgcmd ("Expected error ER01 for ", @command, $stderr));
ok ($stderr =~ m{\[WR01\]} && $stderr =~ m{'0},
    msgcmd ("Expected warning WR01 ('0) for ", @command));
ok ($stderr =~ m{\[WR01\]} && $stderr =~ m{'jit'},
    msgcmd ("Expected warning WR01 ('jit') for ", @command));
ok ($stderr =~ m{\[WR02\]} && $stderr =~ m{'=col1'},
    msgcmd ("Expected warning WR02 ('=col1') for ", @command));
ok ($stderr =~ m{\[WR02\]} && $stderr =~ m{'DUM='},
    msgcmd ("Expected warning WR02 ('DUM=') for ", @command));

my $persons  = File::Spec->catfile (test_file(), 'persons.tsv');
my $cars     = File::Spec->catfile (test_file(), 'cars.csv');
my $children = File::Spec->catfile (test_file(), 'children.tsv');

# test for error conditions AND good results
my $person_and_car_results =
    [
     ['First name', 'Surname',   'Model',  'Sex', 'Nickname', 'Age', 'Year', 'Owned by' ],
     ['Jitka',      'Gudernova', 'Mini',   'F',   '',         '56',  '1968', 'Gudernova'],
     ['Jan',        'Novak',     '',       'M',   'Honza',    '52',  '',     ''         ],
     ['Martin',     'Senger',    'Skoda',  'M',   'Tulak',    '61',  '2002', 'Senger'   ],
    ];

$config_file = File::Spec->catfile (test_file(), 'config.cfg');

@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[WR07\]} && $stderr =~ m{'CHILD'},
    msgcmd ("Expected warning WR07 ('CHILD') for ", @command));
ok ($stderr =~ m{\[WR07\]} && $stderr =~ m{'CAR'},
    msgcmd ("Expected warning WR07 ('CAR') for ", @command));
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 5, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 20, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['First name', 'Surname',   'Sex', 'Nickname', 'Age'],
            ['Jitka',      'Gudernova', 'F',   '',         '56' ],
            ['Jan',        'Novak',     'M',   'Honza',    '52' ],
            ['Martin',     'Senger',    'M',   'Tulak',    '61' ],
           ],
           "With: persons");

@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons", "CAR=$cars" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[WR07\]} && $stderr =~ m{'CHILD'},
    msgcmd ("Expected warning WR07 ('CHILD') for ", @command));
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 8, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 32, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           $person_and_car_results,
           "With: persons and cars");

@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons", "CAR=$cars", "CHILDX=$children" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[WR03\]} && $stderr =~ m{'CHILDX'},
    msgcmd ("Expected warning WR03 ('CHILDX') for ", @command));
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 8, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 32, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           $person_and_car_results,
           "With: persons and cars");

@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons", "CAR=$cars", "CHILD=$children" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 10, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 40, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['First name', 'Surname',   'Model', 'Sex', 'Name',    'Born',  'Nickname', 'Age', 'Year', 'Owned by' ],
            ['Jitka',      'Gudernova', 'Mini',  'F',   'Hrasek',  '1984',  '',         '56',  '1968', 'Gudernova'],
            ['Jan',        'Novak',     '',      'M',   'Kulisek', '1982',  'Honza',    '52',  '',     ''         ],
            ['Martin',     'Senger',    'Skoda', 'M',   '',        '',      'Tulak',    '61',  '2002', 'Senger'   ],
           ],
           "With: persons, cars and children");

@command = ( $^X, $prg, '-config', $config_file, '-inputs', "CAR=$cars", "CHILD=$children" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 5, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 20, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['Model',  'Name',   'Born',   'Year',   'Owned by'    ],
            ['Mini',   'Hrasek', '1984',   '1968',   'Gudernova'   ],
            ['Skoda',  '',       '',       '2002',   'Senger'      ],
            ['Praga',  '',       '',       '1936',   'Someone else'],
           ],
           "With: cars and children");

@command = ( $^X, $prg, '-config', $config_file, '-inputs', "CHILD=$children", "CAR=$cars", "PERSON=$persons" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 3, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 10, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 30, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['First name', 'Surname',   'Model', 'Sex', 'Name',    'Born', 'Nickname', 'Age', 'Year', 'Owned by' ],
            ['Jitka',      'Gudernova', 'Mini',  'F',   'Hrasek',  '1984', '',         '56',  '1968', 'Gudernova'],
            ['Jan',        'Novak',     '',      'M',   'Kulisek', '1982', 'Honza',    '52',  '',     ''         ],
           ],
           "With: children, person and car");

$config_file = File::Spec->catfile (test_file(), 'error-unknown-matching-column.cfg');
@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons", "CAR=$cars", "CHILD=$children" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[WR05\]} && $stderr =~ m{'ParentX'},
    msgcmd ("Expected warning WR05 ('ParentX') for ", @command));
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 8, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 32, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           $person_and_car_results,
           "With: persons and cars");

$config_file = File::Spec->catfile (test_file(), 'error-unknown-primary.cfg');
@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons", "CAR=$cars", "CHILD=$children" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_bad_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[WR05\]} && $stderr =~ m{'SurnameX'},
    msgcmd ("Expected warning WR05 ('SurnameX') for ", @command));
ok ($stderr =~ m{\[ER03\]} && $stderr =~ m{'PERSON'},
    msgcmd ("Expected error ER03 ('PERSON') for ", @command));

$config_file = File::Spec->catfile (test_file(), 'error-unknown-columns.cfg');
@command = ( $^X, $prg, '-config', $config_file, '-inputs', "CHILD=$children", "CAR=$cars", "PERSON=$persons" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 3, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 2, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 6, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['First name', 'Surname'  ],
            ['Jitka',      'Gudernova'],
            ['Jan',        'Novak'    ],
           ],
           "Unknown columns: children, person and car");

$config_file = File::Spec->catfile (test_file(), 'error-no-columns.cfg');
@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons", "CHILD=$children", "CAR=$cars");
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), undef, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), undef, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 0, msgcmd ("Matrix count for ", @command));

# calling external programs (calculated columns)
unless (exists $ENV{COMBINE_SHEETS_EXT_PATH}) {
    my $cwd = getcwd;
    if (basename ($cwd) ne 't') {
        $ENV{COMBINE_SHEETS_EXT_PATH} = File::Spec->catfile ($cwd, 't');
    }
}

$config_file = File::Spec->catfile (test_file(), 'error-missing-output-column.cfg');
@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[WR10\]} && $stderr =~ m{'count-chars'},
    msgcmd ("Expected warning WR10 ('count-chars') for ", @command));
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 3, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 12, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['First name', '',   'Surname'  ],
            ['Jitka',      '14', 'Gudernova'],
            ['Jan',        '8',  'Novak'    ],
            ['Martin',     '12', 'Senger'   ],
           ],
           "With: persons and count-chars");

$config_file = File::Spec->catfile (test_file(), 'config-with-calculated-columns.cfg');
@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons" );
$ENV{PERL5LIB} .= ':./t';
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 5, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 20, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['First name', 'Characters Count', 'Initials 1', 'Initials 2', 'Surname'  ],
            ['Jitka',      '14',               'J1G',        'J1JG',       'Gudernova'],
            ['Jan',        '8',                'J8N',        'J8JN',       'Novak'    ],
            ['Martin',     '12',               'M1S',        'M1MS',       'Senger'   ],
           ],
           "With: persons and count-chars(2)");

$config_file = File::Spec->catfile (test_file(), 'error-bad-perl.cfg');
@command = ( $^X, $prg, '-config', $config_file, '-inputs', "PERSON=$persons" );
$ENV{PERL5LIB} .= ':./t';
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
ok ($stderr =~ m{\[WR13\]} && $stderr =~ m{Initials 1},
    msgcmd ("Expected warning WR13 (Initials 1) for ", @command));
ok ($stderr =~ m{\[WR11\]} && $stderr =~ m{Initials 2},
    msgcmd ("Expected warning WR11 (Initials 2) for ", @command));
ok ($stderr =~ m{\[WR11\]} && $stderr =~ m{Initials 3},
    msgcmd ("Expected warning WR11 (Initials 3) for ", @command));
ok ($stderr =~ m{\[WR11\]} && $stderr =~ m{Initials 4},
    msgcmd ("Expected warning WR11 (Initials 4) for ", @command));
ok ($stderr =~ m{\[WR12\]} && $stderr =~ m{Initials 5},
    msgcmd ("Expected warning WR12 (Initials 5) for ", @command));
ok ($stderr =~ m{\[WR12\]} && $stderr =~ m{Initials 6},
    msgcmd ("Expected warning WR12 (Initials 6) for ", @command));
ok ($stderr =~ m{\[WR14\]} && $stderr =~ m{'Not::Existing'},
    msgcmd ("Expected warning WR14 ('Not::Existing') for ", @command));
is (row_count ($stdout), 4, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 2, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 8, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['First name', 'Surname'  ],
            ['Jitka',      'Gudernova'],
            ['Jan',        'Novak'    ],
            ['Martin',     'Senger'   ],
           ],
           "With: persons and count-chars(3)");

$config_file = File::Spec->catfile (test_file(), 'things.cfg');
my $houses    = File::Spec->catfile (test_file(), 'houses.tsv');
my $furniture = File::Spec->catfile (test_file(), 'furniture.tsv');
my $paintings = File::Spec->catfile (test_file(), 'paintings.tsv');
my $drinks    = File::Spec->catfile (test_file(), 'drinks.tsv');
my $food      = File::Spec->catfile (test_file(), 'foods.tsv');

@command = ( $^X, $prg, '-config', $config_file, '-inputs',
             "HOUSE=$houses",
             "FUR=$furniture",
             "PAINT=$paintings",
             "DRINK=$drinks",
             "FOOD=$food" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 13, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 6, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 78, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['Owner',   'House',   'Furniture', 'Painting', 'Drink', 'Food'   ],
            ['Blanka',  'bigger',  'chair',     'acryl',    '',      'salad'  ],
            ['Blanka',  'bigger',  'chair',     'acryl',    '',      'fruit'  ],
            ['Blanka',  'bigger',  'sofa',      'acryl',    '',      'salad'  ],
            ['Blanka',  'bigger',  'sofa',      'acryl',    '',      'fruit'  ],
            ['Katrin',  'big',     '',          'pencil',   'beer',  'swarma' ],
            ['Katrin',  'big',     '',          'pencil',   'soda',  'swarma' ],
            ['Kim',     'small',   'table',     'oil',      '',      'burger' ],
            ['Kim',     'small',   'bed',       'oil',      '',      'burger' ],
            ['Kim',     'small',   'drawer',    'oil',      '',      'burger' ],
            ['Kim',     'smaller', 'table',     'oil',      '',      'burger' ],
            ['Kim',     'smaller', 'bed',       'oil',      '',      'burger' ],
            ['Kim',     'smaller', 'drawer',    'oil',      '',      'burger' ],
           ],
           "With: things");

$config_file = File::Spec->catfile (test_file(), 'books_to_authors.cfg');
my $books   = File::Spec->catfile (test_file(), 'books.tsv');
my $authors = File::Spec->catfile (test_file(), 'authors.tsv');

@command = ( $^X, $prg, '-config', $config_file, '-inputs',
             "BOOK=$books",
             "AUTHOR=$authors" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 6, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 4, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 24, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['Name',    'Title',   'Age', 'Note'      ],
            ['Blanka',  'Book 1',  '30',  'from B1-d' ],
            ['Katrin',  'Book 3',  '20',  'from B3-c' ],
            ['Katrin',  'Book 2',  '20',  'from B2-e' ],
            ['Kim',     'Book 1',  '28',  'from B1-a' ],
            ['Kim',     'Book 2',  '28',  'from B2-b' ],
           ],
           "With: books and authors");

@command = ( $^X, $prg, '-config', $config_file, '-inputs',
             "AUTHOR=$authors",
             "BOOK=$books" );
($stdout, $stderr, $success, $exit_code) = capture_exec (@command);
check_good_exit_code ($exit_code, @command);
is (row_count ($stdout), 7, msgcmd ("Rows count for ", @command));
is (col_count ($stdout), 4, msgcmd ("Columns count for ", @command));
is (mtx_count ($stdout), 28, msgcmd ("Matrix count for ", @command));
is_deeply (cut_into_table ($stdout),
           [
            ['Name',        'Title',   'Age', 'Note'      ],
            ['Blanka',      'Book 1',  '30',  'from B1-d' ],
            ['Katrin',      'Book 3',  '20',  'from B3-c' ],
            ['Katrin',      'Book 2',  '20',  'from B2-e' ],
            ['Kim',         'Book 1',  '28',  'from B1-a' ],
            ['Kim',         'Book 2',  '28',  'from B2-b' ],
            ['Lazy author', '',        '50',  ''          ],
           ],
           "With: authors and books");

# -----------------------------------------------------------------
sub row_count {
    my $data = shift;
    my @lines = split (m{\n}, $data);
    return undef unless @lines > 0;
    return scalar @lines;
}
sub col_count {
    my $data = shift;
    my @lines = split (m{\n}, $data);
    return undef unless @lines > 0;
    return scalar split (m{\t}, $lines[0], -1);
}
sub mtx_count {
    my $data = shift;
    my @lines = split (m{\n}, $data);
    my $count = 0;
    foreach my $line (@lines) {
        $count += scalar split (m{\t}, $line, -1);
    }
    return $count;
}
sub cut_into_table {
    my $data = shift;
    my @lines = split (m{\n}, $data);
    my @result = ();
    foreach my $line (@lines) {
        push (@result, [ split (m{\t}, $line, -1) ]);
    }
    return [ @result ];
}

__END__
