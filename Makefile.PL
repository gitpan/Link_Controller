use ExtUtils::MakeMaker;

#we force a dependency from the install to the file copy then 
#set the copied files as exes


#sub MY::installbin {
#   my $preserve=$_;
#   ($_) = shift->SUPER::installbin(@_);
#   m/cp.*\.pl.*\.pl/ && do {
#     s/^(\s*)cp/${1}perl perlstart.PL/;
#     s/\.pl\s*$//g;
#   };
#   my $return=$_;
#   $_=$preserve;
#   $return;
# }

WriteMakefile( NAME => "Link_Controller",
               VERSION_FROM => "lib/WWW/Link_Controller/Version.pm",
               dist => {COMPRESS => "gzip",
                        SUFFIX => "gz" },
             );



