=head1 DESCRIPTION

Just a small utility script that sets up some variables and cleans up
some files before each test.  We normally start by deleting files used
by the progrms during their work so that we have repeatable and
reliable state.

We create the file .cgi-infostruc.pl.

=cut

print STDERR "fixing up files; the current directory is ", cwd, "\n"
  if $verbose & 8;

#setup files for start of tests

$conf='.cgi-infostruc.pl';
$blib=cwd . '/blib'; $script=$blib . '/script';
$lonp='link_on_page.cdb'; $phasl='page_has_link.cdb';
$urls='urllist'; $linkdb='test-links.bdbm'; $sched='schedule.bdbm';

unlink $lonp, $phasl, $linkdb, $urls, $conf, $sched;

open (CONFIG, ">$conf") or die "can't open conf file: $conf";
print CONFIG <<"EOF";
\$::links="$linkdb";
\$::page_index="$phasl";
\$::link_index="$lonp";
\$::schedule="$sched";
EOF
close CONFIG  or die "can't close conf file: $conf";;

3921;
