#!/usr/bin/perl -w

=head1 NAME

fix-link - identify files affected by a link change and fix them

=head1 SYNOPSIS

fixlink-as-text.pl [arguments] old-link new-link

=head1 DESCRIPTION

This program is designed to change one uri to another one throughout
an infostructure (group of interlinked files).  Normally the program
uses an index built up for link testing to make this operation fast by
examining only those files which have links needing changed.

B<This program is not designed to run SUID.  Instead the user is meant
to have access to the files that are to be changed.>


=head1 FILE LOCATION MODES

=head2 Find Files by directory

Goes through all of the files in a directory.  It changes checks all
files to see if they need to be changed.

=head2 Find Files by index file

Goes through the index file looking for all URIs that need to be
corrected then corrects those.

=head1 SUBSTITUTION MODES

=head2 Do simple textual substitutions

Here we just substitute string for string.  See "HOW IT WORKS" below.

=head2 Do file parsing to find uris

Not yet implemented.  Here we go through each file parsing it
properly.  This is the only way for binary formats.

=head1 RELATIVE LINKS

With the B<--relative> option we can search for relative links.  This
is more dangerous (more chance of a false match) and slower, but will
be needed if you move files within your own web pages and need to
correct links to them.

=head1 HOW IT WORKS

This discussion covers how we do substitution in HTML documents.  It's
a bit out of date.

The proper way to do this is to parse each bit of the document, then
identify the links, convert them to the most cannonical form possible
and compare them to the original uri.  If they match then replace them
with the new one (possibly in a relative form).

This is great if:-
  a) your document is not broken

  b) you don't have any links outside the link text (more common than
  you would like to imagine, think of every `we have changed to a new
  site' notice)

So we resort to the following brute force approach:-

  a) if it looks like the original absolute link substitute it no
  matter what.

  b) if it looks like the relative form and seems to be in an
  attribute substitute it and warn what we are doing.

  c) if it looks like the relative form, but isn't in an attribute
  then bitch about it, but do nothing.

Your files should

  a) have the right level of quoting

  b) not have any uris containing [stuff]/fred/../[stuff]

=head1 TODO

Add extra formats.


=head1 SEE ALSO

L<verify-link-control(1)>; L<extract-links(1)>; L<build-schedule>
L<link-report(1)>; L<fix-link(1)>; L<link-report.cgi(1)>; L<fix-link.cgi>
L<suggest(1)>; L<link-report.cgi(1)>; L<configure-link-control>

The LinkController manual in the distribution in HTML, info, or
postscript formats, included in the distribution.

http://scotclimb.org.uk/software/linkcont - the
LinkController homepage.

=cut

use File::Find;
use File::Copy;
use CDB_File::BiIndex;
use Fcntl;
use DB_File;
use MLDBM qw(DB_File);
use WWW::Link::Repair::Substitutor;
use WWW::Link::Repair;
use URI;
use strict;

#Configuration - we go through %ENV, so you'd better not be running SUID
#eval to ignore if a file doesn't exist.. e.g. the system config

use WWW::Link_Controller::ReadConf;

#controls - not really configurations right now.

#$::secret_suggestions=0; #whether the user wants to tell others about changes

use vars qw();

use Getopt::Function qw(maketrue makevalue);
$::verbose=0;
$::tree=0;
$::base=undef;
$::relative=undef;
$::opthandler = new Getopt::Function
  [ "version V>version",
    "usage h>usage help>usage",
    "help-opt=s",
    "verbose:i v>verbose",
    "",
#    "link-index=s",
    "directory=s",

    "tree t>tree",
    "base=s b>base",
  ],  {
#         "link-index" => [ sub { $::link_index=$::value; },
#  			 "Use the given file as the index of which file has "
#  			 . "what link.",
#  			 "FILENAME" ],
       "directory" => [ \&makevalue,
			 "correct all files in the given directory"
			 . "what link.",
			 "DIRNAME" ],
#   "mode" => [ sub { $::link_index=$::value; },
#  		  "Use the given file as the index of which file has "
#  		  . "what link.",
#  		  "FILENAME" ],
       "tree" => [ \&maketrue,
		   "Fix the link and any others based on it." ],
       "relative" => [ \&maketrue,
		   "Fix relative links (expensive??)." ],
       "base" => [ \&makevalue,
		   "Base uri of the document or directory to be fixed.",
		   "FILENAME" ],
  };

$::opthandler->std_opts;

$::opthandler->check_opts;

sub usage() {
  print <<'EOF';
fix-link [options] old-link new-link

EOF
  $::opthandler->list_opts;
print <<'EOF';

Replace any occurences of OLD-LINK with NEW-LINK using link index file
to locate which files OLD-LINK occurs in.
EOF
}

sub version() {
  print <<'EOF';
fix-link version
$Id: fix-link.pl,v 1.10 2001/11/22 15:33:21 mikedlr Exp $
EOF
}

my $origuri=shift;
die "missing arguments, giving up\n" unless @ARGV;
my $newuri=shift;

#FIXME: CHANGE EVERYTHING TO USE URI RATHER THAN URL
#make the uris absolute.

if (defined $::base) {
  my $origuri_obj = new URI $origuri;
  my $newuri_obj = new URI $newuri;

  my $orig_abs = $origuri_obj->abs($::base);
  my $new_abs = $newuri_obj->abs($::base);

  $origuri = $orig_abs->as_string();
  $newuri = $new_abs->as_string();
}

print STDERR "going to change $origuri to $newuri\n" if $::verbose;

$::substitutor=
  WWW::Link::Repair::Substitutor::gen_substitutor ( $origuri, $newuri,
					       $::tree, $::relative);

$::handler=
  WWW::Link::Repair::Substitutor::gen_simple_file_handler($::substitutor);

unless ( $::directory  ) {

  #we could create new links as we go along.  We could delete old ones
  #but I don't see why..  Best that I can see is to output a list of
  #any new URLs we create..
  #
  #    die 'you must define the $::links configuration variable'
  #      unless $::links;
  #    tie %::links, MLDBM, $::links, O_RDONLY, 0666, $DB_HASH
  #      or die $!;
  # we go RDONLY but if we want to make suggestions that will have to change

  die 'you must define the $::link_index configuration variable'
    unless $::link_index;
  die 'you must define the $::page_index configuration variable'
    unless $::page_index;
  $::index = new CDB_File::BiIndex $::page_index, $::link_index;

  print STDERR "using index to find files\n" if $::verbose;

  WWW::Link::Repair::infostructure($::index, $::handler, $origuri);

} else {

  print STDERR "searching through directory $::directory\n" if $::verbose;

  WWW::Link::Repair::directory($::handler, $::directory)
}

exit;
