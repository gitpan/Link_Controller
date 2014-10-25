package WWW::Link_Controller::ReadConf::utils;
use Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(yesno getstring);

sub yesno ($) {
  my $question=shift;
  print $question;
  my $answer=<>;
  $answer =~ m/y/ && return 1;
  return 0;
}

sub getstring ($;$){
  my $question=shift;
  my $default=shift;
  print $question;
  print "[$default]" if $default;
  my $answer=<>;
  $answer =~ m/^$/ && return $default if $default;
  chomp ($answer);
  return $answer;
}
