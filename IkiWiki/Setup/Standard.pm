#!/usr/bin/perl
# Standard ikiwiki setup module.
# Parameters to import should be all the standard ikiwiki config stuff,
# plus an array of wrappers to set up.

use warnings;
use strict;
use IkiWiki::Wrapper;
use IkiWiki::Render;

package IkiWiki::Setup::Standard;

sub import {
	IkiWiki::setup_standard(@_);
}
	
package IkiWiki;

sub setup_standard {
	my %setup=%{$_[1]};

	$setup{plugin}=$config{plugin};
	if (exists $setup{add_plugins}) {
		push @{$setup{plugin}}, @{$setup{add_plugins}};
		delete $setup{add_plugins};
	}
	if (exists $setup{disable_plugins}) {
		foreach my $plugin (@{$setup{disable_plugins}}) {
			$setup{plugin}=[grep { $_ ne $plugin } @{$setup{plugin}}];
		}
		delete $setup{disable_plugins};
	}
	if (exists $setup{exclude}) {
		$config{wiki_file_prune_regexp}=qr/$config{wiki_file_prune_regexp}|$setup{exclude}/;
	}

	if (! $config{refresh} || $config{wrappers}) {
		debug("generating wrappers..");
		my @wrappers=@{$setup{wrappers}};
		delete $setup{wrappers};
		my %startconfig=(%config);
		foreach my $wrapper (@wrappers) {
			%config=(%startconfig, verbose => 0, %setup, %{$wrapper});
			checkconfig();
			gen_wrapper();
		}
		%config=(%startconfig);
	}
	
	foreach my $c (keys %setup) {
		if (defined $setup{$c}) {
			if (! ref $setup{$c}) {
				$config{$c}=possibly_foolish_untaint($setup{$c});
			}
			elsif (ref $setup{$c} eq 'ARRAY') {
				$config{$c}=[map { possibly_foolish_untaint($_) } @{$setup{$c}}]
			}
			elsif (ref $setup{$c} eq 'HASH') {
				foreach my $key (keys %{$setup{$c}}) {
					$config{$c}{$key}=possibly_foolish_untaint($setup{$c}{$key});
				}
			}
		}
		else {
			$config{$c}=undef;
		}
	}

	if (! $config{refresh}) {
		$config{rebuild}=1;
		debug("rebuilding wiki..");
	}
	else {
		debug("refreshing wiki..");
	}

	loadplugins();
	checkconfig();
	lockwiki();
	loadindex();
	refresh();

	debug("done");
	saveindex();
}

1
