=head2 link_url

C<link_url> looks at a candidate.

=cut

package WWW::Link_Controller::URL;
use URI::URL;
use Carp;
our $verbose;
use strict;
use warnings;

#charset definitions

sub RESERVED () { '[;/?:@&=+$]';}
sub ALPHA () { '[A-Za-z]'; }
sub ALPHA_NUM () { '[A-Za-z0-9]'; }
sub SCHEME_CHAR () { '[A-Za-z0-9+.-]'; }
sub MARK () { "[-_.!~*'()]"; }
sub UNRESERVED () { '(?:' . ALPHA_NUM . '|' . MARK . ')' };
sub ESCAPE () { '[%]'; }
sub SCHEME () { '(?:(?i)[a-z][a-z0-9+.-]*)';}
sub ABSURI () { SCHEME . ':' . '/';}

sub CONTROL () { '[\x00-\x1F\x7F]'; }

#N.B. % and # normally included here.  We don't include % since it is
#allowed as the escape character and we don't include # since within
#LinkController we consider the fragment as part of the URL in
#contradiction with the standards, since we may be interested to check
#that the exact fragment of the resource exists
sub DELIMS () { '[<>"]'; }
sub UNWISE () { '[{}|\^[]`]'; }
sub EXCLUDED () { '(?:'. CONTROL .'|'. DELIMS .'|'. UNWISE .'|'.' '.')' };
sub URIC () { '(?:' . RESERVED . '|' . UNRESERVED . '|' . ESCAPE . ')' };

#sub AUTHORITY () { '(?:(?i)[a-z][a-z0-9+.-]*)';}
#sub NET_PATH () { '//' . AUTHORITY . '/' . ABS_PATH; }


=head2 verify_url

verify url checks that a url is a valid and possible uri in the terms
of RFC2396

=cut

sub verify_url ($) {
  my $url=shift;
  my $control=CONTROL;
  # we don't print it out directly..  maybe we shouldn't even print out 
  # the warning.
  do { carp "url $url contains control characters" ;
       return undef; } if $url =~  m/$control/;
  my $exclude=EXCLUDED;
  my $ex;
  do { carp "url $url contains excluded character: $ex" ;
       return undef; } if ($ex) =  $url =~ m/($exclude)/;

  #try to identify invalid schemes.  The problem here is that it's possible
  #to have a : elsewhere in a URL so we have to be very careful.

  my $scheme=$url;

  #chop off anything which is definitely not the scheme.. this gets rid of
  #the second part of any paths etc.  This protects us against relative urls
  #which have a : in them (N.B.

  $scheme =~ s,[#/].*,, ;

  #now keep the bit preceeding the :

  ($scheme) = $scheme =~ m/^([^:]*):/;

  if ( defined $scheme ) {
    my $scheme_re= '^' . ALPHA .'('. ALPHA_NUM ."|". SCHEME_CHAR .')*$'  ;
    do { carp "url $url has illegal scheme: $scheme" ;
	 return undef; } unless $scheme =~ m/$scheme_re/;
  }

  return 1;
}

sub link_url ($$) {
  my $url=shift;
  my $base=shift;
  croak "usage link_url(<url>,<base>)" unless defined $url;

  unless (verify_url($url)) {
    warn "dropping url: $url";
  };

  $url =~ m,^(?:ftp|gopher|http|https|ldap|rsync|telnet):(?:[^/]|.[^/]),
    and do {
    warn "ERROR: ignoring relative url with scheme $url";
    return undef;
  };

  my $urlo=new URI::URL $url;
  my $aurlo=$urlo->abs($base);
  my $ret_url;
  if ( URI::eq($urlo,$aurlo) ) {
    $ret_url = $url;
  } else {
    $ret_url=$aurlo->as_string();
  }

  $ret_url =~ m,^(?:ftp|gopher|http|https|ldap|rsync|telnet):(?:[^/]|.[^/]),
    and do {
    warn "ERROR: abs(url) $url gave $ret_url";
    return undef;
  };

  print STDERR "fixed up link name $url\n"
    if $::verbose & 16 and defined $url;
  return $ret_url;
}

99;
