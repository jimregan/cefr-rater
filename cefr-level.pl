#!/usr/bin/perl

use warnings;
use strict;
use utf8;

# https://englishprofile.org/wordlists/evp?task=downloadCSV
my $BE_FILENAME = 'English Vocabulary Profile Online - British English.csv';
open(DICT, '<', $BE_FILENAME);

my %lexical_or = map { $_ => 1 } qw/11337 11857 11883 13645 13647 13650 13843 13932 13933 15360 15607 15608/;

sub level_gte {
    my $a = shift;
    my $b = shift;
    my %lmap = (
        'A1' => 1,
        'A2' => 2,
        'B1' => 3,
        'B2' => 4,
        'C1' => 5,
        'C2' => 6,
    );
    return ($lmap{$a} > $lmap{$b}) ? 1 : 0;
}

while(<DICT>) {
    chomp;
    s/\r//;
    s/^\N{BOM}//;
    next if(/^#/);
    next if(/"Base Word"/);
    if(/^([0-9]+);([^;" ]+);([^;]*)?;([ABC][12]);(.*)$/) {
        print "Simple: $_\n";
    } elsif(/^([0-9]+);"([^"]+)";([^;]*)?;([ABC][12]);(.*)$/) {
        print "Complex: $_\n";
    } else {
        print "NO MATCH: $_\n";
    }
}