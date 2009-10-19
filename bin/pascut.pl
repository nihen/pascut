#!/usr/bin/perl
use utf8;
binmode *STDOUT, ':utf8';

use File::ChangeNotify;
use IPC::Open2;
use Path::Class qw/file dir/;

if ( !$ARGV[0] ) {
    print "Usage: pascut.pl assrcdir\n";
    exit;
}

my $as_src = dir($ARGV[0])->resolve;
my %compile_id = ();

open2(my $in, my $out, 'fcsh');
binmode $in, ':utf8';
binmode $out, ':utf8';

# first skip
read_until_wait();

all_compile();


# my watcher
my $watcher = File::ChangeNotify->instantiate_watcher(
    directories => [$as_src->stringify],
    filter      => qr/\.as$/,
);

print "start watch\n";
# blocking
while ( my @events = $watcher->wait_for_events() ) {
    my %already = ();
    foreach my $event ( @events ) {
        if ( $already{$event->path} ) {
            next;
        }
        $already{$event->path} = 1;
        my $file = $event->path;
        if ( $file =~ m{(.*)\.as$} ) {
            if ( -e $1 . '-config.xml' ) {
                print "re-compile: $file\n";
                compile($file);
            }
            else {
                print "all compile\n";
                all_compile();
                last;
            }
        }
    }
}

sub all_compile {
    $as_src->recurse(callback => sub {
        my $file = shift;
        if ( $file =~ m{(.*)\.as$} ) {
            if ( -e $1 . '-config.xml' ) {
                print "compile: $file\n";
                compile($file);
            }
        }
    });
}

sub compile {
    my $file = shift;

    if ( $compile_id{$file} ) {
        print {$out} "compile $compile_id{$file}\n";
        print "recompile_id: $compile_id{$file}\n";
    }
    else {
        print {$out} "mxmlc +configname=air $file\n";
        my $compile_id = get_compile_id(read_until_wait());
        if ( $compile_id ) {
            print "compile_id: $compile_id\n";
            $compile_id{$file} = $compile_id;
        }
    }
}

sub get_compile_id {
    my $str = shift;

    if ( $str =~ m/fcsh: Assigned (\d+) as the compile target id/ ) {
        return $1;
    }
    elsif ( $str =~ m/fcsh: コンパイルのターゲット ID として (\d+) が割り当てられました/ ) {
        return $1;
    }
    return;
}

sub read_until_wait {
    my $in_str = '';

    while ( sysread($in, my $line, 1024) ) {
        $in_str .= $line;
        if ( $line =~ m/^\(fcsh\)/ ) {
            last;
        }
    }

    return $in_str;
}


1;

