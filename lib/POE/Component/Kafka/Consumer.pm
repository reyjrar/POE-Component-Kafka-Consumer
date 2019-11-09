package POE::Component::Kafka::Consumer;
# ABSTRACT: Interface to consume data from a Kafka queue without blocking

use strict;
use warnings;

use Kafka::Librd;
use POE qw(
    Wheel::Run
);

# VERSION

sub spawn {
    my $type = shift;
    my %params = @_;

    # Setup Logging
    my $loggingConfig = exists $params{LoggingConfig} && -f $params{LoggingConfig} ? $params{LoggingConfig}
                      : \q{
                            log4perl.logger = DEBUG, Sync
                            log4perl.appender.File = Log::Log4perl::Appender::File
                            log4perl.appender.File.layout   = PatternLayout
                            log4perl.appender.File.layout.ConversionPattern = %d [%P] %p - %m%n
                            log4perl.appender.File.filename = kafka_consumer.log
                            log4perl.appender.File.mode = truncate
                            log4perl.appender.Sync = Log::Log4perl::Appender::Synchronized
                            log4perl.appender.Sync.appender = File
                        };
    Log::Log4perl->init($loggingConfig) unless Log::Log4perl->initialized;

    # Build Configuration
    my %CONFIG = (
        Alias              => 'kafka_consumer',
        Brokers            => [qw(localhost:9092)],
        ConnectOptions     => {},
        poll_ms            => 1_000,
        %params,
    );

    # Management Session
    my $session = POE::Session->create(
        inline_states => {
            _start    => \&_start,
            _child    => \&_child,
            shutdown  => \&es_shutdown,
        },
        heap => {
            cfg        => \%CONFIG,
        },
    );

    DEBUG(sprintf "Spawned a Kafka::Consumer session for %d brokers.",
        scalar( @{ $CONFIG{Brokers} } ),
    );
    return $session;
}

sub _start {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    # Set the alias
    $kernel->alias_set( $heap->{cfg}{Alias} );

    # Instantiate the consumer
    $heap->{_kafka} = Kafka::Librd->new(
        Kafka::Librd::RD_KAFKA_CONSUMER,
        $heap->{cfg}{ConnectOptions},
    );
    # Add the endpoints
    $heap->{_kafka}->brokers_add(join(',', @{ $heap->{cfg}{Brokers} }));
}

sub _child {
}


1;
