#!/usr/bin/perl -T
# Stubs for no revision control.

use warnings;
use strict;

package IkiWiki;

sub rcs_update () {
}

sub rcs_prepedit ($) {
	return ""
}

sub rcs_commit ($$$) {
	return undef # success
}

sub rcs_add ($) {
}

sub rcs_recentchanges ($) {
}

1
