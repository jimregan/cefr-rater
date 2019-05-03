#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use Lingua::EN::Inflexion;
use Data::Dumper;

# https://englishprofile.org/wordlists/evp?task=downloadCSV
my $BE_FILENAME = 'English Vocabulary Profile Online - British English.csv';
open(DICT, '<', $BE_FILENAME);

my %lexical_or = map { $_ => 1 } qw/11337 11857 11883 13645 13647 13650 13843 13932 13933 15360 15607 15608/;
my %slash_splits = map { $_ => 1 } qw/15629 15490/;

my %lmap = (
    'A1' => 1,
    'A2' => 2,
    'B1' => 3,
    'B2' => 4,
    'C1' => 5,
    'C2' => 6,
);
sub level_lt {
    my $a = shift;
    my $b = shift;
    return ($lmap{$a} < $lmap{$b}) ? 1 : 0;
}
my %phrases = map { $_ => () } keys %lmap;
my %simple_words = ();
my %simple_totals = map { $_ => 0 } keys %lmap;

sub addforms {
    my $word = shift;
    my $pos = shift;
    my $level = shift;
    if($pos eq 'noun' || $pos eq 'verb') {
        my $regex = ($pos eq 'noun') ? noun($word)->as_regex : verb($word)->as_regex;
        for my $form (split/\|/, substr($regex, 5, -1)) {
            if(exists $simple_words{$form}) {
                if(level_lt($simple_words{$form}, $level)) {
                    $simple_words{$form} = $level;
                }
            } else {
                $simple_words{$form} = $level;
            }
        }
    } else {
        if(exists $simple_words{$word}) {
            if(level_lt($simple_words{$word}, $level)) {
                $simple_words{$word} = $level;
            }
        } else {
            $simple_words{$word} = $level;
        }
    }
}

sub regexify {
    my $in = shift;
    $in =~ s/\, etc.$//;
    $in =~ s/\, etc. / /;
    $in =~ s/ (sb\/sth$|sth\/sb$|sth$|sb$)//;
    my @words = split/ /, $in;
    my $out = '';
    for(my $i = 0; $i <= $#words; $i++) {
        my $w = $words[$i];
        my $parens = 0;
        if(substr($w, 0, 1) eq '(' && substr($w, -1) eq ')') {
            $w = substr($w, 1, -1);
            $parens = 1;
        }
        if($w eq 'sb' || $w eq 'sb/sth' || $w eq 'sth/sb') {
            $w = '(?:me|you|him|her|it|us|them|[A-Za-z]+(?: ?[A-Za-z]+)?)';
        } elsif($w eq "sth") {
            $w = '(?:[A-Za-z]+(?: ?[A-Za-z]+)?)';
        } elsif($w eq "sb's") {
            $w = "(?:my|your|his|her|its|our|their|[A-Za-z]+(?: ?[A-Za-z]+)?'s)";
        } elsif($w =~ /\//) {
            $w =~ s!/!|!g;
            $w = "(?:$w)";
        }
        if($parens) {
            $out .= '(?:';
        }
        $out .= $w;
        if($i != $#words) {
            if($parens) {
                $out .= ' )?';
            } else {
                $out .= ' ';
            }
        } else {
            if($parens) {
                $out .= ')?';
            }
        }
    }
    return $out;
}

sub dumppunct {
    my $in = shift;
    $in =~ s/[\.\?,!"']$//;
    $in =~ s/^['"]//;
    $in;
}

my @names = ();
my @unknown = ();
sub check_simple {
    my $raw = shift;
    my $nopunct = dumppunct($raw);
    my $lower = lc($nopunct);
    if(exists $simple_words{$raw}) {
        my $lvl = $simple_words{$raw};
        $simple_totals{$lvl}++;
    } elsif(exists $simple_words{$nopunct}) {
        my $lvl = $simple_words{$nopunct};
        $simple_totals{$lvl}++;
    } elsif(exists $simple_words{$lower}) {
        my $lvl = $simple_words{$lower};
        $simple_totals{$lvl}++;
   } elsif($nopunct =~ /[A-Z][a-z]+/) {
        push @names, $nopunct;
    } else {
        push @unknown, $nopunct;
    }
}

while(<DICT>) {
    chomp;
    s/\r//;
    s/^\N{BOM}//;
    next if(/^#/);
    next if(/"Base Word"/);
    if(/^([0-9]+);([^;" ]+);([^;]*)?;([ABC][12]);(.*)$/) {
        my $id = $1;
        my $word = $2;
        my $level = $4;
        my $pos = $5;
        if($id eq '14225') {
            addforms('first-rate', 'phrase', $level);
            addforms('second-rate', 'phrase', $level);
            addforms('third-rate', 'phrase', $level);
        } else {
            addforms($word, $pos, $level);
        }
    } elsif(/^([0-9]+);"([^"]+)";([^;]*)?;([ABC][12]);(.*)$/) {
#        print "Complex: $_\n";
    } else {
        print "NO MATCH: $_\n";
    }
}

my $text = '';
while(<STDIN>) {
    chomp;
    s/\r//;
    $text .= " $_";
}
$text =~ s/^ //;
my @words = split/ /, $text;
for my $simple (@words) {
    check_simple($simple);
}

print "Raw wordcount: $#words\n";
for my $levelout (qw/A1 A2 B1 B2 C1 C2/) {
    my $cnt = $simple_totals{$levelout};
    my $pct = sprintf("%.2f", $cnt / $#words * 100);
    print "Level $levelout: $cnt ($pct%)\n";
}
