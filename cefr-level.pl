#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use Lingua::EN::Inflexion;
use Data::Dumper;

# https://englishprofile.org/wordlists/evp?task=downloadCSV
my $BE_FILENAME = 'English Vocabulary Profile Online - British English.csv';
open(DICT, '<', $BE_FILENAME);

my %lexical_or = map { $_ => 1 } qw/11337 11857 11883 13645 13647 13650 13843 13932 13933 15360 15607 15608 15524 15525 15526 15527 15528 15529 15532 15571/;
my %slash_splits = map { $_ => 1 } qw/15629 15490 12226/;

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
my %phrases = ();
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
    my $pos = shift;
    $in =~ s/^ +//;
    $in =~ s/ +$//;
    $in =~ s/\, etc.$//;
    $in =~ s/\, etc. / /;
    $in =~ s/ (sb\/sth$|swh\/sth$|sth\/sb$|sth$|sb$)//;
    $in =~ s/ \((sb\/sth\)$|sth\/swh\)$|sth\/sb\)$|sth\)$|swh\)$|sb\)$)//;
    $in =~ s/ \(([a-z]+(?: [a-z]+)*) (sth\)$|sb\)$)/ ($1)/;
    my $out = '';
    if($in =~ /^not be /) {
        $in =~ s/^not be //;
        $out = "(?:isn't |is not |wasn't |was not |not been |will not be |not be |won't be |are not |aren't |were not |weren't |am not )";
    } elsif($in =~ /^not be\/come /) {
        $in =~ s/^not be //;
        $out = "(?:isn't |is not |wasn't |was not |not been |will not be |not be |won't be |are not |aren't |were not |weren't |am not |not come |doesn't come |don't come |didn't come |won't come)";
    } elsif($in =~ /^not /) {
        $in =~ s/^not //;
        $out = "(?:not |doesn't |don't |didn't |won't )";
    } elsif($in =~ /^not /) {
        $in =~ s/^not have //;
        $out = "(?:not have |doesn't have |don't have |didn't have |won't have |hasn't |hadn't |haven't )";
    } elsif($in =~ / sth\/doing sth$/) {
        $in =~ s/ sth\/doing sth$/ (doing)/;
    }
    my @words = split/ /, $in;
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
        } elsif($w =~ /\(s\)$/) {
            $w =~ s/\(s\)$/s?/g;
        } elsif($w =~ /\(s\)\//) {
            $w =~ s/\(s\)\//s?\//g;
        }
        if($parens) {
            if($i != $#words) {
                $out .= "(?:$w )?";
            } else {
                $out =~ s/ $//;
                $out .= "(?: $w)?";
            }
        } else {
            if($i != $#words) {
                $out .= ' ';
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
        my $id = $1;
        my $word = $2;
        my $level = $4;
        my $pos = $5;
        if($id eq '695') {
            push @{$phrases{'B1'}}, "check-in(?: desks?)?";
            next;
        }
        if($id eq '696') {
            push @{$phrases{'B1'}}, "check-in(?: counters?)?";
            next;
        }
        if($id eq '5741') {
            push @{$phrases{'B1'}}, "modal(?:s| verbs?)?";
            next;
        }
        if($pos eq 'noun' && $word !~ /[\(\)\/]/) {
            my $aref = $phrases{$level};
            my $lemmaqueue = '';
            if($word =~ /( of .*)/) {
                $lemmaqueue = $1;
                $word =~ s/$lemmaqueue$//;
            }
            my @npieces = split/ /, $word;
            if($npieces[0] eq 'the' || $npieces[0] eq 'a' || $npieces[0] eq 'an') {
                push @{$aref}, join(' ', $word);
                next;
            } else {
                my $nounpart = noun($npieces[$#npieces])->as_regex;
                $npieces[$#npieces] = $nounpart;
                push @{$aref}, join(' ', @npieces) . $lemmaqueue;
                next;
            }
        }
        if($word =~ / or /) {
            my @p = split/ or /, $word;
            my @w1 = split/ /, $p[0];
            if($p[1] =~ /^$w1[0]/) {
                print "LEXICAL: $id\t$word\n"
            }
        }
        my @parts = ();
        if(exists $lexical_or{$id}) {
            @parts = split/ or /, $word;
        } elsif(exists $slash_splits{$id}) {
            @parts = split/ ?\/ /, $word;
        } else {
            push @parts, $word;
        }
        
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

print Dumper(\%phrases);