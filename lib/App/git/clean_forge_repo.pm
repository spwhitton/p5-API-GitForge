package App::git::clean_forge_repo;
# ABSTRACT: create repos on git forges with optional features disabled
#
# Copyright (C) 2020  Sean Whitton <spwhitton@spwhitton.name>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use 5.028;
use strict;
use warnings;

use subs 'main';
use Cwd;
use Term::UI;
use Getopt::Long;
use Git::Wrapper;
use API::GitForge qw(new_from_domain forge_access_token remote_forge_info);
use Try::Tiny;

my $exit_main = 0;

CORE::exit main unless caller;

=func main

Implementation of git-clean-forge-repo(1).  Please see documentation
for that command.

Normally takes no arguments and responds to C<@ARGV>.  If you want to
override that you can pass an arrayref of arguments, and those will be
used instead of the contents of C<@ARGV>.

=cut

sub main {
    shift if $_[0] and ref $_[0] eq "";
    local @ARGV = @{ $_[0] } if $_[0] and ref $_[0] ne "";

    my $term   = Term::ReadLine->new("brand");
    my $remote = "origin";
    my $git    = Git::Wrapper->new(getcwd);
    #<<<
    try {
        $git->rev_parse({ git_dir => 1 });
    } catch {
        die "pwd doesn't look like a git repository ..\n";
    };
    #>>>
    GetOptions "remote=s" => \$remote;

    my ($forge_domain, $forge_repo) = remote_forge_info $remote;
    exit
      unless $term->ask_yn(
        prompt => "Do you want to create repo $forge_repo?");

    my $forge = new_from_domain
      domain       => $forge_domain,
      access_token => forge_access_token $forge_domain;
    $forge->clean_repo($forge_repo);

  EXIT_MAIN:
    return $exit_main;
}

sub exit { $exit_main = shift // 0; goto EXIT_MAIN }

1;
