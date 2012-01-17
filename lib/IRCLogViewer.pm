package IRCLogViewer;
use Dancer ':syntax';

our $VERSION = '0.1';

use Time::Piece 'localtime';
use IRC::Formatting::HTML 'irc_to_html';

sub today {
  my $now = localtime;
  return split /-/, $now->ymd;
}

sub parse_line {
  my ($raw) = @_;

  my ($time, $line) = ($raw =~ / (\d{2}:\d{2}:\d{2})\] (.*)/);

  # reformat for html
  $line = irc_to_html($line, invert => 'italic');

  # make urls links
  $line =~ s|(\S+://\S+)|<a href="$1">$1</a>|g;

  return { t => $time, m => $line };
}

sub get_log {
  my ($year, $month, $day) = @_;

  my @lines = ();

  open my $file, '<', "data/$year-$month-$day.log" or return [];
  push @lines, parse_line $_ while <$file>;
  close $file;

  return \@lines;
}

sub search_logs {
  my ($query) = @_;

  my @results = ();
  my $pid = open my $child, '-|';

  unless (defined $pid) {
    error "Couldn't fork: $!";
    return [];
  }

  unless ($pid) {
    exec 'grep', '-i', $query, '-r', 'data' or error "Couldn't exec: $!";
  } else {
    while (<$child>) {
      my ($date, $line) = (m|^data/(\d{4}-\d{2}-\d{2})\.log:(.*)|);

      my $entry = parse_line $line;
      ($entry->{d} = $date) =~ s|-|/|g;

      push @results, $entry;
    }

    close $child;
  }

  return [ sort { $a->{d} cmp $b->{d} || $a->{t} cmp $b->{t} } @results ];
}

get '/' => sub {
  template 'view', {
    log   => get_log(today),
    date  => join '/', today,
  };
};

get '/search' => sub {
  template 'search', {
    log   => search_logs(params->{query}),
    query => params->{query},
  };
};

get '/:year/:month/:day' => sub {
  template 'view', {
    log   => get_log(params->{year}, params->{month}, params->{day}),
    date  => join '/', params->{year}, params->{month}, params->{day},
  };
};

any qr{.*} => sub {
  status 'not_found';
  template '404';
};

true;
