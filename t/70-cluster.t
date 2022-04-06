#!perl

use warnings;
use strict;
use Test::More;
use Test::Fatal;
use Test::Deep;
use Redis::Fast;
use lib 't/tlib';
use Test::SpawnRedisServer;

my @ret = redis_cluster();
my $redis_port = pop @ret;
my ($c, $redis_addr) = @ret;
END { diag 'shutting down redis'; $c->() if $c }

diag "redis address : $redis_addr\n";

{
    # check basic cliuster command
    my $client = Redis::Fast->new(server => $redis_addr);

    use Data::Dumper;
    my ($major, $minor, $revision) = split /\./, $client->info->{redis_version};
    if($major < 3) {
        plan skip_all => 'this test reqires Redis 3.0 or above';
    }

    my $info = $client->info;
    cmp_deeply($info, superhashof({
                      redis_mode => 'cluster',
                      cluster_enabled => '1',
                    }),
              "redis info"
             );

    my $cluster_info = $client->cluster_info;
    cmp_deeply($cluster_info, superhashof({
                      cluster_known_nodes => '1',
                    }),
              "redis cluster_info"
             );

    ok $client->cluster_myid, 'got cluster myid';
}

done_testing();
