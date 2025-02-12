#!perl

use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Redis::Fast;
use lib 't/tlib';
use Test::SpawnRedisTimeoutServer;
use Errno qw(ETIMEDOUT EWOULDBLOCK);
use POSIX qw(strerror);
use Carp;
use IO::Socket::INET;
use Test::TCP;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

subtest 'server replies quickly enough' => sub {
    my $server = Test::SpawnRedisTimeoutServer::create_server_with_timeout(0);
    my $redis = Redis::Fast->new(server => '127.0.0.1:' . $server->port, read_timeout => 1);
    ok($redis);
    my $res = $redis->get('foo');;
    is $res, 42;
};

subtest "server doesn't replies quickly enough" => sub {
    my $server = Test::SpawnRedisTimeoutServer::create_server_with_timeout(10);
    my $redis = Redis::Fast->new(server => '127.0.0.1:' . $server->port, read_timeout => 1);
    ok($redis);
    like(
         exception { $redis->get('foo'); },
         qr/Error while reading from Redis server: /,
         "the code died as expected",
        );
    ok($! == ETIMEDOUT || $! == EWOULDBLOCK);
};

subtest "server doesn't respond at connection (cnx_timeout)" => sub {
SKIP: {
    skip "This subtest is failing on some platforms", 4;
    my $server = Test::TCP->new(
        listen => 1,
        code => sub {
            my $sock = shift;
            while(1) {
                $sock->accept();
            };
        },
    );

    my $redis;
    my $start_time = clock_gettime(CLOCK_MONOTONIC);
    isnt(
         exception { $redis = Redis::Fast->new(server => '127.0.0.1:' . $server->port, cnx_timeout => 2); },
         undef,
         "the code died",
        );
    my $end_time = clock_gettime(CLOCK_MONOTONIC);
    ok($end_time - $start_time >= 1, "gave up late enough");
    ok($end_time - $start_time < 5, "gave up soon enough");
    ok(!$redis, 'redis was not set');
}
};

subtest "server doesn't respond at connection with unreachable server (cnx_timeout)" => sub {
    my $redis;
    my $start_time = clock_gettime(CLOCK_MONOTONIC);

    # $server is one of example IP addresses.
    # it is reserved for documentation, so unreachable.
    my $server = "192.0.2.1:9998";

    isnt(
         exception { $redis = Redis::Fast->new(server => $server, cnx_timeout => 2); },
         undef,
         "the code died",
        );
    my $end_time = clock_gettime(CLOCK_MONOTONIC);
    ok($end_time - $start_time >= 1, "gave up late enough");
    ok($end_time - $start_time < 5, "gave up soon enough");
    ok(!$redis, 'redis was not set');
};

done_testing;

