#!/usr/bin/perl -w

=head1 NAME

link-report - report status of links using databases

=head1 DESCRIPTION

This program goes through an entire database of links and reports
information about those links which match given criteria.  It can
optionally relate these to the locations of these links in files.  It
can give the output in several formats.

No actions are carried out to get further information than that which
is in the database.  This means that if a URL isn't listed in the link
database, a warning is printed, but nothing else.

Distributed along with this program is a file for emacs which can use
this to build a list of files for editing called link-report-dired.
This can be very useful for fixing all broken links.

=head1 SELECTING LINKS

This bit is where we really miss in the design by not doing it against
an SQL database.  When (and if) that comes then we can add alot more
power here more simply.

There are three modes for selection

=over

=item *

by url

=item *

by regex on the url --url-include --url-exclude

=item *

by regex on the page name --page-include --page-exclude

=back

These select which links are to be examined.  Then there are options
on the state of the link which choose which links to actually put out
information about.

By default redirected and broken links are output.  If any of these
options are called then only the specified links are output.

=over

=item --all-links

print out links in all states

=item --not-perfect

print out all links which were broken even on one check.

=item --redirected

print out links which were redirected

=back

=head1 BUGS

Infostructure mode C<-I> should be the default and there should be a
switch to use the database.

=head1 TODO

Much detailed control of the kind of links reported should be provided
(e.g. how many times detected broken etc.).  This should be done as a
more advanced database system is integrated.

=head1 SEE ALSO

L<verify-link-control(1)>; L<extract-links(1)>; L<build-schedule>
L<link-report(1)>; L<fix-link(1)>; L<link-report.cgi(1)>; L<fix-link.cgi>
L<suggest(1)>; L<link-report.cgi(1)>; L<configure-link-control>

The LinkController manual in the distribution in HTML, info, or
postscript formats, included in the distribution.

http://scotclimb.org.uk/software/linkcont - the
LinkController homepage.

=cut


use strict;
use Fcntl;
use DB_File;
use MLDBM qw(DB_File);
use CDB_File::BiIndex 0.026;
use WWW::Link;
use WWW::Link::Reporter::HTML;
use WWW::Link::Reporter::Text;
use WWW::Link::Reporter::LongList;
use WWW::Link::Selector;
use vars qw($linkdbm);


$::verbose=1023;


$WWW::Link::Repair::infostrucbase=undef;
$WWW::Link::Repair::filebase=undef;
#Configuration - we go through %ENV, so you'd better not be running SUID
#eval to ignore if a file doesn't exist.. e.g. the system config
use WWW::Link_Controller::ReadConf;

##############################################################################
#start command line processing
use Getopt::Function qw(maketrue makevalue);

use vars qw($html $not_perfect $redirected $since);

$::ignore_missing=0;
$::infostructure=0;
$::verbose=0;
$::not_perfect=0;
$::okay=0;
$::since=0;
$::html=0;
$::long_list=0;
@::url_exc=();
@::url_inc=();
@::page_exc=();
@::page_inc=();
@::urls=();
$::url_report=0;

$::opthandler = new Getopt::Function
  [ "version V>version",
    "usage h>usage help>usage",
    "help-opt=s",
    "verbose:i v>verbose",
    "",
    "url=s U>url",
    "url-file=s f>url",
    "url-exclude=s E>url-exclude",
    "url-include=s I>url-include",
    "page-exclude=s e>page-exclude",
    "page-include=s i>page-include",
    "",
    "all-links a>all-links",
    "broken b>broken",
    "not-perfect n>not-perfect",
    "redirected r>redirected",
    "okay o>okay",
    "disallowed d>disallowed",
    "unsupported u>unsupported",
    "ignore-missing m>ignore-missing",
    "",
    "infostructure:s I>infostructure",
    "config-file=s",
    "link-index=s",
    "link-database=s",
    "url-base=s",
    "file-base=s",
    "",
    "long-list l>long-list",
    "html H>html",
  ],
  {
   "url-exclude" => [ sub { push @::url_exc, $::value; },
		      "Add a regular expressions for URLs to ignore.",
		      "EXCLUDE RE" ],
   "url-include" => [ sub { push @::url_inc, $::value; },
		      "Give regular expression for URLs to check (if this "
		      . "option is given others aren't checked).",
		      "INCLUDE RE" ],
   "page-exclude" => [ sub { push @::page_exc, $::value; },
		       "Add a regular expressions for pages to ignore.",
		       "EXCLUDE RE" ],
   "page-include" => [ sub { push @::page_inc, $::value; },
		       "Give regular expression for URLs to check (if this "
		       . "option is given others aren't checked).",
		       "INCLUDE RE" ],
#     "since" => [ \&makevalue,	#FIXME process time strings
#  		"Only list links who's status has changed since the "
#  		. "given time.",
#  		"TIME" ],

   "all-links" => [ \&maketrue,
		    "Report information about every URL." ],
   "broken" => [ \&maketrue,
	       "Report links which are considered broken." ],
   "not-perfect" => [ \&maketrue,
		      "Report any URL which wasn't okay at last test." ],
   "okay" => [ \&maketrue,
	       "Report links which have been tested okay." ],
   "redirected" => [ \&maketrue,
		   "Report links which are redirected." ],
   "disallowed" => [ \&maketrue,
		   "Report links for which testing isn't allowed." ],
   "unsupported" => [ \&maketrue,
		   "Report links which we don't know how to test." ],
   "ignore-missing" => [ \&maketrue,
			 "Don't complain about links which aren't in "
			 . "the database." ],
   "url-file" => [ sub { print "reading urlfile $::value" if $::verbose;
                         open URLS, "<$::value"; my @urls=<URLS>;
			 foreach (@urls) { s/\s*$//; s/\s*// }
			 push @::urls, @urls;
			 $::url_report=1;
		       },
		   "Read all URLs in a file (one URL per line).",
		   "FILENAME"],
   "url" => [ sub { push @::urls, split /\s+/, $::value; $::url_report=1; },
	      "Give URLs which are to be reported on.",
	      "URLs"],
   "infostructure" => [ \&maketrue,
			"Check on links in the given infostructure (or "
			. "default).",
			"NAME" ],
   "config-file" => [ sub {
			eval {require $::value};
			die "Additional config failed: $@"
			  if $@; #if it's not there die anyway. compare Config.pm
		      },
		      "Load in an additional configuration file",
		      "FILENAME" ],
   "link-index" => [ sub { $::link_index=$::value; },
		     "Use the given file as the index of which file has "
		     . "what link.",
		     "FILENAME" ],
   "link-database" => [ sub { $::links=$::value; },
			"Use the given file as the dbm containing links.",
			"FILENAME" ],

   "url-base" => [ \&makevalue,	#FIXME process time strings
		   "Regex for base of the infostructure (first part of s///).",
		   "REGEX" ],
   "file-base" => [ \&makevalue,	#FIXME process time strings
		    "The base of files to be used (second part of s///).",
		    "STRING" ],
   "html" => [ \&maketrue,
	       "Report status of links in html format." ],
   "long-list" => [ sub { $::long_list=1; $::infostructure=1; },
		    "Where possible, identify the file and long list it "
		    . "(implies infostructure).  This is used for emacs "
		    . "check-all-dired." ],
  };
$::opthandler->std_opts;

$::opthandler->check_opts;

sub usage() {
  print <<EOF;
link-report [options]

EOF
  $::opthandler->list_opts;
  print <<EOF;

Report on the status of links, getting the links either from the
database, from the index file or from the command line.
EOF
}

sub version() {
  print <<'EOF';
link-report version
$Id: link-report.pl,v 1.21 2002/01/06 21:18:43 mikedlr Exp $
EOF
}

if ($::verbose) {
  $WWW::Link::Reporter::verbose=0xFF;
}

##############################################################################
#consistency checks

if (@::urls) {
  die "If you specify URLS then we can't use exclude or include regexes"
    if (@::url_exc || @::url_inc 
	|| @::page_exc || @::page_exc);
}

die  "Page and url exclude are incompatible.  Maybe you can help?"
  if (@::url_exc || @::url_inc 
	and @::page_exc || @::page_exc);

##############################################################################
#end command line processing

die 'you must define the $::links configuration variable'
    unless $::links;
$::linkdbm = tie %::links, "MLDBM", $::links, O_RDONLY, 0666, $::DB_HASH
  or die $!;

(@::url_exc || @::url_inc) and
  $::include=WWW::Link::Selector::gen_include_exclude @::url_exc, @::url_inc;

(@::page_exc || @::page_inc) and
  $::include=WWW::Link::Selector::gen_include_exclude @::page_exc, @::page_inc;

$::include=sub {return 1} unless $::include;


($::infostructure) && do {
  die 'you must define the $::link_index configuration variable'
    unless $::link_index;
  die 'you must define the $::page_index configuration variable'
    unless $::page_index;
  $::index = undef;
  $::index = new CDB_File::BiIndex ($::page_index, $::link_index);
};


($html) && do {
  ($::long_list) && die "long list option is not compatible with html";
  $::reporter=new WWW::Link::Reporter::HTML (\*STDOUT, $::index);
};

($::long_list) && do {
    die "you need to provide an index for long listing" unless $::index;
    $::url_base=$WWW::Link::Repair::infostrucbase unless defined $::url_base;
    $::file_base=$WWW::Link::Repair::filebase unless defined $::file_base;
    die "URL base undefined.  Use --urlbase or put it in the config file."
      unless $::url_base;
    die "FILE base undefined.  Use --filebase or put it in the config file."
      unless $::file_base;
    $::reporter=new WWW::Link::Reporter::LongList 
      ($::index, $::url_base, $::file_base);
};

defined $::reporter  or do {
  $::reporter=new WWW::Link::Reporter::Text $::index;
};


if ($::all_links || $::broken || $::not_perfect || $::okay || $::redirected
    || $::ignore_missing || $::disallowed || $::unsupported) {
  $::reporter->all_reports(0);
  $::all_links && $::reporter->all_reports(1);
  $::not_perfect and do {
    $::reporter->report_not_perfect(1);
  };
  $::reporter->report_broken(1) if $::broken;
  $::reporter->report_redirected(1) if $::redirected;
  $::reporter->report_disallowed(1) if $::disallowed;
  $::reporter->report_unsupported(1) if $::unsupported;
  $::reporter->report_okay(1) if $::okay;
} else {
  $::reporter->default_reports();
  $::reporter->all_reports(1) if @::urls; #report all links
}

CASE: {
  ($::url_report ) && do {
    print STDERR "Reporting on specific urls:", join (" ", @::urls), "\n"
      if $::verbose & 16;
    $::selectfunc =
      WWW::Link::Selector::generate_url_func (\%::links,$::reporter,@::urls );
    last CASE;
  };
  (@::page_exc || @::page_inc ) && do {
    die "page filtering only works in infostructure mode" unless $::index;
    print STDERR "Reporting on filtered pages from the database.\n"
      if $::verbose & 16;
    $::selectfunc =
      WWW::Link::Selector::generate_index_select_func
	  ( \%::links, $::reporter, $::include, $::index, );
    last CASE;
  };
  print STDERR "Reporting on filtered URLs direct from database.\n"
    if $::verbose & 16;
  $::selectfunc =
    WWW::Link::Selector::generate_select_func
	( \%::links, $::reporter, $::include, $::index, );
}

$WWW::Link::Selector::ignore_missing = $::ignore_missing;

$::reporter->heading;
&$::selectfunc;
$::reporter->footer;

print STDERR "finished reporting on links\n"
  if $::verbose;
