package API::GitForge::Role::GitForge;
# ABSTRACT: role implementing generic git forge operations
#
# Copyright (C) 2017, 2020  Sean Whitton <spwhitton@spwhitton.name>
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

=head1 STATUS

Unstable.  Interface may change.

=head1 DESCRIPTION

Operations which one might wish to perform against any git forge.  See
L<API::GitForge>.

In this documentation, C<example.com> should be replaced with the
domain at which your git forge is hosted, e.g. C<salsa.debian.org>.

=cut

use 5.028;
use strict;
use warnings;

use Role::Tiny;

use Carp;
use File::Temp qw(tempdir);
use Git::Wrapper;
use File::Spec::Functions qw(catfile);

=method new(domain => $domain, access_token => $token)

Instantiate an object representing the GitForge at C<$domain>.  The
C<access_key> argument is optional; if present, it should be an API
key for the forge.

=cut

sub new {
    my ($class, %opts) = @_;
    croak "need domain!" unless exists $opts{domain};

    my %attrs = (_domain => $opts{domain});
    $attrs{_access_token} = $opts{access_token} if exists $opts{access_token};
    my $self = bless \%attrs => $class;

    $self->_make_api;

    return $self;
}

=method ensure_repo($repo)

Create a new repo at C<https://example.com/$repo>.

=cut

sub ensure_repo { shift->_create_repo(@_) }

=method clean_repo($repo)

Create a new repo at C<https://example.com/$repo> and turn off
optional forge features.

=cut

sub clean_repo {
    my ($self, $repo) = @_;
    $self->_ensure_repo($repo);
    $self->_clean_config_repo($repo);
}

=method ensure_fork($upstream)

Ensure that the current user has a fork of the repo at
C<https://example.com/$upstream>, and return URI to that fork suitable
for adding as a git remote.

=cut

sub ensure_fork { shift->_ensure_fork(@_) }

=method clean_fork($upstream)

Ensure that the current user has a fork of the repo at
C<https://example.com/$upstream>, config that fork to make it obvious
it's only there for submitting change proposals, and return URI to
fork suitable for adding as a git remote.

=cut

sub clean_fork {
    my $self     = shift;
    my $fork_uri = $self->_ensure_fork($_[0]);

    my $temp = tempdir CLEANUP => 1;
    my $git = Git::Wrapper->new($temp);
    $git->init;
    my @fork_branches
      = map { m#refs/heads/#; $' } $git->ls_remote("--heads", $fork_uri);
    return $fork_uri if grep /\Agitforge\z/, @fork_branches;

    open my $fh, ">", catfile $temp, "README.md";
    say $fh "This repository exists only in order to submit pull request(s).";
    close $fh;
    $git->add("README.md");
    $git->commit({ message => "Temporary fork for pull request(s)" });

    $git->push($fork_uri, "master:gitforge");
    $self->_clean_config_fork($_[0]);

    # assume that if we had to create the gitforge branch, we just
    # created the fork, so can go ahead and nuke all branches there.
    if ($self->can("_ensure_fork_branch_unprotected")) {
        $self->_ensure_fork_branch_unprotected($_[0], $_) for @fork_branches;
    }
    # may fail if we couldn't unprotect; that's okay
    eval { $git->push($fork_uri, "--delete", @fork_branches) };

    return $fork_uri;
}

=method nuke_fork($upstream)

Delete the user's fork of the repo at
C<https://example.com/$upstream>.

=cut

sub nuke_fork { shift->_nuke_fork(@_) }

=method clean_config_repo($repo)

Turn off optional forge features for repo at
C<https://example.com/$repo>.

=cut

sub clean_config_repo { shift->_clean_config_repo(@_) }

=method clean_config_fork($upstream)

Configure user's fork of repo at C<https://example.com/$upstream> to
make it obvious that it's only there for submitting change proposals.

=cut

sub clean_config_fork { shift->_clean_config_fork(@_) }

requires
  qw<_make_api _ensure_repo _clean_config_repo _clean_config_fork
     _ensure_fork _nuke_fork>;

1;
