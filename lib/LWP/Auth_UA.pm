package LWP::Auth_UA.pm;

@ISA=qw(LWP::UserAgent.pm);

use strict;
use warnings;

=head1 NAME

LWP::Auth_UA.pm - a user agent which knows some authorisation tokens

=head1 DESCRIPTION

This is a LWP user agent which is almost identical to the normal user
agent except that if it reaches a situation where it needs an
authentication token then it will automaticall retrieve it from a file
if it is there.

Storing authentication tokens in a file is inherently a security
issue.  This risk may, however, not be much higher than the one that
you are currently carrying, so this can be useful.

This page describes how this works and how to ensure that the security
risks you are taking on are not greater than are acceptable to you.

As with the rest of LinkController, there is no warantee.  If you have
an environment in which this might be a problem, you should definitely
find someone to look over your installation and ensure that everything
is done correctly.  Of course, this is true of every piece of software
you install.

=head1 SECURITY RISKS

The fundamental security problem with this system is that the
authentication token must be stored somewhere where the program can
access it.  This is because link-controller has to send the actual
authentication token over the link to authenticate.  Since it's very
easy to monitor the inputs and outputs of a program, it's very easy to
monitor this password.

This applies even if we keep the password in some encrypted form,
since we then have to store the decryption key in the program which
can then be found and used to decrypt the key.  

So there are only two possible defenses:

=over 4

=item *

make sure that the program data remains secret

=item *

make sure that the passwords the program has can't do any real damage

=back

We demand permissions on our files which protect against accidental
disclosure by encouraging the user to be more secure.  

Making sure that the program can't do any damage is normally achieved
by giving it a dedicated account which has only read only privilages
and, preferably, can only use it's privilages from a specified IP
address which will be the host on which the link checking is run.

=head2 Accidental Sending of Tokens

Another authentication risk is that the system will send it to a
server which is trying to trick it.  This is again difficult to
protect against.  The only solution in this case is to ensure that the
regular expression used for limiting the URI matches only host names
which are under the control of the body responsible for handing out
the authentication token.

=head2 Sending of Tokens over Insecure protocols

If an insecure protocol like HTTP is used for sending an
authentication token, then it is possible for someone to listen to the
transaction and record the token for later use.

The protection against this is to switch over to only using secure
tokens and hard wire the protocol name into the URI regular expression.

=head1 TOKEN STORAGE

Each authentication token (password) is stored in a file with a URI
Regexp and a Relm token, separated by whitespace.

  # comment
  <uri-regexp> <authentication-token> <realm-regexp>

The location of this file is determined by the C<$::authfile>
configuration variable.

The authentication token is `encrypted' with the rot13 (Caesar)
scheme.  This is not a security measure as such.  Rather it allows
those who don't want to know the password to read the file but not
directly see the passwords.

At startup, test-link reads in the file.  Whenever a document needing
authentication is

=cut

sub get_basic_credentials {
  my $self=shift;
  my $realm=shift;
  my $uri=shift;
  my $proxy=shift;
  my $credentials=$self->{Auth_UA-credentials};
  $credentials=$self->aua_load_credentials() unless defined $credentials;
  foreach ( @$credentials ) {

  };
  
}

sub aua_load_credentials {
  my $self=shift;
  my $file=$self->{Auth_UA-authfile};
  open my $cred, $file;
  while ( <$cred> ) {
    my ($realm, $auth, $uri_re) = m/
  };
}

sub aua_authfile {
  my $self=shift;
  return $self->{Auth_UA-authfile} unless @_;
  $self->{Auth_UA-authfile} = shift;
}
