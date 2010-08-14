#!/usr/local/bin/perl -w
use strict;
use Template;
my $t = shift || die "Name of the template?\n";
my $template = Template->new();
my $a = $template->process($t, {INTERPOLATE  => 1, INCLUDE_PATH => '.',});
