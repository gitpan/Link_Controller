#!/usr/bin/perl -w
use warnings;

=head1 DESCRIPTION

Test those bits of the functionality of test-link that can be done
safely without any network connection or servers..  Unfortunately this
mostly means behavior where it doesn't do anything.

We mostly don't want to test things which require a working network
connection (unscalable and unreliable)

We don't want much external configuration because this could cause
confusion.

We don't want to take too long becuase this should be run by every
single person trying to install the software.

=head1 TESTS

first we test normal http

then we try to test other protocols

=cut

use Cwd;

$ENV{HOME}=cwd() . "/t/homedir";
$config=$ENV{HOME} . "/.link-control.pl";
die "LinkController test config file, $config missing." unless -e $config;

BEGIN {print "1..14\n"}

@start = qw(perl -Iblib/lib);

#$verbose=255;
$verbose=0 unless defined $verbose;
$fail=0;
sub nogo {print "not "; $fail=1;}
sub ok {my $t=shift; print "ok $t\n"; $fail=0}

$::infos="fixlink-infostruc.test-tmp";

$fixed='test-data/fixlink-infostruc';
unlink $::infos;
-e $::infos and die "can't unlink infostruc file $::infos";
open DEFS, ">$infos" or die "couldn't open $infos $!";
print DEFS "directory http://example.com/ "
    . cwd() . "/$fixed\n";
close DEFS or die "couldn't close $infos $!";

do "t/config/files.pl" or die "files.pl script not read: " . ($@ ? $@ :$!);
#die "files.pl script failed $@" if $@;

-e $_ and die "file $_ exists" foreach ($lonp, $phasl, $linkdb);

system 'rm', '-rf', $fixed;

-e $fixed and die "couldn't delete $fixed";

system 'cp', '-pr', 'test-data/sample-infostruc', $fixed;

ok(1);

#extract links for our later tests.

nogo if system @start, qw(blib/script/extract-links ), "--config-file=$conf",
  ($::verbose ? "--verbose" : "--silent") ;

ok(2);

nogo unless ( -e $lonp and -e $phasl and -e $linkdb );

ok(3);

$starturl='http://www.rum.com/';
$endurl='http://www.drinks.com/rum/';
$fixfile='test-data/fixlink-infostruc/banana.html';

#a standard fix of one link to another

nogo if system @start, 'blib/script/fix-link',
  "--config-file=$conf", $starturl, $endurl,
    ($::verbose ? "--verbose" : () );


ok(4);

nogo unless system "grep $starturl $fixfile > /dev/null" ;

ok(5);

nogo if system "grep $endurl $fixfile > /dev/null" ;

#testing relative fixing

$base='http://example.com/';
$startrel='../recipe';
$endrel='recipe';

ok(6);

nogo if system "grep $startrel $fixfile > /dev/null" ;

ok(7);

#this should NOT fix the infostructure

nogo if system @start, 'blib/script/fix-link',
  "--config-file=$conf", $base . $startrel, $base . $endrel,
    ($::verbose ? "--verbose" : "--no-warn" );


ok(8);

nogo if system "grep $startrel $fixfile > /dev/null" ;

ok(9);

nogo unless system "grep 'HREF=.$endrel.' $fixfile > /dev/null" ;

ok(10);

#this should now fix the infostructure doing relative substitution

nogo if system @start, 'blib/script/fix-link', '--relative',
  "--config-file=$conf", $base . $startrel, $base . $endrel,
    ($::verbose ? "--verbose" : "--no-warn" );

ok(11);

nogo unless system "grep $startrel $fixfile > /dev/null" ;

ok(12);

nogo if system "grep 'HREF=.$endrel.' $fixfile > /dev/null" ;


ok(13);

#now test that we can cope with links containing ..

open CONF, ">>$conf" or die "couldn't open $conf: $!";
print CONF <<EOF;
\$::page_index="test-data/badcdb/page_has_link.cdb";
\$::link_index="test-data/badcdb/link_on_page.cdb";
EOF
close CONF or die "couldn't close $conf: $!";

nogo if system @start, 'blib/script/fix-link',
  "--config-file=$conf",
  "http://scotclimb.org.uk/../images/coire_an_lochain_diag.gif",
  "http://scotclimb.org.uk/images/coire_an_lochain_diag.gif",
  ($::verbose ? "--verbose" : "--no-warn" ); #"--silent" if ever we need

ok(14);


