#!/usr/bin/perl -w

=head1 NAME

configure-link-cgi - configure a CGI that reports on or repairs links.

=head1 SYNOPSIS

configure-link-cgi.pl [options] cgi-file-name

=head1 DESCRIPTION

Each CGI program should be hardcoded with it's own configuration.
At the same time we want to use one central program file.  This is
achieved by simply building scripts which set variables and then run
the main cgi program.

This program should be run only once the basics of the linkcontroller
system have been configured for the current user with
B<configure-link-control>

=head1 OPTIONS

The C<--reporter> option will generate a CGI which reports on the
status of links.  The C<--fixer> option will generate one which can
fix links.  If both are given then both are generated.  If neither are
given then a reporter is generated by default.

=head1 TRUST

The CGI bin program trusts the perl libraries.

The CGI bin program trusts the diretory structure and that the
link_report.cgi program can be called safely.

=head1 SECURITY

The program was written to pass Perl's tainting mechanism.

The program deletes various environment variables.

    $ENV{PATH} = "/bin:/usr/bin";
    delete @ENV{qw(HOME IFS CDPATH ENV BASH_ENV)};   # Make %ENV safer

This means that the users own configuration file in the users home
directory will be ignored.  The reason for this is that CGIs aren't
guaranteed to be run by the right user.  Hardcode any of the
configuration you want to copy from there.

=head1 ISSUES

I don't think the following are bugs, but I might be wrong so you should be
aware of them.

=over

=item -

We use the WWW::Link_Controller::ReadConf module to get configuration.  This
goes poking around in home directories for configuration files and
doesn't check that the files are secure??

=item -

There are  probably issues.  If you  need security call  in a security
audit  company to  check  this  file over.   Donating  the results  is
appreciated.

=back

=head1 BUGS

None, but see ISSUES ;-)

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
use WWW::Link_Controller::ReadConf;
use WWW::Link_Controller::ReadConf::utils;
use Fcntl;

use vars qw(%config $reporter_script $fixer_script
            $reporter_filename $fixer_filename @vars);

use Getopt::Function qw(maketrue makevalue);

$::opthandler = new Getopt::Function
  [ "version V>version",
    "usage h>usage help>usage",
    "help-opt=s",
    "verbose:i v>verbose",
    "reporter r>reporter",
    "fixer f>fixer",
    "link-report=s",
    "fix-link=s",
  ],  {
      reporter => [\&maketrue, "Create a CGI for reporting on links" ],
      fixer => [\&maketrue, "Create a CGI for fixing links" ],
      "link-report" => [\&makevalue,
			"Change the location of link-report.cgi",
			"FILEPATH"],
      "fix-link" => [\&makevalue,
		     "Change the location of fix-link.cgi",
		     "FILEPATH"],
      };

$::opthandler->std_opts;

$::opthandler->check_opts;

sub usage() {
  print <<EOF;
configure-link-cgi [options] cgi-file-name

EOF
  $::opthandler->list_opts;
  print <<EOF;

Attempt to setup LinkController for basic usage.
EOF
}

sub version() {
  print <<'EOF';
configure-link-cgi version 
$Id: configure-link-cgi.pl,v 1.8 2001/12/30 12:18:27 mikedlr Exp $
EOF
}

($::reporter || $::fixer) or ($::reporter=1);

print <<EOINTRO;
              LinkController CGI Configuration

Welcome to LinkController CGI Configuration.  This program is designed
to configure a CGI program which will report on or repair given links.

EOINTRO

if ($::reporter) {
  print "\n";
  $reporter_filename = getstring( <<EOQ );

Give a filename for the link reporting CGI script.  If none is given then
it will be output to stdout...

EOQ

  print "\n";
}

if ($::fixer) {
  print "\n";
  $fixer_filename = getstring( <<EOQ );

Give a filename for the link fixing CGI script.  If none is given then
it will be output to stdout...

EOQ

  print "\n";
}

if ($::reporter) {
  $config{"url_regex"} = getstring( <<EOQ );
Give a (perl) regular expression for those URLs you want this CGI to
be able to report on (e.g. ^http://somewhere.somedom/somesite). Leave
blank if you want to allow any broken links in the links database to
be reported on.  For full details of how to write such regular expressions
see the perlre(1) manual page.
EOQ

  $config{"url_regex"} =~ m/^[a-z]{2,10}:/ and print STDERR
  "\nWarning: You should probably have started with a caret ('^')\n\n";

  print "\n";
}

if ($::fixer) {
  $config{"infostrucs"} = getstring( <<EOQ );
Give the filename of the infostrucs file where the definitions of the
infostructures to be repaired are stored.  N.B. this is the only
control on which files the CGI can edit.  See the LinkController
manual for information about the format of the file.
EOQ

  $config{"url_regex"} =~ m/^[a-z]{2,10}:/ and print STDERR
  "\nWarning: You should probably have started with a caret ('^')\n\n";

  print "\n";
}

$config{"links"} = getstring( <<EOQ );
The location of the links database file given from your configuration is
	$::links
If you want to hardwire a location into your CGI (including that one)
then give it now.  Leave blank if you want the CGI to read from the
normal configuration files.  These need to be correct for the user the
CGI script is finally run by.
EOQ

print "\n";

$config{"page_index"} = getstring( <<EOQ );
The location of the page index file given from your configuration is
	$::page_index
If you want to hardwire a location into your CGI (including that one)
then give it now.  Leave blank if you want the CGI to read from the
normal configuration files.  These need to be correct for the user the
CGI script is finally run by.
EOQ

$config{"link_index"} = getstring( <<EOQ );
The location of the link index file given from your configuration is
	$::link_index
If you want to hardwire a location into your CGI (including that one)
then give it now.  Leave blank if you want the CGI to read from the
normal configuration files.  These need to be correct for the user the
CGI script is finally run by.
EOQ

$::link_report=`which link-report.cgi`;
chomp $::link_report;
$::fix_link=`which fix-link.cgi`;
chomp $::fix_link;

if ( $::reporter ) {
  @vars=qw($::links $::page_index $::link_index $::url_regex);
  $reporter_script=cgi_script($::link_report, \@vars);
  print "The generated reporter is as follows:\n\n";
  print $reporter_script , "\n";
  if ($reporter_filename) {
    sysopen CGI, $reporter_filename, O_WRONLY | O_CREAT | O_TRUNC, 0777
      or die "couldn't open $reporter_filename";
    print CGI $reporter_script;
    close CGI or die "couldn't close $reporter_filename";
  }
}

if ( $::fixer ) {
  @vars=qw($::links $::page_index $::link_index $::infostrucs);
  $fixer_script=cgi_script($::fix_link, \@vars);
  print "The generated fixer is as follows:\n\n";
  print $fixer_script , "\n";
  if ($fixer_filename) {
    sysopen CGI, $fixer_filename, O_WRONLY | O_CREAT | O_TRUNC, 0777
      or die "couldn't open $fixer_filename";
    print CGI $fixer_script;
    close CGI or die "couldn't close $fixer_filename";
  }
}

exit 0;

sub cgi_script {
  my $cgiprogram=shift;
  my $vars=shift;

  my $perl=`which perl`;
  chomp $perl;

  my $script=`which perl`;
  chomp $perl;

  my $cgiscript .= <<"EOF" ;
#!$perl -Tw
EOF

  $cgiscript .= <<'EOF' ;
#
######################################################################
# This file has been automatically created by configure-link-cgi.    #
######################################################################
use strict;
use vars qw($dont_run_cgi $fixed_config $url_regex $links $links $link_index);
#include LinkController config files now so that we can override them
#later..
BEGIN {
EOF

  #this gives us the appropriate configuration file; I think it's safe;
  my $home=$ENV{HOME};

  $cgiscript .= <<"EOF" ;
  \$ENV{PATH} = "/bin:/usr/bin";
  \$ENV{HOME} = "$home";
  delete \@ENV{qw(HOME IFS CDPATH ENV BASH_ENV)};   # Make \%ENV safer
EOF

  $cgiscript .= <<'EOF' ;
}

$fixed_config = 1; #flag that we have been run in this way.

use WWW::Link_Controller::ReadConf;

EOF

  foreach my $varname ( @$vars ) {
    my $configname = $varname;
    $configname =~ s/^\$:://;
    next unless $config{$configname};
    $cgiscript .= <<"EOF" ;
$varname="$config{$configname}" ;

EOF
  }
  $cgiscript .= <<"EOF" ;
unless (\$dont_run_cgi) {
  defined (do "$cgiprogram") || do {
    die "parse of $cgiprogram failed: \$@" if \$@;
    die "couldn't open $cgiprogram: \$!"
  }
}
EOF
  return $cgiscript;
}
