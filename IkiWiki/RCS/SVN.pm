#!/usr/bin/perl -T
# For subversion support.

use warnings;
use strict;

package IkiWiki;

sub svn_info ($$) { #{{{
	my $field=shift;
	my $file=shift;

	my $info=`LANG=C svn info $file`;
	my ($ret)=$info=~/^$field: (.*)$/m;
	return $ret;
} #}}}

sub rcs_update () { #{{{
	if (-d "$config{srcdir}/.svn") {
		if (system("svn", "update", "--quiet", $config{srcdir}) != 0) {
			warn("svn update failed\n");
		}
	}
} #}}}

sub rcs_prepedit ($) { #{{{
	# Prepares to edit a file under revision control. Returns a token
	# that must be passed into rcs_commit when the file is ready
	# for committing.
	# The file is relative to the srcdir.
	my $file=shift;
	
	if (-d "$config{srcdir}/.svn") {
		# For subversion, return the revision of the file when
		# editing begins.
		my $rev=svn_info("Revision", "$config{srcdir}/$file");
		return defined $rev ? $rev : "";
	}
} #}}}

sub rcs_commit ($$$) { #{{{
	# Tries to commit the page; returns undef on _success_ and
	# a version of the page with the rcs's conflict markers on failure.
	# The file is relative to the srcdir.
	my $file=shift;
	my $message=shift;
	my $rcstoken=shift;

	if (-d "$config{srcdir}/.svn") {
		# Check to see if the page has been changed by someone
		# else since rcs_prepedit was called.
		my ($oldrev)=$rcstoken=~/^([0-9]+)$/; # untaint
		my $rev=svn_info("Revision", "$config{srcdir}/$file");
		if (defined $rev && defined $oldrev && $rev != $oldrev) {
			# Merge their changes into the file that we've
			# changed.
			chdir($config{srcdir}); # svn merge wants to be here
			if (system("svn", "merge", "--quiet", "-r$oldrev:$rev",
			           "$config{srcdir}/$file") != 0) {
				warn("svn merge -r$oldrev:$rev failed\n");
			}
		}

		if (system("svn", "commit", "--quiet", "-m",
		           possibly_foolish_untaint($message),
			   "$config{srcdir}") != 0) {
			my $conflict=readfile("$config{srcdir}/$file");
			if (system("svn", "revert", "--quiet", "$config{srcdir}/$file") != 0) {
				warn("svn revert failed\n");
			}
			return $conflict;
		}
	}
	return undef # success
} #}}}

sub rcs_add ($) { #{{{
	# filename is relative to the root of the srcdir
	my $file=shift;

	if (-d "$config{srcdir}/.svn") {
		my $parent=dirname($file);
		while (! -d "$config{srcdir}/$parent/.svn") {
			$file=$parent;
			$parent=dirname($file);
		}
		
		if (system("svn", "add", "--quiet", "$config{srcdir}/$file") != 0) {
			warn("svn add failed\n");
		}
	}
} #}}}

sub rcs_recentchanges ($) { #{{{
	my $num=shift;
	my @ret;
	
	eval q{use CGI 'escapeHTML'};
	eval q{use Date::Parse};
	eval q{use Time::Duration};
	
	if (-d "$config{srcdir}/.svn") {
		my $svn_url=svn_info("URL", $config{srcdir});

		# FIXME: currently assumes that the wiki is somewhere
		# under trunk in svn, doesn't support other layouts.
		my ($svn_base)=$svn_url=~m!(/trunk(?:/.*)?)$!;
		
		my $div=qr/^--------------------+$/;
		my $infoline=qr/^r(\d+)\s+\|\s+([^\s]+)\s+\|\s+(\d+-\d+-\d+\s+\d+:\d+:\d+\s+[-+]?\d+).*/;
		my $state='start';
		my ($rev, $user, $when, @pages, @message);
		foreach (`LANG=C svn log --limit $num -v '$svn_url'`) {
			chomp;
			if ($state eq 'start' && /$div/) {
				$state='header';
			}
			elsif ($state eq 'header' && /$infoline/) {
				$rev=$1;
				$user=$2;
				$when=concise(ago(time - str2time($3)));
		    	}
			elsif ($state eq 'header' && /^\s+[A-Z]\s+\Q$svn_base\E\/([^ ]+)(?:$|\s)/) {
				my $file=$1;
				my $diffurl=$config{diffurl};
				$diffurl=~s/\[\[file\]\]/$file/g;
				$diffurl=~s/\[\[r1\]\]/$rev - 1/eg;
				$diffurl=~s/\[\[r2\]\]/$rev/g;
				push @pages, {
					link => htmllink("", pagename($file), 1),
					diffurl => $diffurl,
				} if length $file;
			}
			elsif ($state eq 'header' && /^$/) {
				$state='body';
			}
			elsif ($state eq 'body' && /$div/) {
				my $committype="web";
				if (defined $message[0] &&
				    $message[0]->{line}=~/^web commit by (\w+):?(.*)/) {
					$user="$1";
					$message[0]->{line}=$2;
				}
				else {
					$committype="svn";
				}
				
				push @ret, { rev => $rev,
					user => htmllink("", $user, 1),
					committype => $committype,
					when => $when, message => [@message],
					pages => [@pages],
				} if @pages;
				return @ret if @ret >= $num;
				
				$state='header';
				$rev=$user=$when=undef;
				@pages=@message=();
			}
			elsif ($state eq 'body') {
				push @message, {line => escapeHTML($_)},
			}
		}
	}

	return @ret;
} #}}}

1
