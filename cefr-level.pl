#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use Lingua::EN::Inflexion;
use Data::Dumper;

my $USE_PHRASES = 0;

# https://englishprofile.org/wordlists/evp?task=downloadCSV
my $BE_FILENAME = 'English Vocabulary Profile Online - British English.csv';
open(DICT, '<', $BE_FILENAME);
open(VERBS, '<', "verbs.txt");
my %verbs = ();
while(<VERBS>) {
    chomp;
    $verbs{$_} = 1;
}

sub is_verb {
    my $v = shift;
    return exists $verbs{$v};
}

my %slash_splits = map { $_ => 1 } qw/15629 15490 12226 15309 13570 12336/;

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
my %phrases = map { $_ => [] } keys %lmap;
my %single_words = map { $_ => [] } keys %lmap;
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

my %vp = map { $_ => 1 } qw/13751 14415 15010 15011 14874 13313 14903/;
my %np = map { $_ => 1 } qw/15479 15355 15309 14975 14800 14185 13404 13360 12074 11333 13333 14948/;

sub all_verbs {
    for my $v (@_) {
        if(!is_verb($v)) {
            return 0;
        }
    }
    return 1;
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
    $in =~ s/\.\.\.\??$//;

    my $out = '';
    if($in =~ /^not be /) {
        $in =~ s/^not be //;
        #$out = "(?:isn't |is not |wasn't |was not |not been |not be |won't be |are not |aren't |were not |weren't |am not )";
        $out = "(?:not |n't )";
    } elsif($in =~ /^not be\/come /) {
        $in =~ s/^not be\/come //;
        $out = "(?:isn't |is not |wasn't |was not |not been |not be |won't be |are not |aren't |were not |weren't |am not |not come |doesn't come |don't come |didn't come |won't come)";
    } elsif($in =~ /^not /) {
        $in =~ s/^not //;
        $out = "(?:not |doesn't |don't |didn't |won't )";
    } elsif($in =~ /^not have /) {
        $in =~ s/^not have //;
        $out = "(?:not have |doesn't have |don't have |didn't have |won't have |hasn't |hadn't |haven't )";
    } elsif($in =~ / sth\/doing sth$/) {
        $in =~ s/ sth\/doing sth$/ (doing)/;
    } elsif($pos eq 'phrase' || $pos eq '"phrasal verb"') {
        my @tmpwrds = split/ /, $in;
        if($tmpwrds[0] =~ /\//) {
            my @firsts = split(/\//, $tmpwrds[0]);
            if(all_verbs(@firsts)) {
                my @regexes = map { verb($_)->as_regex } @firsts;
                $out .= "(?^i:" . join("|", @regexes) . ") ";
                shift @tmpwrds;
                $in = join(' ', @tmpwrds); 
            }
        } else {
            if(is_verb($tmpwrds[0])) {
                $out .= verb($tmpwrds[0])->as_regex . ' ';
                shift @tmpwrds;
                $in = join(' ', @tmpwrds); 
            }
        }
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
                $out .= "$w ";
            } else {
                $out .= "$w";
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
        push @{$single_words{$lvl}}, $raw;
    } elsif(exists $simple_words{$nopunct}) {
        my $lvl = $simple_words{$nopunct};
        $simple_totals{$lvl}++;
        push @{$single_words{$lvl}}, $nopunct;
    } elsif(exists $simple_words{$lower}) {
        my $lvl = $simple_words{$lower};
        $simple_totals{$lvl}++;
        push @{$single_words{$lvl}}, $lower;
   } elsif($nopunct =~ /[A-Z][a-z]+/) {
        push @names, $nopunct;
    } else {
        push @unknown, $nopunct;
    }
}

sub uniq {
    my %k = map { $_ => 1 } @_;
    return keys %k;
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
        next if(!$USE_PHRASES);
        if(exists $np{$id}) {
            $pos = 'noun';
        }
        if(exists $vp{$id}) {
            $pos = '"phrasal verb"';
        }
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
        my @parts = ();
        my $ref = $phrases{$level};
        if($id eq '11383' || $id eq '13446') {
            push @{$ref}, regexify('keeb sb at arm\'s length', '"phrasal verb"');
            push @{$ref}, regexify('at arm\'s length', 'phrase');
            next;
        }
        if($word =~ / or /) {
            my @p = split/ or /, $word;
            my @w1 = split/ /, $p[0];
            if($p[1] =~ /^$w1[0]/) {
                @parts = @p;
            }
        } elsif($word =~ /;/) {
            @parts = split/; /, $word;
        } elsif(exists $slash_splits{$id}) {
            @parts = split/ ?\/ /, $word;
        } else {
            push @parts, $word;
        }

        for my $part (@parts) {
            push @{$ref}, regexify($part, $pos);
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
$text =~ s/  +/ /;
$text =~ s/ $//;
my @words = split/ /, $text;
for my $simple (@words) {
    check_simple($simple);
}

print "Raw wordcount: $#words\n";
for my $levelout (qw/A1 A2 B1 B2 C1 C2/) {
    my $cnt = $simple_totals{$levelout};
    my $pct = sprintf("%.2f", $cnt / $#words * 100);
    print "Level $levelout: $cnt ($pct%)\n";
    my @clevel = uniq(@{$single_words{$levelout}});
    if(($levelout eq 'C1' || $levelout eq 'C2') && $#clevel > 0) {
        print "Words seen $levelout:\n";
        print join(' ', @clevel);
        print "\n";
    }
}

if($USE_PHRASES) {
    for my $levelout (qw/A1 A2 B1 B2 C1 C2/) {
        my @sorted = uniq(sort { length $b <=> length $a } @{$phrases{$levelout}});
        #my $regex = '(?:' . join('|', @sorted) . ')';
        my @clevel = ();
        my $cnt = 0;
        for my $regex (@sorted) {
            while($text =~ /$regex/) {
                my $match = $1;
                push @clevel, $match;
                $cnt++;
            }
        }
        print "$levelout phrases: $cnt\n";
        if(!level_lt('B2', $levelout) && $#clevel > 0) {
            print "Phrases seen:\n";
            print join('\n', @clevel);
            print "\n";
        }
    }
}