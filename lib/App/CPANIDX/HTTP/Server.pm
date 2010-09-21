package App::CPANIDX::HTTP::Server;
 
#ABSTRACT: HTTP::Server::Simple based server for CPANIDX

use strict;
use warnings;
use DBI;
use App::CPANIDX::Renderer;
use App::CPANIDX::Queries;
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);
 
sub dsn {
  my ($self,$dsn) = @_;
  if ( $dsn and $self->{_dbh} ) {
    warn "Already have a database connection, thanks\n";
    return;
  }
  if ( $dsn ) {
    $self->{_dbh} = DBI->connect($dsn,'','') or die $DBI::errstr, "\n";
    $self->{_dsn} = $dsn;
    return;
  }
  return $self->{_dsn};
}

sub handle_request {
   my $self = shift;
   my $cgi  = shift;
   
   my $path = $cgi->path_info();
   $path =~ s!/+!/!g;
   warn $path, "\n";
   my ($root,$enc,$type,$search) = grep { $_ } split m#/#, $path;

   if ( $root eq 'cpanidx' ) {
      $search = '0' if $type =~ /^next/ and !$search;
      my @results = $self->_search_db( $type, $search );
      #$enc = 'yaml' unless $enc and $enc =~ /^(yaml|json|xml|html)$/i;
      $enc = 'yaml' unless $enc and grep { lc($enc) eq $_ } App::CPANIDX::Renderer->renderers();
      my $ren = App::CPANIDX::Renderer->new( \@results, $enc );
      my ($ctype, $string) = $ren->render( $type );
      print "HTTP/1.0 200 OK\r\n";
      print "Content-type: $ctype\r\n\r\n";
      print $string;
   } 
   else {
      print "HTTP/1.0 404 Not found\r\n";
      print $cgi->header,
      $cgi->start_html('Not found'),
      $cgi->h1('Not found'),
      $cgi->end_html;
   }
}

sub _search_db {
  my ($self,$type,$search) = @_;
  my @results;
  if ( my $sql = App::CPANIDX::Queries->query( $type ) ) {
    if ( ( $type eq 'mod' or $type eq 'corelist' ) 
        and !( $search =~ m#\A[a-zA-Z_][0-9a-zA-Z_]*(?:(::|')[0-9a-zA-Z_]+)*\z# ) ) {
      return @results;
    } 
    # send query to dbi
    my $sth = $self->{_dbh}->prepare_cached( $sql->[0] ) or die $DBI::errstr, "\n";
    $sth->execute( ( $sql->[1] ? $search : () ) );
    while ( my $row = $sth->fetchrow_hashref() ) {
       push @results, { %{ $row } };
    }
  }
  return @results;
}

1;

=head1 SYNOPSIS

=head1 DESCRIPTION

Meep

=head1 METHODS

=over

=item C<new>

=item C<dsn>

=item C<run>

=item C<handle_request>

=back

=cut
