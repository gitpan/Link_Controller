#!/bin/sh
cp $HOME/.link-control.pl $HOME/.link-control.pl.bak
sed -e "s,directory-here,$PWD," dot-link-control.pl.example > $HOME/.link-control.pl
