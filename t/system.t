#!/usr/bin/perl -w
use warnings;

=head1 DESCRIPTION

This test extracts links from an set of test pages and makes a link
database using standard tools.  Next it marks some of the links as
broken.  Finally it checks that the reporting programs give the
correct warnings about broken links.

=cut

use Cwd;

$ENV{HOME}=cwd() . "/t/homedir";
$home_config=$ENV{HOME} . "/.link-control.pl";
die "LinkController test config file, $home_config missing."
  unless -e $home_config;

BEGIN {print "1..10\n"}

@start = qw(perl -Iblib/lib);

#$verbose=255;
$verbose=0;
$fail=0;
sub nogo {print "not "; $fail=1;}
sub ok {my $t=shift; print "ok $t\n"; $fail=0}

do "t/config/files.pl" or die "files.pl script not read: $!" if $! ;
die "files.pl script failed: $@" if $@;

#try to generate the lists.

-e $_ and die "file $_ exists" foreach ($lonp, $phasl, $urls, $linkdb);
# create a "urllist" file from the directories
nogo if system @start, qw(blib/script/extract-links http://www.test.nowhere/
                          test-data/sample-infostruc/),
                          "--config-file=$conf";

ok(1);

#FIXME:delete this test

#nogo unless ( -e $lonp and -e $phasl and -e $urls);

ok(2);

#FIXME:delete this test

#nogo if system @start, 'blib/script/links-from-listfile', 'test-links.bdbm',
#		'urllist';

ok(3);

nogo unless ( -e $lonp and -e $phasl and -e $linkdb );

ok(4);

nogo if system @start, 'blib/script/link-report', "--config-file=$conf";

ok(5);

#put some broken links into the database
use Fcntl;
use DB_File;
use WWW::Link;
use MLDBM qw(DB_File);

tie %::links, MLDBM, "test-links.bdbm", O_RDWR, 0666, $DB_HASH
  or die $!;

$link = $::links{"http://www.rum.com/"};

#bypass time checks, but otherwise as close as possible to reality.
$link->first_broken;
$i=6;
$link->more_broken while --$i;

$::links{"http://www.rum.com/"}  = $link;

$link = $::links{"http://www.ix.com"};

#bypass time checks, but otherwise as close as possible to reality.
$link->passed_test;

$::links{"http://www.ix.com"}  = $link;

untie %::links;

$command= (join (" ", @start) )
  . " blib/script/link-report --config-file=$conf ";

$output = `$command`;

$output =~ m,broken.*http://www.rum.com/, or nogo ;

ok(6);

$command= (join (" ", @start) )
  . " blib/script/link-report --config-file=$conf " . '--html';

$output = `$command`;

$output =~ m(BROKEN.*
             \<A\s+.*
              HREF="http://www\.rum\.com/"
             ([^<>]|\n)*\> 
             http://www\.rum\.com/
             \<\/A\> 
            )sx or nogo ;

ok(7);

$command= (join (" ", @start) )
  . " blib/script/link-report --config-file=$conf " . '--okay';

$output = `$command`;

$output =~ m(http://www\.ix\.com)sx or nogo ;

ok(8);

#add tainting for the CGIbin
@start = qw(perl -Iblib/lib -w -T);

$command= (join (" ", @start) )
  . ' blib/script/link-report.cgi';

$output = `echo | $command`;

$output =~ m(\<HEAD\>.*\<TITLE\>.*\</TITLE\>.*\</HEAD\>.*\<BODY\>.*
	     BROKEN .*
             \<A\s .*
              HREF="http://www\.rum\.com/"
             ([^<>]|\n)*\> 
             http://www\.rum\.com/
             \</A\> .*
            \</BODY\>)isx or nogo ;

ok(9);

print STDERR "#going to run: echo infostructure=1 | $command";
$output = `echo infostructure=1 | $command`;
($mesg="output:\n\n$output\n\n") =~ s/^/#/mg;
print STDERR $mesg;


$output =~ m(\<HEAD\>.*\<TITLE\>.*\</TITLE\>.*\</HEAD\>.*\<BODY\>.*
	     BROKEN .*
             \<A\s .*
              HREF="http://www\.rum\.com/"
             ([^<>]|\n)*\> .*
             http://www\.rum\.com/
             \<\/A\> .*
             \<A\s.*
              HREF="http://www\.test\.nowhere/banana\.html"
             ([^<>]|\n)*\> .*
             http://www\.test\.nowhere/banana\.html .*
             \</A\> .*
            \</BODY\>)isx or nogo ;

ok(10);

#FIXME write tests for url reporting tests for include or exclude features.

#unlink 'link_on_page.cdb', 'page_has_link.cdb', 'test-links.bdbm', 'urllist',
#  $conf;
