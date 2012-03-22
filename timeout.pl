#!/usr/bin/perl

# perl version of timeout
# I've found that timeout doesn't work quite right
# noninteractively, so I wrote this
#
# timeouts are in minutes

use strict;

my $duration = shift();
if ( $duration !~ /^\d+$/ ) {
    die "Duration must be an integer specifying the number of minutes to wait";
}

my $majorPid = getppid();
my $commandPid = fork();
if ( !defined( $commandPid ) ) {
    die "Failed to fork 1";
} elsif ( $commandPid == 0 ) {
    # process that executes the actual command
    my $command = join( " ",  @ARGV );
    exec( $command );
} else { #( $commandPid > 0 ) {
    my $watchPid = fork();
    if ( !defined( $watchPid ) ) {
	die "Failed to fork 2";
    } elsif ( $watchPid > 0 ) {
	waitpid( $commandPid, 0 );
	$commandPid = undef;
	kill 2, $watchPid;
	exit( 0 );
    } else { # ( $watchPid == 0 ) {
	my $secondsWaited = 0;
	while ( $secondsWaited < $duration * 60 ) {
	    $secondsWaited += sleep( 60 );
	}

	# UGLY HACK
	# ideally, I'd like to do:
	# kill 2 $commandPid, which will kill only the command process
	# however, I've found that this doesn't always kill subprocesses
	# (sbt being a major offender). I'm still not certain why 
	# kill -2, $commandPid doesn't work either (sbt in mind)
	kill -2, $majorPid;

	# this would be needed if the above line were more precise
	#kill 2, getppid();
    }
}
